import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'testu_i18n.dart';
import 'testu_icons.dart';
import 'testu_live.dart';
import 'testu_pdf.dart';
import 'testu_notifications.dart';
import 'testu_question_source.dart';
import 'testu_report_sheet.dart';
import 'testu_social.dart';
import 'testu_social_api.dart';
import 'testu_session_engine.dart';
import 'testu_shell.dart';
import 'testu_sully.dart';
import 'testu_theme.dart';
import 'testu_topics.dart' show masteryOf;
import 'testu_usage.dart';
import 'testu_widgets.dart';
import 'testu_client.dart';

/// Every "start a session" CTA in the app lands here. [topicId] is the live
/// topic to draw questions from; null means the first one. [sectionId]
/// starts the session on that section's questions (the tutor tab's
/// "Review it now" on the weakest section); the rest follow in order.
/// Completes when the session screen is popped, so a caller can refresh
/// what the answers changed.
Future<void> showTestuSession(BuildContext context,
    {String? topicId, String? sectionId}) {
  return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          TestuSessionScreen(topicId: topicId, sectionId: sectionId)));
}

// Show-once-ever: the first confidence tap explains that tapping submits.
// In-memory cache of the SharedPreferences flag so the controller can be
// seeded synchronously; the prefs read in initState catches up on cold start.
const _confAckKey = 'testu.confAcked';
bool _confAcked = false;

List<String> get _conf => [
  L('Guessing', 'Adivinando'),
  L('Unsure', G('Inseguro', 'Insegura')),
  // ponytail: "Bastante" alone (user-approved) — also keeps the cell 1 line.
  L('Fairly sure', 'Bastante'),
  L('Certain', G('Seguro', 'Segura')),
];
const _t = TestuTokens.instance;
final _confColors = [
  _t.confGuessing,
  _t.confUnsure,
  _t.confFairlySure,
  _t.confCertain,
];
// Tint behind the tapped level; the olive one is the fairly-sure tint and
// exists nowhere else.
final _confSelectedBg = [
  _t.redTint,
  _t.amberTint,
  const Color(0xFF1D2212),
  _t.greenTint,
];

const _bold = TextStyle(fontWeight: FontWeight.w700);

/// Learn Mode session — a chat with Sully. Confidence tap IS the submit;
/// the debrief follows the last question.
class TestuSessionScreen extends StatefulWidget {
  const TestuSessionScreen(
      {super.key,
      this.topicId,
      this.sectionId,
      this.questionId,
      this.highlightMessageId,
      this.source});

  final String? topicId;
  final String? sectionId;

  /// From a notification: start on this question and, once it is answered,
  /// open its thread on [highlightMessageId].
  final String? questionId;
  final String? highlightMessageId;

  /// Where the questions come from; null = the build's default (live server
  /// for minsur, the bundled demo for vueling). Tests pass
  /// [LocalQuestionSource] explicitly — a live build never falls back to it.
  final TestuQuestionSource? source;

  @override
  State<TestuSessionScreen> createState() => _TestuSessionScreenState();
}

class _TestuSessionScreenState extends State<TestuSessionScreen> {
  final _scroll = ScrollController();
  final _input = TextEditingController();
  late final SessionController _controller;
  int _grownTo = 0; // transcript length already auto-scrolled for

  /// Chat with Sully, interleaved into the transcript: (engine transcript
  /// length at send time — the entry the bubble renders after, isUser, text).
  final _chat = <(int, bool, String)>[];
  StreamSubscription<String>? _sullySub;
  Timer? _sullyTimeout;
  bool _waitingSully = false;

  /// Set when the 90 s line was shown: the next tutor message on the channel
  /// still lands as the late answer instead of being dropped.
  bool _lateSully = false;

  /// Keys on each question's framing bubble, and the one the auto-scroll is
  /// currently not allowed to push above the viewport top.
  final _anchors = <int, GlobalKey>{};
  GlobalKey? _anchor;

  /// Whether the list still follows new content. A finger that drags away
  /// from the bottom takes it back: a tutor message fires onGrew on every
  /// step of its reveal, and following that yanks the reader mid-sentence.
  bool _stick = true;
  static const _stickSlack = 80.0;

  /// Adapter picked by the compile-time flag (or handed in by a test).
  late final TestuQuestionSource _source = widget.source ??
      (testuLive
          ? EmeQuestionSource(
              topicId: widget.topicId,
              sectionId: widget.sectionId,
              questionId: widget.questionId)
          : LocalQuestionSource());
  List<TestuQ> _qs = const [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = SessionController(
      questions: () =>
          [for (final q in _qs) SessionQuestion(okIdx: q.okIdx, video: q.video)],
      scheduler: TimerScheduler(),
      confAcked: _confAcked,
    );
    _controller.addListener(_onEngine);
    SharedPreferences.getInstance().then((p) {
      if (p.getBool(_confAckKey) ?? false) {
        _confAcked = true;
        _controller.acknowledgeConf();
      }
    });
    // Rebuild on language switch: entries are semantic, spans are built in
    // build(), so the whole transcript flips — past bubbles included.
    testuLang.addListener(_onLang);
    // Questions must be loaded before the engine starts — it reads them to
    // size the session. Local load resolves on the next microtask.
    _boot();
  }

  /// Load the batch, then start the engine. A source that throws or comes
  /// back empty is the error state — never the bundled demo standing in
  /// for the live server.
  Future<void> _boot() async {
    var qs = const <TestuQ>[];
    try {
      qs = await _source.load();
    } catch (e) {
      debugPrint('TestU: question load failed ($e)');
    }
    if (!mounted) return;
    setState(() {
      _qs = qs;
      _loading = false;
      _error = qs.isEmpty;
    });
    if (!_error) _controller.start();
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = false;
    });
    _boot();
  }

  @override
  void dispose() {
    testuLang.removeListener(_onLang);
    _controller.removeListener(_onEngine);
    _controller.dispose();
    _scroll.dispose();
    _input.dispose();
    _sullySub?.cancel();
    _sullyTimeout?.cancel();
    super.dispose();
  }

  /// Bottom dock: the composer once the current question is answered, and
  /// "Continuar →" beside it while the end-of-question offer is pending.
  /// Before the confidence tap there is nothing to ask yet, so no composer;
  /// leaving early is the header ✕ only (approved 2026-09-03). Null = no
  /// dock. Continue appends the next Framing synchronously, so the pill
  /// vanishes on its own — no local "taken" flag.
  Widget? _dock() {
    final last = _controller.transcript.lastOrNull;
    if (last == null || last is Framing || last is Prompt || last is HintNote) {
      return null;
    }
    final t = TestuTokens.of(context);
    return Row(
      children: [
        Expanded(
          // House composer — same module as thread replies and the tutor
          // ask bar.
          child: TestuComposer(
            controller: _input,
            hint: L('Ask ${client.tutor} anything\u2026',
                'Pregunta a ${client.tutor} lo que quieras\u2026'),
            onSend: (_) => _sendTyped(),
          ),
        ),
        if (last is ContinueOffer) ...[
          const SizedBox(width: 8),
          TestuPressable(
            onTap: _controller.continueSession,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
              decoration: BoxDecoration(
                color: t.primaryAction,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                L('Continue →', 'Continuar →'),
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.65,
                  color: t.onPrimaryAction,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// The learner's submitted attempt on [q], if any — Sully gets it with a
  /// follow-up so it can answer with the chosen option and confidence.
  Attempt? _attemptFor(TestuQ q) {
    final qi = _qs.indexOf(q);
    for (final e in _controller.transcript.reversed) {
      if (e is Verdict && e.attempt.qi == qi) return e.attempt;
    }
    return null;
  }

  /// Hint: authored copy when the question has one; live questions carry
  /// none, so Sully is asked for one instead (still marks the attempt
  /// assisted).
  void _hint(TestuQ q) {
    _controller.markHintUsed();
    if (q.hint == null) {
      _sendChat(
          L('Give me a hint without revealing the answer.',
              'Dame una pista sin revelar la respuesta.'),
          q: q);
    }
  }

  /// The question the free-text chat is about — the latest one on screen.
  TestuQ? get _chatQ {
    for (final e in _controller.transcript.reversed) {
      final qi = switch (e) {
        Framing f => f.qi,
        Prompt p => p.qi,
        HintNote h => h.qi,
        Verdict v => v.attempt.qi,
        _ => null,
      };
      if (qi != null) return _qs[qi];
    }
    return null;
  }

  /// Sends [text] into the chat as the user. Live questions go to Sully's
  /// real channel; otherwise [offlineAnswer] (or a generic demo line) is
  /// the reply.
  void _sendChat(String text, {TestuQ? q, String? offlineAnswer}) {
    q ??= _chatQ;
    setState(() => _chat.add((_controller.transcript.length, true, text)));
    // Chatting wins over "keep the framing in view": otherwise a hint
    // reply lands below the fold and the auto-scroll snaps back up.
    _anchor = null;
    _scrollDownForced();
    if (q != null && canAskSully(q)) {
      void sullySays(String s) {
        // Only the reply to an open question: the server also posts its
        // own feedback after `chat_tutor_answer`, and the local verdict
        // already covers that. After the 90 s line the next message still
        // counts (late replies append).
        if (!mounted || !(_waitingSully || _lateSully)) return;
        _lateSully = false;
        _sullyTimeout?.cancel();
        setState(() {
          _waitingSully = false;
          _chat.add((_controller.transcript.length, false, s));
        });
        _scrollDown();
      }

      _sullySub ??= sullyReplies().listen(sullySays);
      setState(() {
        _waitingSully = true;
        _lateSully = false;
      });
      // The server acknowledges the follow-up before the tutor answers, and
      // the answer may never come (minsur, 2026-09-02) — don't spin forever.
      _sullyTimeout?.cancel();
      _sullyTimeout = Timer(const Duration(seconds: 90), () {
        if (!_waitingSully) return;
        sullySays(sullySlowReply());
        // ponytail: whatever the tutor posts next is taken as the late
        // answer; match on a reply id when the server sends one.
        _lateSully = true;
      });
      askSully(q, text, attempt: _attemptFor(q))
          .catchError((Object e) => sullySays(sullyFailure(e)));
    } else {
      // The canned demo lines belong to the bundled questions only; a live
      // question that cannot reach the tutor says so instead.
      setState(() => _chat.add((
        _controller.transcript.length,
        false,
        _source is LocalQuestionSource
            ? offlineAnswer ?? sullyDemoReply()
            : sullyUnavailable()
      )));
      _scrollDown();
    }
  }

  void _sendTyped() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _sendChat(text);
  }

  Widget _chatBubble((int, bool, String) c) {
    final (_, user, text) = c;
    if (!user) {
      // Live reply: markdown rendered, citation block, source link.
      return _Rise(
          child: SullyMessage.reply(text,
              bottomPadding: 16, onFollowUp: (s) => _sendChat(s)));
    }
    // The shared sent-message bubble — same as the tutor tab and sheets.
    return _Rise(child: TestuYouMsg(text: text));
  }

  /// Question copy resolves `L()` at load time, so a language flip reloads
  /// it; the transcript's own spans are rebuilt in build().
  void _onLang() {
    // Only the local copy resolves L() at load time; refetching the live
    // batch on a language toggle would be a pointless round trip.
    if (_source is! LocalQuestionSource) return;
    _source.load().then((qs) {
      if (!mounted) return;
      setState(() => _qs = qs);
    });
  }

  void _onEngine() {
    if (!mounted) return;
    final outcome = _controller.outcome;
    if (outcome != null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => TestuDebriefScreen(
              outcome: outcome, questions: _qs, topic: _source.topic)));
      return;
    }
    setState(() {});
    if (_controller.transcript.length > _grownTo) {
      _grownTo = _controller.transcript.length;
      final last = _controller.transcript.last;
      if (last is Framing) {
        _anchor = _anchors[last.qi] ??= GlobalKey();
      } else if (last is! Prompt && last is! HintNote) {
        // Question answered (or a stop challenged): back to chat behavior,
        // otherwise Sully's verdict/challenge lands below the fold unseen.
        _anchor = null;
      }
      _scrollDownForced();
    }
  }

  /// Re-arms the auto-scroll for content the user asked for — a new question,
  /// their own message — as opposed to content that merely grew.
  void _scrollDownForced() {
    _stick = true;
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients || !_stick) return;
      var target = _scroll.position.maxScrollExtent;
      // Bottom-aligning a tall question card pushes the framing bubble and
      // the question text off the top. Never scroll past the current
      // question's framing bubble; letting options run off the bottom is
      // the intended trade.
      final box = _anchor?.currentContext?.findRenderObject();
      if (box is RenderBox) {
        target = math.min(
            target, RenderAbstractViewport.of(box).getOffsetToReveal(box, 0.0).offset);
      }
      _scroll.animateTo(
        target.clamp(_scroll.position.minScrollExtent,
            _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: TestuTokens.curve,
      );
    });
  }

  /// Semantic transcript → chat widgets, rebuilt every build. Entries are
  /// append-only, so positional Element matching keeps per-bubble state
  /// (typing reveal, chip vanish, card selection) across rebuilds.
  Widget _entryWidget(SessionEntry e) {
    final qs = _qs;
    return switch (e) {
      Framing f => KeyedSubtree(
          key: _anchors[f.qi] ??= GlobalKey(),
          child: _framingBubble(qs[f.qi], video: f.video)),
      Prompt p => _questionCard(qs[p.qi]),
      HintNote h => _hintBubble(qs[h.qi]),
      Verdict v => _verdictBubble(qs[v.attempt.qi], v.attempt),
      // Rendered in the dock (bottom of screen), not at its transcript
      // position: a chat with Sully after the verdict must never scroll
      // "Continuar" out of reach (approved 2026-09-03).
      ContinueOffer _ => const SizedBox.shrink(),
      StopChallenge s => _stopChallengeBubble(s.remaining),
      StopFarewell _ => _farewellBubble(),
    };
  }

  Widget _framingBubble(TestuQ q, {required bool video}) {
    if (!video) {
      return _SullyBubble(
          spans: _framingSpans(q), delay: 900, onGrew: _scrollDown);
    }
    return _SullyBubble(
      spans: _framingSpans(q),
      delay: 900,
      onGrew: _scrollDown,
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const _FakePlayer(),
          const SizedBox(height: 12),
          _ChoiceChips(
            chips: [
              (L('I watched it — continue', 'Lo he visto — continuar'),
                  true, _controller.watchedVideo)
            ],
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _framingSpans(TestuQ q) => [
        ...q.framing,
        if (q.whyLink)
          TextSpan(
            // ponytail: decorative link — the explanation sheet doesn't exist.
            text: L(' Why this question?', ' ¿Por qué esta pregunta?'),
            style: TextStyle(
              color: _t.mut,
              decoration: TextDecoration.underline,
              decorationColor: _t.idle,
            ),
          ),
      ];

  Widget _questionCard(TestuQ q) => _QuestionCard(
        q: q,
        onGrew: _scrollDown,
        onHint: () => _hint(q),
        needsConfAck: () => _controller.needsConfAck,
        onConfGate: _confGate,
        onSubmit: (chosen, conf) {
          final intent = _controller.submit(chosen: chosen, confidence: conf);
          // The engine appends the Verdict synchronously when it accepts.
          final last = _controller.transcript.last;
          if (intent != null && last is Verdict) {
            final a = last.attempt;
            _source.reportAttempt(
              qi: a.qi,
              questionId: _qs[a.qi].questionId,
              chosen: chosen,
              confidence: conf,
              correct: a.correct,
            );
          }
          switch (intent) {
            case HapticIntent.medium:
              HapticFeedback.mediumImpact();
            case HapticIntent.heavy:
              HapticFeedback.heavyImpact();
            case null:
              break; // engine refused (raced phase change) — nothing to render
          }
        },
      );

  void _confGate() {
    HapticFeedback.heavyImpact();
    _showConfAck(context, onAck: () {
      _confAcked = true;
      SharedPreferences.getInstance().then((p) => p.setBool(_confAckKey, true));
      _controller.acknowledgeConf();
    });
  }

  Widget _hintBubble(TestuQ q) => _SullyBubble(
        delay: 800,
        onGrew: _scrollDown,
        spans: [
          TextSpan(
              text: L(
                  'I can give you a hint. This will mark the attempt as assisted, so it will count less toward mastery.\n\n',
                  'Puedo darte una pista. Esto marcará el intento como asistido, así que contará menos para tu dominio.\n\n')),
          // Live questions carry no authored hint: Sully's reply follows as a
          // chat bubble instead.
          if (q.hint != null) TextSpan(text: q.hint, style: kItalic),
        ],
      );

  Widget _verdictBubble(TestuQ q, Attempt a) {
    final good = a.correct;
    final conf = a.confidence;
    final List<InlineSpan> spans;
    if (good) {
      spans = [
        TextSpan(
            text: '${L('Correct', 'Correcto')} · ${_conf[conf]}\n',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                letterSpacing: 0.25,
                color: _t.greenText)),
        TextSpan(
            text: conf >= 2
                ? q.good ??
                    L('Correct — and you were certain. That knowledge is consolidating.',
                        'Correcto — y estabas ${G('seguro', 'segura')}. Ese conocimiento se está consolidando.')
                : L('Correct. You marked it "${_conf[conf]}" — this knowledge may not be fully consolidated yet, so I’ll bring it back soon.',
                    'Correcto. Lo marcaste como «${_conf[conf]}» — puede que este conocimiento aún no esté consolidado, así que lo traeré de vuelta pronto.')),
      ];
    } else {
      spans = [
        TextSpan(
            text: conf == 3
                ? '${L('Not quite · you were certain', 'No exactamente · estabas ${G('seguro', 'segura')}')}\n'
                : '${L('Not quite', 'No exactamente')} · ${_conf[conf]}\n',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                letterSpacing: 0.25,
                color: _t.redText)),
        // Backend questions carry no tailored miss copy — fall back to the
        // rationale-free generic line.
        ...(q.bad ??
            [
              TextSpan(
                  text: L('That is not the right answer.',
                      'Esa no es la respuesta correcta.'))
            ]),
        if (conf == 3)
          TextSpan(
              text: L(
                  '\n\nBecause you were certain, I’ve marked this as a priority to revisit — it’s the most valuable kind of finding.',
                  '\n\nComo estabas ${G('seguro', 'segura')}, lo he marcado como prioridad para repasar — es el tipo de hallazgo más valioso.')),
      ];
    }

    return _SullyBubble(
      spans: spans,
      delay: 950,
      onGrew: _scrollDown,
      extra: _VerdictExtras(
        q: q,
        highlightMessageId:
            q.questionId != null && q.questionId == widget.questionId
                ? widget.highlightMessageId
                : null,
        onAsk: (text, offline) =>
            _sendChat(text, q: q, offlineAnswer: offline),
        onFlag: (reason, note) =>
            _source.reportFlag(q: q, reason: reason, note: note),
      ),
    );
  }

  Widget _stopChallengeBubble(int remaining) {
    final qword = remaining == 1
        ? L('one more question', 'una pregunta más')
        : L('$remaining more questions', '$remaining preguntas más');
    return _SullyBubble(
      delay: 900,
      onGrew: _scrollDown,
      spans: [
        TextSpan(
            text: L(
                'Are you sure you want to stop here? You have only $qword to go in this block — finishing it is what moves ${testuLive ? 'your mastery of ' : ''}',
                '¿${G('Seguro', 'Segura')} que quieres parar aquí? Te quedan solo $qword en este bloque — terminarlo es lo que ${testuLive ? 'hace avanzar tu dominio en ' : 'saca '}')),
        // ponytail: live names the topic in play; the "Review soon" band is
        // the demo's script until the backend keeps a per-topic status.
        TextSpan(
            text: testuLive
                ? _source.topic
                : CL('Due diligence', 'Debida diligencia',
                    'Aircraft arrival & chocking', 'Llegada y calzado'),
            style: kItalic),
        TextSpan(
            text: testuLive
                ? L(
                    ' forward. Stopping now records a partial session and slows your mastery.',
                    '. Parar ahora registra una sesión parcial y frena tu dominio.')
                : L(
                    ' out of "Review soon". Stopping now records a partial session and slows your mastery.',
                    ' de «Repasar pronto». Parar ahora registra una sesión parcial y frena tu dominio.')),
      ],
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _ChoiceChips(chips: [
            (L('Keep going', 'Seguir'), true, _controller.continueSession),
            (L('Stop anyway', 'Parar igualmente'), false,
                _controller.confirmStop),
          ]),
        ],
      ),
    );
  }

  Widget _farewellBubble() => _SullyBubble(
        delay: 800,
        spans: [
          TextSpan(
              text: L(
                  'Understood — I’ve recorded today’s attempts. We’ll pick this up exactly where you left it.',
                  'Entendido — he registrado los intentos de hoy. Lo retomaremos exactamente donde lo dejaste.')),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final dock = _dock();
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 4, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TestuEyebrow(
                          // No topic name on the error screen: the source's
                          // fallback title is the prototype's.
                          '${L('LEARN MODE', 'MODO APRENDER')}'
                          '${_error ? '' : ' · ${_source.topic.toUpperCase()}'}',
                          fontSize: 10.5,
                          letterSpacing: 1.47, // +0.14em
                        ),
                      ),
                      TestuIconButton(
                        TestuGlyph.close,
                        onTap: () {
                          // Both exits end a session, so they share one
                          // flow. Nothing answered yet means there is
                          // nothing to challenge — just leave.
                          if (!_controller.hasProgress ||
                              !_controller.requestStop()) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: _controller.progress),
                      duration: const Duration(milliseconds: 600),
                      curve: TestuTokens.curve,
                      builder: (_, v, child) => TestuHairline(v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                NotificationListener<ScrollNotification>(
                  // Only a finger unsticks the list, never the auto-scroll's
                  // own animation — that one ends above the bottom whenever
                  // the anchor clamp holds a question's framing in view.
                  onNotification: (n) {
                    if (n is ScrollStartNotification && n.dragDetails != null) {
                      _stick = false;
                    } else if (n is ScrollUpdateNotification &&
                        n.dragDetails != null) {
                      _stick = n.metrics.extentAfter < _stickSlack;
                    } else if (n is ScrollEndNotification &&
                        n.metrics.extentAfter < _stickSlack) {
                      // A fling that coasted back to the bottom re-arms it.
                      _stick = true;
                    }
                    return false;
                  },
                  child: ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                        18, 14, 18, dock == null ? 40 : 130),
                    children: [
                      // ponytail: the loading state is Sully typing — a delay
                      // longer than any fetch, so the dots never resolve; the
                      // bubble is replaced by the transcript when _boot lands.
                      if (_loading)
                        const _SullyBubble(
                            key: ValueKey('sully-loading'),
                            spans: [],
                            delay: 600000),
                      // ponytail: the error state is Sully saying so, with a
                      // retry chip — no dedicated error widget exists yet.
                      if (_error)
                        _SullyBubble(
                          key: const ValueKey('sully-error'),
                          spans: [
                            TextSpan(
                                text: L(
                                    'I couldn’t load your questions right now. Check your connection and try again.',
                                    'No pude cargar tus preguntas ahora mismo. Revisa tu conexión e inténtalo de nuevo.')),
                          ],
                          extra: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: TestuChip(L('Try again', 'Reintentar'),
                                primary: true, onTap: _retry),
                          ),
                        ),
                      for (final (i, e) in _controller.transcript.indexed) ...[
                        _entryWidget(e),
                        for (final c in _chat)
                          if (c.$1 == i + 1) _chatBubble(c),
                      ],
                      // Live reply pending: Sully's typing indicator. Keyed so
                      // the reply bubble that takes its slot gets a fresh State
                      // (otherwise it inherits these never-ending dots).
                      if (_waitingSully)
                        const _SullyBubble(
                            key: ValueKey('sully-typing'),
                            spans: [],
                            delay: 600000),
                    ],
                  ),
                ),
                if (dock != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding:
                          EdgeInsets.fromLTRB(16, 26, 16, bottomInset + 22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.35],
                          colors: [t.bg.withValues(alpha: 0), t.bg],
                        ),
                      ),
                      child: dock,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Entrance: fade + 10px rise, like the prototype's `up` keyframes.
class _Rise extends StatelessWidget {
  const _Rise({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: TestuTokens.curve,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

/// Sully bubble as the session screen uses it: the shared [SullyMessage]
/// with this screen's entrance animation and bubble spacing.
class _SullyBubble extends StatelessWidget {
  const _SullyBubble({
    super.key,
    required this.spans,
    this.extra,
    this.delay = 850,
    this.onGrew,
  });

  final List<InlineSpan> spans;
  final Widget? extra;
  final int delay;
  final VoidCallback? onGrew;

  @override
  Widget build(BuildContext context) => _Rise(
        child: SullyMessage(
          spans: spans,
          extra: extra,
          delay: delay,
          onGrew: onGrew,
          bottomPadding: 16,
        ),
      );
}

/// Chip row that vanishes once one chip is tapped.
class _ChoiceChips extends StatefulWidget {
  const _ChoiceChips({required this.chips});

  final List<(String, bool, VoidCallback)> chips;

  @override
  State<_ChoiceChips> createState() => _ChoiceChipsState();
}

class _ChoiceChipsState extends State<_ChoiceChips> {
  bool _gone = false;

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, primary, onTap) in widget.chips)
          TestuChip(
            label,
            primary: primary,
            onTap: () {
              setState(() => _gone = true);
              onTap();
            },
          ),
      ],
    );
  }
}

// ponytail: static thumb standing in for the prototype's embedded player —
// becomes a real video once sessions have a media backend.
class _FakePlayer extends StatelessWidget {
  const _FakePlayer();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/img/ramp.jpg', fit: BoxFit.cover),
                  const ColoredBox(color: Color(0x520A0A0B)),
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: t.scrim,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.onImgLine),
                      ),
                      child:
                          TestuIcon(TestuGlyph.play, size: 16, color: t.ink),
                    ),
                  ),
                ],
              ),
            ),
            // The demo clip's credit line; a live build has no demo footage.
            if (!testuLive)
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
                color: t.card2,
                child: Text(
                  L('Turnaround groundhandling, Frankfurt — demo footage · CC BY-SA Lufthansa Cargo',
                      'Handling de turnaround, Fráncfort — metraje de demo · CC BY-SA Lufthansa Cargo'),
                  style: kCaption,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Question card + its confidence bar. Tapping a confidence level submits.
class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    required this.q,
    required this.onGrew,
    required this.onHint,
    required this.needsConfAck,
    required this.onConfGate,
    required this.onSubmit,
  });

  final TestuQ q;
  final VoidCallback onGrew;
  final VoidCallback onHint;
  final bool Function() needsConfAck;
  final VoidCallback onConfGate;
  final void Function(int chosen, int conf) onSubmit;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  int? _sel;
  int? _confSel;
  bool _locked = false;

  void _pickOption(int i) {
    if (_locked) return;
    final grew = _sel == null;
    setState(() => _sel = i);
    if (grew) widget.onGrew();
  }

  void _pickConf(int c) {
    if (_locked || _sel == null) return;
    if (widget.needsConfAck()) {
      widget.onConfGate();
      return; // like the prototype: re-tap a level after acknowledging
    }
    setState(() => _confSel = c);
    Timer(const Duration(milliseconds: 220), () {
      if (!mounted || _locked) return;
      setState(() => _locked = true);
      widget.onSubmit(_sel!, c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final q = widget.q;
    return _Rise(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.kicker,
                  // Live topic titles are backend-sized — cap the kicker.
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'GeistMono',
                    fontWeight: FontWeight.w500,
                    fontSize: 9,
                    letterSpacing: 1.44, // +0.16em, the kicker eyebrow
                    color: t.faint,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  q.text,
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    letterSpacing: -0.16,
                    height: 1.42,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 14),
                if (q.image != null) ...[
                  // Prototype parity: question media is tappable to zoom.
                  q.diagram
                      ? GestureDetector(
                          onTap: () => showTestuZoom(context,
                              asset: q.image!, label: q.kicker),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: t.paper,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Image(
                                image: testuImage(q.image!), height: 150),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: t.line),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                GestureDetector(
                                  onTap: () => showTestuZoom(context,
                                      asset: q.image!,
                                      label: q.caption ?? q.kicker),
                                  child: Image(
                                      image: testuImage(q.image!),
                                      fit: BoxFit.cover),
                                ),
                                // Live questions come with a picture but no
                                // caption (the server's asset text spells
                                // out the answer).
                                if (q.caption != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 7, horizontal: 11),
                                    color: t.card2,
                                    child: Text(
                                      q.caption!,
                                      style: TextStyle(
                                        fontFamily: 'Geist',
                                        fontSize: 10,
                                        color: t.faint,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                  const SizedBox(height: 14),
                ],
                for (var i = 0; i < q.opts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _Option(
                      text: q.opts[i],
                      selected: _sel == i,
                      correct: _locked && i == q.okIdx,
                      wrong: _locked && i == _sel && i != q.okIdx,
                      onTap: () => _pickOption(i),
                    ),
                  ),
                // Authored hint, or a live question Sully can be asked for one.
                if (!_locked && (q.hint != null || canAskSully(q)))
                  TestuPressable(
                    onTap: widget.onHint,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        L('Request a hint', 'Pedir una pista'),
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 11.5,
                          color: t.mut,
                          decoration: TextDecoration.underline,
                          decorationColor: t.idle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_sel != null) ...[
            const SizedBox(height: 8),
            _Rise(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TestuEyebrow.h4(L('HOW CONFIDENT ARE YOU?',
                      '¿CUÁN ${G('SEGURO', 'SEGURA')} ESTÁS?')),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: t.line2),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      // Equal-height cells: a wrapping label ("Bastante
                      // segura") must not leave its siblings shorter with
                      // misaligned top bars.
                      child: IntrinsicHeight(
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var c = 0; c < 4; c++)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _pickConf(c);
                                },
                                child: Container(
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _confSel == c
                                        ? _confSelectedBg[c]
                                        : null,
                                    border: Border(
                                      top: BorderSide(
                                          color: _confColors[c], width: 2),
                                      right: c < 3
                                          ? BorderSide(color: t.line2)
                                          : BorderSide.none,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 11, horizontal: 2),
                                  child: Text(
                                    _conf[c],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      color: _confColors[c],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.text,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final Color border;
    final Color? bg;
    if (correct) {
      border = t.greenBorder;
      bg = t.greenTint;
    } else if (wrong) {
      border = t.redBorder;
      bg = t.redTint;
    } else if (selected) {
      border = t.selectedBorder;
      bg = t.raised;
    } else {
      border = t.line2;
      bg = null;
    }
    final radioBorder = correct
        ? t.green
        : selected
            ? t.ink
            : t.faint;
    return TestuPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: radioBorder, width: 1.5),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.ink,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  height: 1.5,
                  color: t.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Citation, evidence line, message actions, and follow-up chips under a
/// verdict — everything that makes the answer explainable.
class _VerdictExtras extends StatefulWidget {
  const _VerdictExtras(
      {required this.q,
      required this.onAsk,
      required this.onFlag,
      this.highlightMessageId});

  final TestuQ q;

  /// Comment the thread opens on (notification tap); null otherwise.
  final String? highlightMessageId;

  /// Chip tapped: send [question] into the chat as the user; the second
  /// argument is the canned answer used when the session is offline.
  final void Function(String question, String offlineAnswer) onAsk;

  /// Report sheet confirmed: hand (reason id, optional note) to the source.
  /// Resolves when the server has it (live) or at once (demo).
  final Future<void> Function(String reason, String? note) onFlag;

  @override
  State<_VerdictExtras> createState() => _VerdictExtrasState();
}

class _VerdictExtrasState extends State<_VerdictExtras> {
  // "Was this helpful" — same reaction module as threads (app-wide rule).
  // ponytail: base count is demo data; live starts at zero until the
  // backend returns real ones.
  final _qReacts = <TestuReaction, int>{
    if (!testuLive) TestuReaction.like: 12
  };
  TestuReaction? _qMine;
  bool _flagged = false;
  bool _wrongs = false; // "why are the others wrong?" chip consumed
  bool _proc = false; // "show me the full procedure" chip consumed

  void _tap(VoidCallback fn) {
    HapticFeedback.selectionClick();
    setState(fn);
  }

  /// One report surface app-wide: the shared sheet (testu_report_sheet.dart).
  /// Live, the send lands in services/testu/social/flag.json through
  /// [TestuQuestionSource.reportFlag]; the demo records nothing and says so.
  void _openFlagDialog() {
    HapticFeedback.selectionClick();
    final labels = [for (final r in testuFlagReasons) flagReasonLabel(r)];
    showTestuReportSheet(
      context,
      eyebrow: L('QUESTION · REPORT', 'PREGUNTA · REPORTAR'),
      title: L('Report this question', 'Reportar esta pregunta'),
      subtitle: testuLive
          ? L('Goes to the content team with your name and this question.',
              'Llega al equipo de contenido con tu nombre y esta pregunta.')
          : L('Your report is recorded on this device.',
              'Tu reporte queda registrado en este dispositivo.'),
      reasons: labels,
      sentText: testuLive
          ? L('Sent to the content team. Thanks for flagging it.',
              'Enviado al equipo de contenido. Gracias por avisar.')
          : null,
      onSend: (reasonIndex, note) async {
        await widget.onFlag(testuFlagReasons[reasonIndex], note);
        // Demo only: the local bell. Live notices are Part D's.
        if (!testuLive) {
          final reason = labels[reasonIndex];
          addTestuNotice(
            L('Question report recorded', 'Reporte de pregunta registrado'),
            L('\u201c$reason\u201d \u2014 recorded on this device.',
                '\u00ab$reason\u00bb \u2014 registrado en este dispositivo.'),
          );
        }
        if (mounted) _tap(() => _flagged = true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.q;
    final t = TestuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Citation block only exists for authored questions; backend
        // questions carry no source quote.
        if (q.quote != null && q.page != null) const SizedBox(height: 12),
        if (q.quote != null && q.page != null) _quoteBlock(t, q),
        // Backend questions carry no competency framework, so the whole
        // block is omitted rather than rendered with empty labels.
        if (q.skill != null || q.comp != null || q.ob != null) ...[
          const SizedBox(height: 9),
          _box(
            t,
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: L('Evidence recorded · Skill: ',
                        'Evidencia registrada · Habilidad: ')),
                TextSpan(text: q.skill ?? '—', style: _evBold(t)),
                TextSpan(text: L(' · Competency: ', ' · Competencia: ')),
                TextSpan(text: q.comp ?? '—', style: _evBold(t)),
                if (q.ob != null) ...[
                  TextSpan(text: L('\nBehavior: ', '\nConducta: ')),
                  TextSpan(text: '“${q.ob}”', style: _evBold(t)),
                ],
              ]),
              style: kNote,
            ),
          ),
        ],
        const SizedBox(height: 6),
        Row(
          children: [
            TestuReactions(
              reacts: _qReacts,
              mine: _qMine,
              onChanged: (r) {
                // Removing a reaction is not a rating, so only a set one
                // is reported to the console.
                if (r != null) {
                  testuUsage.rate(
                    channel: liveTutorChannelId ?? '',
                    sectionId: q.sectionId ?? '',
                    questionId: q.questionId,
                    helpful: r == TestuReaction.like,
                  );
                }
                setState(() => _qMine = r);
              },
            ),
            const SizedBox(width: 18),
            TestuPressable(
              onTap: () {
                if (!_flagged) _openFlagDialog();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _flagged
                      ? L('Reported', 'Reportada')
                      : L('Report question', 'Reportar pregunta'),
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 10.5,
                    letterSpacing: 0.42,
                    fontWeight: _flagged ? FontWeight.w600 : FontWeight.w400,
                    color: _flagged ? t.orange : t.faint,
                  ),
                ),
              ),
            ),
          ],
        ),
        // Social thread: inline (decided 2026-08-31). Live on the question's
        // channel; the demo keeps its mock thread.
        if (!testuLive || q.questionId != null)
          SocialThreadEntry(
              channel: testuLive && q.questionId != null ? 'q-${q.questionId}' : null,
              highlightMessageId: widget.highlightMessageId),
        const SizedBox(height: 6),
        // Suggested follow-ups: tapping one sends it into the chat as the
        // user's own message; Sully answers in the chat flow.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!_wrongs)
              TestuChip(
                  L('Why are the others wrong?',
                      '¿Por qué las otras están mal?'),
                  onTap: () => _tap(() {
                        _wrongs = true;
                        widget.onAsk(
                            L('Why are the other options wrong?',
                                '¿Por qué las otras opciones están mal?'),
                            _whyWrong(q));
                      })),
            if (!_proc)
              TestuChip(
                  L('Show me the full procedure',
                      'Muéstrame el procedimiento completo'),
                  onTap: () => _tap(() {
                        _proc = true;
                        widget.onAsk(
                            L('Show me the full procedure.',
                                'Muéstrame el procedimiento completo.'),
                            _procedureText(q));
                      })),
          ],
        ),
      ],
    );
  }

  /// One honest line per distractor — generic on purpose, since nothing in
  /// the question data says *why* a given option is wrong.
  String _whyWrong(TestuQ q) {
    final ok = q.opts[q.okIdx];
    return [
      for (var i = 0; i < q.opts.length; i++)
        if (i != q.okIdx)
          L('“${q.opts[i]}” — not the one; “$ok” is what the standard requires.',
              '«${q.opts[i]}» — no es la correcta; «$ok» es lo que exige la norma.'),
    ].join('\n');
  }

  /// The canned "full procedure" answer as chat-bubble text.
  String _procedureText(TestuQ q) {
    if (q.quote != null && q.page != null) {
      return '“${q.quote}”\n— ${q.cite} · p. ${q.page}';
    }
    if (q.bad != null) return q.bad!.map((s) => s.toPlainText()).join();
    return L('The full procedure is not attached to this question yet.',
        'El procedimiento completo aún no está adjunto a esta pregunta.');
  }

  Widget _quoteBlock(TestuTokens t, TestuQ q) => TestuSourceBlock(
        quote: q.quote,
        meta: '${q.cite} · p. ${q.page}',
        label: L('Open source', 'Abrir fuente'),
        onTap: () => openTestuSource(
            context, Cite(quote: q.quote, title: q.cite, page: q.page!)),
      );

  Widget _box(TestuTokens t, Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        decoration: BoxDecoration(
          color: t.field,
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      );

  TextStyle _evBold(TestuTokens t) =>
      TextStyle(fontWeight: FontWeight.w600, color: t.mut);
}

/// First confidence tap: the tap-submits rule, from Sully, once ever.
/// Barrier-dismiss does NOT acknowledge — only the button calls [onAck].
Future<void> _showConfAck(BuildContext context,
    {required VoidCallback onAck}) {
  return showTestuDialog<void>(
    context,
    // Spec: the one dialog a backdrop tap must not close.
    dismissible: false,
    child: Builder(
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The same bubble the tutor speaks in everywhere else.
          SullyMessage(
            delay: 0,
            spans: [
              TextSpan(
                  text: L(
                      'Quick heads-up before your first confidence call: ',
                      'Un aviso antes de tu primera llamada de confianza: ')),
              TextSpan(
                  text: L(
                      'the moment you tap a level, your answer is submitted',
                      'en cuanto toques un nivel, tu respuesta queda enviada'),
                  style: _bold),
              TextSpan(
                  text: CL(
                      ' — there’s no changing it afterwards. Your confidence is part of the answer, so decide it like you would on site.',
                      ' — no se puede cambiar después. Tu confianza es parte de la respuesta, así que decídela como lo harías en la mina.',
                      ' — there’s no changing it afterwards. Your confidence is part of the answer, so decide it like you would on the ramp.',
                      ' — no se puede cambiar después. Tu confianza es parte de la respuesta, así que decídela como lo harías en la rampa.')),
            ],
          ),
          const SizedBox(height: 14),
          TestuButton(
            L('Understood — don’t show this again',
                'Entendido — no volver a mostrar'),
            variant: TestuButtonVariant.primary,
            onTap: () {
              onAck();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    ),
  );
}

/// Debrief — "end with meaning, not a score". Stats and findings are
/// computed from the session's real [SessionOutcome].
class TestuDebriefScreen extends StatelessWidget {
  const TestuDebriefScreen({
    super.key,
    required this.outcome,
    required this.questions,
    required this.topic,
  });

  /// The questions the session ran on — the findings quote their copy.
  final List<TestuQ> questions;

  /// Topic the session ran on; the mastery card is labelled with it.
  final String topic;

  final SessionOutcome outcome;

  void _leave(BuildContext context, int tab) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    TestuShell.tabRequest.value = tab;
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final attempts = outcome.attempts;
    final total = attempts.length;
    final correct = attempts.where((a) => a.correct).length;
    final certainRight =
        attempts.where((a) => a.correct && a.confidence >= 2).length;
    final misconceptions =
        attempts.where((a) => !a.correct && a.confidence == 3).length;
    // ponytail: calibration = confidence matched correctness (conf>=2 iff
    // correct); the backend's real calibration model replaces this.
    final calibrated =
        attempts.where((a) => (a.confidence >= 2) == a.correct).length;
    final calPct = total == 0 ? '—' : '${(100 * calibrated / total).round()}%';
    final mastery = masteryOf(correct, total);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              18, 24, 18, MediaQuery.paddingOf(context).bottom + 40),
          children: [
            TestuEyebrow(
                outcome.completed
                    ? L('SESSION COMPLETE · LEARN MODE',
                        'SESIÓN COMPLETADA · MODO APRENDER')
                    : L('SESSION PAUSED · LEARN MODE',
                        'SESIÓN PAUSADA · MODO APRENDER'),
                color: t.orange),
            const SizedBox(height: 10),
            Text(
              L('Here’s what today’s session means, $testuFirstName.',
                  'Esto es lo que significa la sesión de hoy, $testuFirstName.'),
              style: kH1,
            ),
            const SizedBox(height: 20),
            _SullyBubble(
              delay: 0,
              spans: [
                TextSpan(
                    text: outcome.completed
                        ? L('Solid work. You were right ',
                            'Buen trabajo. Acertaste ')
                        : L(
                            'We stopped partway — every attempt still counts. You were right ',
                            'Paramos a mitad — cada intento cuenta igualmente. Acertaste ')),
                TextSpan(text: L('and', 'y'), style: kItalic),
                TextSpan(
                    text: L(' certain on $certainRight of $total. ',
                        ' con seguridad en $certainRight de $total. ')),
                TextSpan(
                    text: switch (misconceptions) {
                  0 => L('No misconceptions surfaced today.',
                      'Hoy no aparecieron conceptos erróneos.'),
                  1 => L(
                      'One misconception surfaced, and that’s the most valuable find of the day.',
                      'Apareció un concepto erróneo, y ese es el hallazgo más valioso del día.'),
                  _ => L(
                      '$misconceptions misconceptions surfaced — the most valuable finds of the day.',
                      'Aparecieron $misconceptions conceptos erróneos — los hallazgos más valiosos del día.'),
                }),
              ],
            ),
            const SizedBox(height: 2),
            _StatBand([
                _Stat(L('CORRECT', 'CORRECTAS'),
                    child: _statMono('$correct / $total', t.ink)),
                _Stat(L('CALIBRATION', 'CALIBRACIÓN'),
                    child: _statMono(calPct, t.ink)),
                // Live: this session's right/total through the Topics
                // list's thresholds, so 0/5 never reads "Competent". The
                // demo keeps its scripted band.
                _Stat(L('MASTERY', 'DOMINIO'),
                    child: Text(
                      !testuLive
                          ? L('Competent · Strong ↑', 'Competente · Sólido ↑')
                          : mastery.status.isEmpty
                              ? mastery.label
                              : '${mastery.label} · ${mastery.status}',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: testuLive ? mastery.color : t.greenText,
                      ),
                    )),
            ]),
            const SizedBox(height: 18),
            TestuCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, a) in attempts.indexed)
                    _findingRow(a, last: i == total - 1),
                ],
              ),
            ),
            // ponytail: curve is demo-only until the backend has a
            // trajectory; the illustrative painter never shows in live.
            if (!testuLive) ...[
            const SizedBox(height: 18),
            // ponytail: mastery curve is illustrative — real trajectory data
            // arrives with the backend's mastery model.
            TestuCard(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TestuEyebrow.h4(
                      '${L('MASTERY', 'DOMINIO')} · ${topic.toUpperCase()}'),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (_, box) => CustomPaint(
                      size: Size(box.maxWidth, box.maxWidth * 92 / 320),
                      painter: const _CurvePainter(),
                    ),
                  ),
                ],
              ),
            ),
            ],
            const SizedBox(height: 18),
            TestuButton(L('SEE WHAT CHANGED', 'VER QUÉ HA CAMBIADO'),
                variant: TestuButtonVariant.primary,
                onTap: () => _leave(context, 3)),
            const SizedBox(height: 10),
            TestuButton(L('Done for today', 'Terminar por hoy'),
                onTap: () => _leave(context, 0)),
          ],
        ),
      ),
    );
  }

  /// One finding per attempt, in the vocabulary the session copy uses:
  /// certain+correct = reinforced, certain+wrong = misconception,
  /// unsure+correct = fragile, otherwise a plain gap to review.
  Widget _findingRow(Attempt a, {required bool last}) {
    final q = questions[a.qi];
    final hint = a.assisted
        ? L(' Answered with a hint — counts less toward mastery.',
            ' Respondida con pista — cuenta menos para tu dominio.')
        : '';
    final (color, title, body) = switch ((a.correct, a.confidence)) {
      (true, >= 2) => (
          _t.green,
          L('Reinforced', 'Reforzado'),
          L('Certain and correct — consolidating.',
              'Segura y correcta — consolidándose.'),
        ),
      (true, _) => (
          _t.orange,
          L('Fragile', 'Frágil'),
          L('Correct, but you marked it "${_conf[a.confidence]}". This knowledge may not be fully consolidated yet.',
              'Correcta, pero la marcaste como «${_conf[a.confidence]}». Puede que este conocimiento aún no esté consolidado.'),
        ),
      (false, 3) => (
          _t.red,
          L('Misconception', 'Concepto erróneo'),
          L('Incorrect while certain — marked priority to revisit.',
              'Incorrecta estando ${G('seguro', 'segura')} — marcada como prioridad para repasar.'),
        ),
      (false, _) => (
          _t.red,
          L('To review', 'Para repasar'),
          L('Incorrect. You marked it "${_conf[a.confidence]}".',
              'Incorrecta. La marcaste como «${_conf[a.confidence]}».'),
        ),
    };
    return _DebriefRow(
      color: color,
      title: q.skill == null ? title : '$title · ${q.skill}',
      body: '$body$hint',
      last: last,
    );
  }

  static Widget _statMono(String v, Color color) => Text(
        v,
        style: TextStyle(
          fontFamily: 'GeistMono',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: color,
        ),
      );
}

/// The three debrief stat cards. Side by side as approved — but a third of a
/// phone's width is narrower than the word "Competente" past XXL, where it
/// broke mid-word, so at those sizes they stack full width instead.
class _StatBand extends StatelessWidget {
  const _StatBand(this.stats);

  final List<Widget> stats;

  @override
  Widget build(BuildContext context) {
    if (testuBigText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, s) in stats.indexed) ...[
            if (i > 0) const SizedBox(height: 9),
            s,
          ],
        ],
      );
    }
    // IntrinsicHeight: the mastery label wraps to 2 lines, the mono stats
    // don't — cards must still share one height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, s) in stats.indexed) ...[
            if (i > 0) const SizedBox(width: 9),
            Expanded(child: s),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, {required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TestuCard(
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TestuEyebrow.tag(label),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _DebriefRow extends StatelessWidget {
  const _DebriefRow({
    required this.color,
    required this.title,
    required this.body,
    this.last = false,
  });

  final Color color;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: last
          ? null
          : BoxDecoration(border: Border(bottom: BorderSide(color: t.card2))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: kRowTitle),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: kCardBody,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The prototype's mastery-curve SVG, ported: labels, dashed required line,
/// green trajectory, orange "you are here" dot.
class _CurvePainter extends CustomPainter {
  const _CurvePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 320;

    void label(String text, double x, double y, double fs,
        {bool right = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: fs * s,
            color: _t.faint,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // SVG text y is the baseline. right: anchor to the right edge so a
      // longer translation can't paint past the card border.
      final dx = right ? size.width - tp.width - 8 * s : x * s;
      tp.paint(canvas, Offset(dx, y * s - tp.height));
    }

    label(L('Expert', 'Experto'), 2, 12, 9);
    label(L('Competent', 'Competente'), 2, 50, 9);
    label(L('Beginner', 'Principiante'), 2, 88, 9);
    label(L('required · Expert', 'requerido · Experto'), 230, 16, 8.5,
        right: true);

    final dash = Paint()
      ..color = _t.track
      ..strokeWidth = 1;
    var x = 58.0 * s;
    while (x < 320 * s) {
      canvas.drawLine(Offset(x, 22 * s), Offset(x + 3 * s, 22 * s), dash);
      x += 7 * s;
    }

    const pts = [(62.0, 84.0), (108.0, 72.0), (154.0, 60.0), (200.0, 50.0),
        (246.0, 42.0), (288.0, 34.0)];
    final path = Path()..moveTo(pts.first.$1 * s, pts.first.$2 * s);
    for (final (px, py) in pts.skip(1)) {
      path.lineTo(px * s, py * s);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..color = _t.green,
    );
    canvas.drawCircle(
        Offset(288 * s, 34 * s), 4.5 * s, Paint()..color = _t.orange);
  }

  @override
  bool shouldRepaint(_CurvePainter old) => false;
}
