import 'dart:async';
import 'package:eme_app_package/eme_http.dart';
import 'package:eme_app_package/models/topic.dart';
import 'package:eme_app_package/models/tutor_channel.dart';
import 'package:eme_app_package/services/chat_socket_service.dart';
import 'package:eme_app_package/models/tutorial.dart';
import 'package:eme_app_package/models/workspace.dart';
import 'package:eme_app_package/services/auth_service.dart';
import 'package:eme_app_package/services/topic_service.dart';
import 'package:eme_app_package/services/workspace_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/painting.dart';
import 'package:openinsitute_core/openinsitute_core.dart';

import 'testu_auth.dart';
import 'testu_client.dart';
import 'testu_i18n.dart';
import 'testu_question_source.dart';
import 'testu_session_engine.dart' show Attempt;
import 'testu_sully.dart' show isSullyError, sullyUnavailable;

/// Live mode: on for the minsur client (the default), off for vueling =
/// the offline demo, byte-for-byte. `--dart-define=TESTU_LIVE=true|false`
/// overrides either way. Single home for the flag; the session and topics
/// screens both read it from here.
const bool testuLive = bool.fromEnvironment('TESTU_LIVE',
    defaultValue: testuClientId == 'minsur');

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
      // The server keeps one token per user: a login elsewhere (web UI, a
      // probe) 403s every call here. Services swallow that to "no data",
      // so the screens went blank instead of saying so (2026-09-04).
      // Signing out drops to the sign-in screen; the guard keeps the
      // burst of parallel 403s from signing out more than once.
      EmeHttp.onUnauthorized = (_) {
        if (AuthService.isLoggedIn) TestuAuth.signOut();
      };
    }();

// ---- Auth: the live bodies behind TestuAuth, same contract as AuthService.

Future<bool> liveRestoreSession() async {
  await _init();
  return AuthService.isLoggedIn;
}

/// 'ok' | 'nouser' | 'error' — the server's own status word, or 'error'
/// when it could not be reached.
Future<String> liveSendUserCode(String email) async {
  await _init();
  try {
    final r = await AuthService.sendUserCode(email: email);
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
  _liveTutorialTitle = null;
  _liveSections = const [];
  _liveQs = const [];
  _lastSectionId = null;
}

// ---- Data.

/// Questions from the backend: [topicId] (or the first topic) -> first
/// tutorial -> its MCQ batch, judged locally off `correctoption`.
/// Writes back: chat follow-ups ([askSully], approved 2026-08-31) and, for
/// Diego's own account only, attempts ([reportAttempt], approved
/// 2026-09-03); the shared test user's progress stays unpolluted.
class EmeQuestionSource extends TestuQuestionSource {
  EmeQuestionSource({this.topicId, this.sectionId, EmeHttp? http})
      : _service = TopicService(http: http);

  final String? topicId;

  /// Section to start on: its questions come first, the rest keep their
  /// order. Unknown or null = tutorial order.
  final String? sectionId;
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
    _liveTutorialTitle = tutorials.first.title;
    unawaited(loadDocuments().catchError((_) => const <LiveDoc>[]));
    final detail = await _service.fetchTutorialDetail(tutorials.first.id);
    _liveSections = detail?.sections ?? const [];
    final all = detail?.mcqQuestions ?? const <SectionQuestion>[];
    if (all.isEmpty) throw StateError('No questions in ${tutorials.first.id}');
    final mcqs = [
      ...all.where((m) => m.section.id == sectionId),
      ...all.where((m) => m.section.id != sectionId),
    ];

    return _liveQs = [
      for (final (i, m) in mcqs.indexed) _toTestuQ(m, i, mcqs.length, topic),
    ];
  }

  /// Writes the attempt back as `chat_tutor_answer` so the server keeps a
  /// `tutoranswer` history the tutor can reason from. Diego's own account
  /// only (approved 2026-09-03); the shared test user stays unpolluted.
  @override
  void reportAttempt({
    required int qi,
    String? questionId,
    required int chosen,
    required int confidence,
    required bool correct,
  }) {
    if (AuthService.userId != 'diego' || questionId == null) return;
    final q = _liveQs[qi];
    if (q.sectionId == null || q.componentId == null) return;
    _tutorChannelFor(_liveTutorialId!).then((chan) async {
      if (chan == null) return;
      await _service.submitAnswer(
        channel: chan.id,
        tutorialId: _liveTutorialId,
        questionId: questionId,
        selectedOption: optionLetter(chosen),
        confidence: confidenceWord(confidence),
        sectionId: q.sectionId!,
        componentId: q.componentId!,
      );
    }).catchError((Object e) {
      debugPrint('TestU: reportAttempt failed ($e)');
    });
  }
}

/// Server vocabulary: `correctoption` is a capital letter; confidence is
/// the `answerconfidence` list id (see chat_tutor_feedback).
String optionLetter(int chosen) => 'ABCDEF'[chosen];
String confidenceWord(int confidence) =>
    const ['noidea', 'notsure', 'mostlysure', 'confident'][confidence];

// The tutorial the loaded questions belong to; follow-ups need its id.
String? _liveTutorialId;
String? _liveTutorialTitle;
List<TutorialSection> _liveSections = const [];
List<TestuQ> _liveQs = const [];
Future<TutorChannel?>? _tutorChannel;

/// True when [q] came from the backend, so a live follow-up can be sent.
bool canAskSully(TestuQ q) =>
    testuLive &&
    _liveTutorialId != null &&
    q.sectionId != null &&
    q.componentId != null;

/// Sully's textual replies from the live chat socket, as plain text. An
/// agent error the server posts instead of an answer (LLM down, 502…)
/// arrives as [sullyUnavailable], so the session, the tutor tab and the
/// document viewer all say the same thing without each checking.
Stream<String> sullyReplies() => ChatSocketService()
    .messageStream
    .where((m) =>
        m.isAI &&
        !m.isKeepAlive &&
        !m.isMessageRemoved &&
        // Upstream renamed the enum to MessageRenderType (2026-09-03);
        // ChatMessage.messageType is now the raw string field.
        (m.messageRenderType.isAgentComment || m.messageRenderType.isText))
    .map((m) => _plainText(m.text))
    .where((s) => s.isNotEmpty)
    .map((s) => isSullyError(s) ? sullyUnavailable() : s);

// ponytail: crude tag strip — the reply HTML is simple tutor prose. Its
// markdown (the /chat answer) survives here; `mdSpans` renders it.
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

/// Sends [text] to Sully as a chat follow-up about [q] on this tutorial's
/// tutor channel (same chat the eMe app shows). Replies arrive on
/// [sullyReplies]. [attempt] rides along so the tutor knows what the learner
/// answered and how sure they were — for most users the app never submits
/// answers, so the server has no other record of it.
Future<void> askSully(TestuQ q, String text, {Attempt? attempt}) =>
    _followUp(text,
        sectionId: q.sectionId!,
        componentId: q.componentId!,
        questionId: q.questionId,
        attempt: attempt);

/// Standalone chat from the tutor tab: no question in play. Anchored on the
/// section the learner last answered (else the first) — the server needs a
/// section for chat history and lesson content, and the learner's answer
/// history rides along.
Future<void> askSullyFree(String text) async {
  if (_liveQs.isEmpty) await EmeQuestionSource().load();
  final q = _liveQs.firstWhere((q) => q.sectionId == _lastSectionId,
      orElse: () => _liveQs.first);
  await _followUp(text, sectionId: q.sectionId!, componentId: q.componentId!);
}

// Section of the learner's most recent recorded answer, from [loadTutorProgress].
String? _lastSectionId;

/// The learner's per-section tally in the live tutorial, from the answers
/// the server keeps on the tutor channel (`tutorhistory.json`). Answers
/// recorded before sections were stored (2026-09-03) carry no section and
/// are skipped. Null when the tutorial could not be loaded.
Future<TutorProgress?> loadTutorProgress() async {
  if (_liveQs.isEmpty) await EmeQuestionSource().load();
  final r = await TopicService().fetchTutorHistory(tutorialId: _liveTutorialId!);
  final (sections, last) = _tally(_liveSections, r.answers);
  _lastSectionId = last?.id;
  return TutorProgress(
    _liveTutorialTitle ?? '',
    [for (final s in sections) if (s.total > 0) s],
    last,
  );
}

/// Answers oldest first. The server says "oldest first" but does not
/// actually sort (2026-09-03); dates share one format and zone, so string
/// order is time order.
List<Map<String, dynamic>> _byDate(List<Map<String, dynamic>> raw) =>
    [...raw]..sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));

/// Per-section tally of [raw] answers over [sections] (tutorial order, every
/// section), plus the section of the most recent answer. Answers recorded
/// before sections were stored (2026-09-03) carry no section and are skipped.
(List<SectionProgress>, SectionProgress?) _tally(
    List<TutorialSection> sections, List<Map<String, dynamic>> raw) {
  final bySection = {for (final s in sections) s.id: SectionProgress.of(s)};
  SectionProgress? last;
  for (final a in _byDate(raw)) {
    final s = bySection[a['section']?.toString()];
    if (s == null) continue;
    final ok = a['iscorrect']?.toString() == 'true';
    s.total++;
    if (ok) s.correct++;
    s.latest['${a['questionid']}'] = ok;
    last = s;
  }
  return (bySection.values.toList(), last);
}

/// The learner's record in one live topic — its first tutorial's sections
/// with question counts and the answers the server keeps on the tutor
/// channel — for the topic screens and the dashboard. Null when live
/// topics are unavailable. [topicId] null = the first topic with tutorials.
Future<TopicProgress?> loadTopicProgress({String? topicId}) async {
  final service = TopicService();
  final topics = await service.fetchTopics();
  final topic = topics.where((t) => t.id == topicId).firstOrNull ??
      topics.where((t) => t.totalTutorials > 0).firstOrNull;
  return topic == null ? null : _topicProgress(service, topic);
}

/// Every live topic in the server's order; one with no tutorial yet has no
/// sections and no answers.
Future<List<TopicProgress>> loadAllTopicProgress() async {
  final service = TopicService();
  return [
    for (final t in await service.fetchTopics())
      await _topicProgress(service, t),
  ];
}

Future<TopicProgress> _topicProgress(TopicService service, Topic topic) async {
  final tutorials =
      topic.totalTutorials == 0 ? const <Tutorial>[] : await service.fetchTutorialsForTopic(topic.id);
  if (tutorials.isEmpty) return TopicProgress(topic, '', const [], const [], null);
  final tutorial = tutorials.first;
  final detail = await service.fetchTutorialDetail(tutorial.id);
  final history = await service.fetchTutorHistory(tutorialId: tutorial.id);
  final answers = _byDate(history.answers);
  final (sections, last) = _tally(detail?.sections ?? const [], answers);
  return TopicProgress(topic, tutorial.title, sections, answers, last);
}

/// One live topic's tally; see [loadTopicProgress].
class TopicProgress {
  TopicProgress(
      this.topic, this.tutorialTitle, this.sections, this.answers, this.last);
  final Topic topic;
  final String tutorialTitle;

  /// Tutorial order, every section; empty when the topic has no tutorial.
  final List<SectionProgress> sections;

  /// Every recorded answer, oldest first, as the server sends it
  /// (iscorrect, confidence, date, section, questionid).
  final List<Map<String, dynamic>> answers;

  /// Section of the most recent answer; null when there is none.
  final SectionProgress? last;

  int get questions => sections.fold(0, (n, s) => n + s.questions);
  int get answered => sections.fold(0, (n, s) => n + s.answered);
  int get mastered => sections.fold(0, (n, s) => n + s.mastered);

  /// Same rule as the tutor tab's greeting.
  SectionProgress? get weakest => TutorProgress(
      tutorialTitle, [for (final s in sections) if (s.total > 0) s], last)
      .weakest;
}

/// One section's tally of the learner's recorded answers.
class SectionProgress {
  SectionProgress(this.id, this.title, {this.questions = 0});
  SectionProgress.of(TutorialSection s)
      : this(s.id, s.title,
            questions: s.contents
                .where((c) => c.isMcq && c.question != null)
                .length);
  final String id;
  final String title;

  /// MCQs in the section.
  final int questions;

  /// Attempts, and how many were right.
  int correct = 0;
  int total = 0;

  /// Question id → whether its most recent attempt was right.
  final Map<String, bool> latest = {};
  int get answered => latest.length;
  int get mastered => latest.values.where((ok) => ok).length;
}

/// The learner's record in the live tutorial, for the tutor tab's greeting.
class TutorProgress {
  TutorProgress(this.tutorialTitle, this.sections, this.last);
  final String tutorialTitle;

  /// Tutorial order; only sections with at least one answer.
  final List<SectionProgress> sections;

  /// Section of the most recent answer; null when there is none.
  final SectionProgress? last;

  /// Lowest share of correct answers, ties to the one with more wrong ones;
  /// null when every recorded answer is right.
  SectionProgress? get weakest {
    SectionProgress? w;
    for (final s in sections) {
      if (s.correct == s.total) continue;
      if (w == null ||
          s.correct * w.total < w.correct * s.total ||
          (s.correct * w.total == w.correct * s.total &&
              s.total - s.correct > w.total - w.correct)) {
        w = s;
      }
    }
    return w;
  }
}

Future<void> _followUp(
  String text, {
  required String sectionId,
  required String componentId,
  String? questionId,
  Attempt? attempt,
}) async {
  final chan = await _tutorChannelFor(_liveTutorialId!);
  if (chan == null) throw StateError('No tutor channel');
  await TopicService().sendFollowUp(
    messageId: 'user_comment_${DateTime.now().millisecondsSinceEpoch}',
    tutorialId: _liveTutorialId!,
    channel: chan.id,
    sectionId: sectionId,
    componentId: componentId,
    questionId: questionId,
    message: text,
    selectedOption: attempt == null ? null : optionLetter(attempt.chosen),
    confidence: attempt == null ? null : confidenceWord(attempt.confidence),
  );
}

/// The tutorial's channel, resolved once and connected to the socket so
/// replies flow to [sullyReplies].
Future<TutorChannel?> _tutorChannelFor(String tutorialId) =>
    _tutorChannel ??= () async {
      final c = await findTutorChannel(tutorialId);
      if (c != null) await ChatSocketService().connect(channel: c.id);
      return c;
    }();

// ---- Reference documents (the sources the tutor cites).

/// One reference document attached to a live tutorial (server `entityasset`,
/// via the site page `entitytutorial/documents.json`).
class LiveDoc {
  LiveDoc(this.id, this.title, this.pages, this._preview,
      {this.video = '',
      this.chapters = const [],
      this.toc = const [],
      this.captions = const [],
      this.credit});
  final String id;
  final String title;
  final int pages;
  final String _preview;

  /// Site-relative mp4 when the document is a video (empty for PDFs).
  final String video;

  /// Authored chapter marks (server `chapters` field, "m:ss Title" lines).
  final List<({Duration at, String name})> chapters;

  /// Table of contents of a PDF (same `chapters` field, "p. N Title" lines).
  final List<({int page, String name})> toc;
  final String? credit;

  bool get isVideo => video.isNotEmpty;
  String get videoUrl => liveAssetUrl(video);

  /// Transcript lines (server `videotrack.captions`), start-ordered; empty
  /// until the transcriber has run.
  final List<({Duration at, String text})> captions;

  /// Rendered page image, 1-based. The page number goes in the rendition
  /// name (`image3000x3000pageN.webp`). `generated` only serves files that
  /// exist; `generate/<sourcepath>/<rendition>/<any name>` renders a missing
  /// one on demand (~2 s, ImageMagick) and caches it there.
  String pageUrl(int page) => liveAssetUrl(_preview
      .replaceFirst('/asset/generated/', '/asset/generate/')
      .replaceFirst(
          'image1200x628.webp', 'image3000x3000page$page.webp/p$page.webp'));
}

List<({Duration at, String name})> _parseChapters(String raw) => [
      for (final m in RegExp(r'^(\d+):(\d\d)\s+(.+)$', multiLine: true)
          .allMatches(raw))
        (
          at: Duration(minutes: int.parse(m[1]!), seconds: int.parse(m[2]!)),
          name: m[3]!.trim()
        ),
    ];

List<({int page, String name})> _parseToc(String raw) => [
      for (final m
          in RegExp(r'^p\.\s*(\d+)\s+(.+)$', multiLine: true).allMatches(raw))
        (page: int.parse(m[1]!), name: m[2]!.trim()),
    ];

/// Every document loaded so far, by title — how a citation in a reply
/// (`[Title, p. N]`, the server's format) finds its viewer.
final Map<String, LiveDoc> liveDocs = {};

/// Reference documents of [topicId]'s first tutorial (null = the current
/// live tutorial). Empty when the topic has none.
Future<List<LiveDoc>> loadDocuments({String? topicId}) async {
  var tutorialId = _liveTutorialId;
  if (topicId != null) {
    final service = TopicService();
    final topics = await service.fetchTopics();
    final topic = topics.where((t) => t.id == topicId).firstOrNull;
    if (topic == null) return const [];
    tutorialId = (await service.fetchTutorialsForTopic(topic.id)).firstOrNull?.id;
  }
  if (tutorialId == null) return const [];
  final data = await DioEmeHttp().getJson(
      'services/module/entitytutorial/documents.json',
      query: {'entitytutorial': tutorialId});
  final docs = [
    for (final d in (data['documents'] as List? ?? const []))
      LiveDoc('${d['id']}', '${d['title']}',
          int.tryParse('${d['pages']}') ?? 1, '${d['preview']}',
          video: '${d['video'] ?? ''}',
          chapters: _parseChapters('${d['chapters'] ?? ''}'),
          toc: _parseToc('${d['chapters'] ?? ''}'),
          captions: [
            for (final c in (d['captions'] as List? ?? const []))
              (
                at: Duration(seconds: int.tryParse('${c['start']}') ?? 0),
                text: '${c['text']}'
              ),
          ],
          credit: '${d['credit'] ?? ''}'.isEmpty ? null : '${d['credit']}'),
  ];
  liveDocs.addAll({for (final d in docs) d.title: d});
  return docs;
}

/// One cited place: a document title and a page (PDF) or a time (video).
typedef Ref = ({String title, int page, Duration? at});

/// A tutor reply split from its sources: the text, the verbatim passage the
/// server quotes (`> …` line), the last `[Title, p. N]` (PDF page) or
/// `[Title, m:ss]` (video time) citation — the primary source — the other
/// citations in the reply, and the page-relative boxes of the passage on
/// the primary page (`[[hl x,y,w,h;…]]`, PDFs only).
class Cite {
  const Cite(
      {this.text = '',
      this.quote,
      this.title,
      this.page = 1,
      this.at,
      this.others = const [],
      this.rects = const []});

  final String text;
  final String? quote;
  final String? title;
  final int page;
  final Duration? at;
  final List<Ref> others;
  final List<Rect> rects;

  Ref get ref => (title: title ?? '', page: page, at: at);

  /// The same citation pointed at [r] (the sources sheet's rows).
  Cite to(Ref r) => Cite(
      quote: quote,
      title: r.title,
      page: r.page,
      at: r.at,
      rects: r == ref ? rects : const []);
}

final _quoteRe = RegExp(r'^\s*>\s*(.+?)\s*$', multiLine: true);
final _hlRe = RegExp(r'^\s*\[\[hl ([\d.,;]+)\]\]\s*$', multiLine: true);

/// "m:ss" — citation times and the video player's clock.
String fmtClock(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

final _citeRe = RegExp(r'\s*\[([^\[\]]+?),\s*(?:p\.?\s*(\d+)|(\d+):(\d\d))\]');

Ref _ref(RegExpMatch m) => (
      title: m[1]!.trim(),
      page: int.tryParse(m[2] ?? '') ?? 1,
      at: m[3] == null
          ? null
          : Duration(minutes: int.parse(m[3]!), seconds: int.parse(m[4]!)),
    );

Cite splitCite(String reply) {
  final ms = _citeRe.allMatches(reply).toList();
  if (ms.isEmpty) return Cite(text: reply);
  final main = _ref(ms.last);
  return Cite(
    text: reply
        .replaceAll(_citeRe, '')
        .replaceAll(_quoteRe, '')
        .replaceAll(_hlRe, '')
        .trim(),
    quote: _quoteRe.allMatches(reply).lastOrNull?[1],
    title: main.title,
    page: main.page,
    at: main.at,
    others: {for (final m in ms) _ref(m)}.where((r) => r != main).toList(),
    rects: [
      for (final r in (_hlRe.firstMatch(reply)?[1] ?? '').split(';'))
        if (r.split(',').length == 4) _rect(r.split(',')),
    ],
  );
}

Rect _rect(List<String> v) => Rect.fromLTWH(double.parse(v[0]),
    double.parse(v[1]), double.parse(v[2]), double.parse(v[3]));

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
    quote: q.sourceQuote,
    cite: q.sourceCite,
    page: q.sourcePage,
  );
}
