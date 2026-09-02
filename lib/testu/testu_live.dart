import 'package:eme_app_package/eme_http.dart';
import 'package:eme_app_package/models/chat_message.dart';
import 'package:eme_app_package/models/topic.dart';
import 'package:eme_app_package/models/tutor_channel.dart';
import 'package:eme_app_package/services/chat_socket_service.dart';
import 'package:eme_app_package/models/tutorial.dart';
import 'package:eme_app_package/models/workspace.dart';
import 'package:eme_app_package/services/auth_service.dart';
import 'package:eme_app_package/services/topic_service.dart';
import 'package:eme_app_package/services/workspace_service.dart';
import 'package:flutter/painting.dart';
import 'package:openinsitute_core/openinsitute_core.dart';

import 'testu_i18n.dart';
import 'testu_question_source.dart';

/// Live mode: `flutter run --dart-define=TESTU_LIVE=true`. Default false =
/// the offline demo, byte-for-byte. Single home for the flag; the session
/// and topics screens both read it from here.
const bool testuLive = bool.fromEnvironment('TESTU_LIVE');

/// The eMe server live mode talks to: the local eme-server-minsur checkout
/// (`eme-server-minsur/`, Tomcat on :8080). Point a build elsewhere with
/// `--dart-define=TESTU_MEDIADB=https://minsur.genailabs.tech/site/mediadb`.
const _mediaDBRoot = String.fromEnvironment('TESTU_MEDIADB',
    defaultValue: 'http://localhost:8080/site/mediadb');

/// Absolute URL for a site-relative asset path from the server
/// (`/site/mediadb/services/module/asset/generated/...`).
String liveAssetUrl(String path) =>
    path.startsWith('http') ? path : Uri.parse(_mediaDBRoot).origin + path;

// Same workspace shape main.dart boots with; init is idempotent.
final _workspace =
    Workspace(id: 'primary', name: 'GenAILabs', mediaDBRoot: _mediaDBRoot);

Future<void>? _ready;

/// Workspace, chat socket and the persisted eMe session (cookie + token),
/// once. The sign-in gate awaits this before any screen exists, so the
/// sources below can assume it ran.
Future<void> _init() => _ready ??= () async {
      await WorkspaceService.init(initialWorkspace: _workspace);
      // The chat socket resolves its URL from OpenI; boot it like BaseApp does.
      await OpenI().initialize(workspaceData: _workspace.toJson());
      await AuthService.init();
    }();

// ---- Auth: the live bodies behind TestuAuth, same contract as AuthService.

Future<bool> liveRestoreSession() async {
  await _init();
  return AuthService.isLoggedIn;
}

/// 'ok' | 'nouser' | 'error' — the server's own status word, or 'error'
/// when it could not be reached.
Future<String> liveSendUserCode(String email,
    {String? firstName, String? lastName}) async {
  await _init();
  try {
    final r = await AuthService.sendUserCode(
        email: email, firstName: firstName, lastName: lastName);
    return r['status']?.toString() ?? 'error';
  } catch (_) {
    return 'error';
  }
}

Future<bool> liveLoginWithOtp(String email, String code) async {
  await _init();
  try {
    return await AuthService.loginWithOtp(email, code);
  } catch (_) {
    return false;
  }
}

Future<void> liveSignOut() async {
  await _init();
  await AuthService.logout();
  // The socket is a singleton: left connected, the next user would hear
  // this user's tutor channel.
  ChatSocketService().disconnect();
  _tutorChannel = null;
  _liveTutorialId = null;
}

// ---- Data.

/// Topics for the live topics screen.
Future<List<Topic>> loadLiveTopics() => TopicService().fetchTopics();

/// Questions from the backend: [topicId] (or the first topic) -> first
/// tutorial -> its MCQ batch, judged locally off `correctoption`.
/// [reportAttempt] stays the inherited no-op so the shared test user's
/// question progress is not polluted; chat follow-ups ([askSully]) are the
/// one sanctioned write (user-approved 2026-08-31).
class EmeQuestionSource extends TestuQuestionSource {
  EmeQuestionSource({this.topicId, EmeHttp? http})
      : _service = TopicService(http: http);

  final String? topicId;
  final TopicService _service;
  String? _topic;

  @override
  String get topic => _topic ?? super.topic;

  @override
  Future<List<TestuQ>> load() async {
    // ponytail: fetchTopics swallows failures to [], so an expired session
    // reads as "no topics" and the session falls back to the offline demo.
    // Bounce to sign-in instead once the transport surfaces the 401.
    final topics = await _service.fetchTopics();
    if (topics.isEmpty) throw StateError('No topics available');

    // ponytail: an unknown id falls back to the first topic that has
    // tutorials rather than erroring — the row that sent it came from this
    // same list, and the server lists topics with no content yet.
    final topic = topics.firstWhere((t) => t.id == topicId,
        orElse: () => topics.firstWhere((t) => t.totalTutorials > 0,
            orElse: () => topics.first));
    _topic = topic.title;
    final tutorials = await _service.fetchTutorialsForTopic(topic.id);
    if (tutorials.isEmpty) throw StateError('No tutorials in ${topic.id}');

    _liveTutorialId = tutorials.first.id;
    final detail = await _service.fetchTutorialDetail(tutorials.first.id);
    final mcqs = detail?.mcqQuestions ?? const <SectionQuestion>[];
    if (mcqs.isEmpty) throw StateError('No questions in ${tutorials.first.id}');

    return [
      for (final (i, m) in mcqs.indexed) _toTestuQ(m, i, mcqs.length, topic),
    ];
  }
}

// The tutorial the loaded questions belong to; follow-ups need its id.
String? _liveTutorialId;
Future<TutorChannel?>? _tutorChannel;

/// True when [q] came from the backend, so a live follow-up can be sent.
bool canAskSully(TestuQ q) =>
    testuLive &&
    _liveTutorialId != null &&
    q.sectionId != null &&
    q.componentId != null;

/// Sully's textual replies from the live chat socket, as plain text.
Stream<String> sullyReplies() => ChatSocketService()
    .messageStream
    .where((m) =>
        m.isAI &&
        !m.isKeepAlive &&
        !m.isMessageRemoved &&
        (m.messageType == MessageType.agentcomment ||
            m.messageType == MessageType.text))
    .map((m) => _plainText(m.text))
    .where((s) => s.isNotEmpty);

// ponytail: crude tag strip — the reply HTML is simple tutor prose.
String _plainText(String html) => html
    .replaceAll(RegExp(r'<br\s*/?>|</p\s*>|</li\s*>', caseSensitive: false),
        '\n')
    .replaceAll(RegExp(r'<[^>]*>'), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// The tutor channel for [tutorialId]: the active one from tutor history,
/// else the session record (minsur answers history without a channel even
/// when a session exists, 2026-09-02). Null when neither has one.
Future<TutorChannel?> findTutorChannel(String tutorialId,
    {EmeHttp? http}) async {
  final service = TopicService(http: http);
  final r = await service.fetchTutorHistory(tutorialId: tutorialId);
  return r.activeChannel ??
      r.currentChannel ??
      await service.fetchTutorSession(tutorialId);
}

/// Sends [text] to Sully as a chat follow-up on this tutorial's tutor
/// channel (same chat the eMe app shows). Replies arrive on [sullyReplies].
Future<void> askSully(TestuQ q, String text) async {
  final chan = await (_tutorChannel ??= () async {
    final c = await findTutorChannel(_liveTutorialId!);
    if (c != null) await ChatSocketService().connect(channel: c.id);
    return c;
  }());
  if (chan == null) throw StateError('No tutor channel');
  await TopicService().sendFollowUp(
    messageId: 'user_comment_${DateTime.now().millisecondsSinceEpoch}',
    tutorialId: _liveTutorialId!,
    channel: chan.id,
    sectionId: q.sectionId!,
    componentId: q.componentId!,
    message: text,
  );
}

TestuQ _toTestuQ(SectionQuestion m, int i, int total, Topic topic) {
  final q = m.question;
  return TestuQ(
    questionId: q.id,
    sectionId: m.section.id,
    componentId: m.contentId,
    framing: [
      TextSpan(text: L('Next up in ', 'Siguiente en ')),
      TextSpan(text: m.section.title, style: testuItal),
      const TextSpan(text: '.'),
    ],
    kicker:
        '${L('QUESTION', 'PREGUNTA')} ${i + 1} '
        '${L('OF', 'DE')} $total · ${topic.title.toUpperCase()}',
    text: q.question,
    // No caption: the asset row's text restates the correct answer.
    image: m.image == null ? null : liveAssetUrl(m.image!.assetUrl),
    opts: q.optionsList,
    okIdx: q.correctAnswerIndex,
    bad: q.rationale.isEmpty ? null : [TextSpan(text: q.rationale)],
  );
}
