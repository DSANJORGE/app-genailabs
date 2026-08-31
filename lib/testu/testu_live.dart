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
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:openinsitute_core/openinsitute_core.dart';

import 'testu_i18n.dart';
import 'testu_question_source.dart';

/// Live mode: `flutter run --dart-define=TESTU_LIVE=true`. Default false =
/// the offline demo, byte-for-byte. Single home for the flag; the session
/// and topics screens both read it from here.
const bool testuLive = bool.fromEnvironment('TESTU_LIVE');

const _ital = TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFA9A8A4));

// Same workspace main.dart boots with; init is idempotent.
final _workspace = Workspace(
  id: 'primary',
  name: 'GenAILabs',
  mediaDBRoot: 'https://minsur.genailabs.tech/site/mediadb',
);

const _devEmail = 'testuser@eme.world';
const _devOtp = '666666';

/// Restores the persisted eMe session (cookie + token) and, in debug builds
/// only, falls back to the sanctioned test login. Never registers an account.
Future<void> _ensureAuth({bool force = false}) async {
  await WorkspaceService.init(initialWorkspace: _workspace);
  // The chat socket resolves its URL from OpenI; boot it like BaseApp does.
  await OpenI().initialize(workspaceData: _workspace.toJson());
  if (!force) {
    await AuthService.init();
    if (AuthService.isLoggedIn) return;
  }
  // ponytail: dev-only lazy login, no login UI. A release live build is
  // expected to piggyback an existing eMe session.
  if (kDebugMode) {
    // The fixed test OTP needs no prior sendusercode call (probed 2026-08-31).
    await AuthService.loginWithOtp(_devEmail, _devOtp);
  }
}

/// Topics for the live topics screen, behind the same lazy auth.
Future<List<Topic>> loadLiveTopics() async {
  await _ensureAuth();
  return TopicService().fetchTopics();
}

/// Questions from the backend: first topic -> first tutorial -> its MCQ
/// batch, judged locally off `correctoption`. [reportAttempt] stays the
/// inherited no-op so the shared test user's question progress is not
/// polluted; chat follow-ups ([askSully]) are the one sanctioned write
/// (user-approved 2026-08-31).
class EmeQuestionSource extends TestuQuestionSource {
  EmeQuestionSource({EmeHttp? http})
    : _service = TopicService(http: http),
      _injected = http != null;

  final TopicService _service;

  /// Tests inject an http and must never touch the network or prefs, so an
  /// injected transport skips auth entirely.
  final bool _injected;

  @override
  Future<List<TestuQ>> load() async {
    if (!_injected) await _ensureAuth();

    var topics = await _service.fetchTopics();
    // fetchTopics swallows failures to []; an expired cookie is
    // indistinguishable from "no topics", so re-login once and retry.
    if (topics.isEmpty && !_injected) {
      await _ensureAuth(force: true);
      topics = await _service.fetchTopics();
    }
    if (topics.isEmpty) throw StateError('No topics available');

    final topic = topics.first;
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

/// Sends [text] to Sully as a chat follow-up on this tutorial's tutor
/// channel (same chat the eMe app shows). Replies arrive on [sullyReplies].
Future<void> askSully(TestuQ q, String text) async {
  final chan = await (_tutorChannel ??= () async {
    final c = await TopicService().fetchTutorChannel(_liveTutorialId!);
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
      TextSpan(text: m.section.title, style: _ital),
      const TextSpan(text: '.'),
    ],
    kicker:
        '${L('QUESTION', 'PREGUNTA')} ${i + 1} '
        '${L('OF', 'DE')} $total · ${topic.title.toUpperCase()}',
    text: q.question,
    opts: q.optionsList,
    okIdx: q.correctAnswerIndex,
    bad: q.rationale.isEmpty ? null : [TextSpan(text: q.rationale)],
  );
}
