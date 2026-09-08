import 'dart:async';

import 'package:flutter/material.dart';

import 'testu_client.dart';
import 'testu_i18n.dart';
import 'testu_live.dart';
import 'testu_notifications.dart';
import 'testu_session.dart';
import 'testu_sully.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Tutor tab — the tutor's standalone chat (spec: the tutor on every screen;
/// this is where you talk to her outside a session). The header is the
/// room's identity and carries the tab's one avatar; her messages show the
/// name kicker only (Diego, 2026-09-03). One white element: the "Review it
/// now" chip, the adaptive recommendation. The composer is live: a
/// conversation can start with a typed question, not only with a chip.
class TestuTutorScreen extends StatefulWidget {
  const TestuTutorScreen({
    super.key,
    required this.active,
    required this.onCalibration,
  });

  /// True while this tab is the visible one — retriggers the message
  /// entrance, like the prototype re-animating on each visit.
  final bool active;

  /// "How is my calibration?" jumps to the Dashboard tab.
  final VoidCallback onCalibration;

  @override
  State<TestuTutorScreen> createState() => _TestuTutorScreenState();
}

class _TestuTutorScreenState extends State<TestuTutorScreen> {
  bool _in = false;
  final _scroll = ScrollController();

  // Live: the learner's tally per section, fetched once per visit. While it
  // is on its way the tutor is "typing" — the greeting must not claim "no
  // answers yet" about a record that simply hasn't loaded. Null after a
  // failure reads as no record.
  TutorProgress? _progress;
  bool _loadingProgress = false;
  /// The last fetch threw and there is no earlier record to show.
  bool _progressFailed = false;

  // C1: the same conversation on phone and web. Loaded once per screen
  // life, only while nothing was typed here yet.
  bool _loadingHistory = false;

  // (fromUser, text), in order.
  final _chat = <(bool, String)>[];
  bool _waiting = false;
  StreamSubscription<String>? _sub;
  Timer? _timeout;
  bool _late = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _enter();
  }

  @override
  void didUpdateWidget(TestuTutorScreen old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _enter();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _enter() {
    setState(() => _in = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _in = true);
    });
    if (testuLive) {
      _loadingProgress = true;
      _progressFailed = false;
      loadTutorProgress().then((p) {
        if (!mounted) return;
        setState(() {
          _loadingProgress = false;
          if (p != null) _progress = p;
        });
      }).catchError((Object e) {
        debugPrint('TestU: tutor progress ($e)');
        if (mounted) {
          setState(() {
            _loadingProgress = false;
            _progressFailed = _progress == null;
          });
        }
      });
      // ponytail: a failed history load is silent — the greeting stands and
      // re-entering the tab retries; an error card when someone misses it.
      if (_chat.isEmpty && !_loadingHistory) {
        _loadingHistory = true;
        loadTutorHistory().then((turns) {
          if (mounted && _chat.isEmpty && turns.isNotEmpty) {
            setState(() => _chat.addAll(turns));
            _scrollDown();
          }
        }).catchError((Object e) {
          debugPrint('TestU: tutor history ($e)');
        }).whenComplete(() => _loadingHistory = false);
      }
    }
  }

  /// Same live/offline split as the session chat, minus the question.
  void _send(String text) {
    setState(() => _chat.add((true, text)));
    _scrollDown();
    if (!testuLive) {
      setState(() => _chat.add((false, sullyDemoReply())));
      _scrollDown();
      return;
    }
    void says(String s) {
      if (!mounted || !(_waiting || _late)) return;
      _late = false;
      _timeout?.cancel();
      setState(() {
        _waiting = false;
        _chat.add((false, s));
      });
      _scrollDown();
      // Reply landed while the learner was on another tab: the bell says so.
      // Local only — the reply already reached only this learner's channel.
      if (testuLive && !widget.active) {
        addTestuNotice(testuNoticeTitle('tutorreply', ''), noticePreview(s),
            type: 'tutorreply');
      }
    }

    _sub ??= sullyReplies().listen(says);
    setState(() {
      _waiting = true;
      _late = false;
    });
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 90), () {
      if (!_waiting) return;
      says(sullySlowReply());
      // ponytail: the next tutor message is taken as the late answer.
      _late = true;
    });
    askSullyFree(text).catchError((Object e) => says(sullyFailure(e)));
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });

  /// Same words and retry as the dashboard's failed load — one honest
  /// line, never a greeting invented about a record that did not arrive.
  Widget _progressError() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              L('Could not load your progress. Check your connection and try again.',
                  'No se pudo cargar tu progreso. Revisa tu conexión e inténtalo de nuevo.'),
              style: kMeta),
          const SizedBox(height: 12),
          TestuAct(L('Try again', 'Reintentar'), onTap: _enter),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final wide = testuWide(context);
    final thread = [
      AnimatedSlide(
        offset: _in ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 400),
        curve: TestuTokens.curve,
        child: AnimatedOpacity(
          opacity: _in ? 1 : 0,
          duration: const Duration(milliseconds: 400),
          child: !testuLive
              ? _demoGreeting(context, widget.onCalibration, _send)
              : _loadingProgress && _progress == null
                  ? const SullyMessage.typing(
                      key: ValueKey('tutor-loading'),
                      avatar: false,
                      bottomPadding: 16)
                  : _progressFailed
                      ? _progressError()
                      : _liveGreeting(
                          context, _progress, widget.onCalibration, _send),
        ),
      ),
      const SizedBox(height: 14),
      for (final (user, text) in _chat)
        user
            ? TestuYouMsg(text: text)
            : SullyMessage.reply(text,
                avatar: false, bottomPadding: 16, onFollowUp: _send),
      // Keyed so the reply that takes its slot gets a fresh State
      // (otherwise it inherits these never-ending dots).
      if (_waiting)
        const SullyMessage.typing(
            key: ValueKey('tutor-typing'), avatar: false, bottomPadding: 16),
      const _PrivacyNote(),
    ];
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          // The column fills the viewport so the desktop frame can sink the
          // thread to the composer, chat-style, instead of leaving a tall
          // window's void between the last message and the bar. On the
          // phone it starts at the top, as the list did.
          CustomScrollView(
            controller: _scroll,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(18, testuTopPad(context), 18, 0),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Header(),
                      const SizedBox(height: 18),
                      if (wide) const Spacer(),
                      ...thread,
                      // Room for the ask bar (~88) and, on the phone, the
                      // nav. In the column, not the sliver padding: the fill
                      // extent ignores padding after it.
                      SizedBox(height: bottomInset + (wide ? 100 : 130)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _AskBar(bottomInset: bottomInset, onSend: _send),
          ),
        ],
      ),
    );
  }
}

/// The room's identity: 48px face + display name + org line, closed by a
/// hairline. The only avatar on the tab.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            ClipOval(
              child: Image.asset(client.tutorAvatar,
                  width: 48, height: 48, fit: BoxFit.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(client.tutor, style: kH1),
                  if (!testuLive) ...[
                    const SizedBox(height: 2),
                    Text(
                        CL('Tutor ${client.name} Operations',
                            'Tutor ${client.name} Operaciones',
                            'Tutor ${client.name} Ground Operations',
                            'Tutor ${client.name} Operaciones en Tierra'),
                        style: kLabel),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Divider(height: 1, thickness: 1, color: t.line),
      ],
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        testuLive
            ? L('Private to you. ${client.tutor} answers with the source when it finds one; '
                    'when it does not, it says so. Your managers see readiness signals — never this conversation.',
                'Privado para ti. ${client.tutor} responde con la fuente cuando la encuentra; '
                    'si no la encuentra, te lo dice. Tus responsables ven señales de preparación — nunca esta conversación.')
            : L('Private to you. ${client.tutor}’s answers always cite their sources. '
                    'Your managers see readiness signals — never this conversation.',
                'Privado para ti. Las respuestas de ${client.tutor} siempre citan sus fuentes. '
                    'Tus responsables ven señales de preparación — nunca esta conversación.'),
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 10.5,
          height: 1.6,
          color: t.faint,
        ),
      ),
    );
  }
}

/// Live greeting, written from the learner's own record in the live
/// tutorial: the section they last answered and the one they are weakest in
/// (Diego, 2026-09-03). No record yet -> an invitation to start.
Widget _liveGreeting(BuildContext context, TutorProgress? p,
    VoidCallback onCalibration, ValueChanged<String> onAsk) {
  final last = p?.last;
  final weakest = p?.weakest;
  final hi = L('Hello $testuFirstName. ', 'Hola, $testuFirstName. ');
  final spans = <TextSpan>[];
  String score(SectionProgress s) => L('${s.correct} of ${s.total} right',
      '${s.correct} de ${s.total} bien');
  // Section titles come numbered ("2. Empresas y…"); prose reads better bare.
  String name(SectionProgress s) =>
      s.title.replaceFirst(RegExp(r'^\d+\.\s*'), '');

  if (last == null) {
    spans.addAll([
      TextSpan(text: hi + L("I don't have any answers of yours yet in ",
          'Todavía no tengo respuestas tuyas en ')),
      TextSpan(text: p?.tutorialTitle ?? L('your tutorial', 'tu tutorial'),
          style: kItalic),
      TextSpan(text: L('. Shall we start, or is there anything else on your mind?',
          '. ¿Empezamos, o hay algo en lo que estés pensando?')),
    ]);
  } else if (weakest == null || weakest.id == last.id) {
    final clean = weakest == null;
    spans.addAll([
      TextSpan(text: hi + L('The last thing you worked on was ',
          'Lo último que trabajaste fue ')),
      TextSpan(text: name(last), style: kItalic),
      TextSpan(
          text: clean
              ? L(' (${score(last)} — nothing to fix there). Want to keep going, or is there anything else on your mind?',
                  ' (${score(last)}, nada que corregir). ¿Seguimos, o hay algo más en lo que estés pensando?')
              : L(' (${score(last)}) — it is also where you are weakest, so I have marked it to revisit. Want to go over it now, or is there anything else on your mind?',
                  ' (${score(last)}) — y es también donde más flojeas, así que lo he marcado para repasar. ¿Quieres repasarlo ahora, o hay algo más en lo que estés pensando?')),
    ]);
  } else {
    spans.addAll([
      TextSpan(text: hi + L('The last thing you worked on was ',
          'Lo último que trabajaste fue ')),
      TextSpan(text: name(last), style: kItalic),
      TextSpan(text: L(' (${score(last)}). Where you are weakest is ',
          ' (${score(last)}). Donde más flojeas es ')),
      TextSpan(text: name(weakest), style: kItalic),
      TextSpan(
          text: L(' (${score(weakest)}) — I have marked it to revisit. Want to go over it now, or is there anything else on your mind?',
              ' (${score(weakest)}) — lo he marcado para repasar. ¿Quieres repasarlo ahora, o hay algo más en lo que estés pensando?')),
    ]);
  }

  // Third chip: re-explain the weakest section. No progress yet means no
  // real weak spot to ask about — drop the chip rather than fall back to
  // the client's canned question about a subject the learner may not have.
  final ask = weakest == null
      ? null
      : L('Explain ${name(weakest)} again', 'Explícame otra vez ${name(weakest)}');
  return SullyMessage(
    delay: 0,
    avatar: false,
    spans: spans,
    extra: _chips(context, onCalibration, onAsk,
        primary: last == null
            ? L('Start now', 'Empezar ahora')
            : L('Review it now', 'Repasarlo ahora'),
        ask: ask,
        // "Review it now" opens the session on the weakest section.
        sectionId: weakest?.id),
  );
}

Widget _chips(BuildContext context, VoidCallback onCalibration,
    ValueChanged<String> onAsk,
    {required String primary, String? ask, String? sectionId}) {
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        TestuChip(primary,
            primary: true,
            onTap: () => showTestuSession(context, sectionId: sectionId)),
        TestuChip(L('How is my calibration?', '¿Cómo va mi calibración?'),
            onTap: onCalibration),
        // A canned question, sent as if typed — omitted when there is none
        // backed by real progress (live, no answers yet).
        if (ask != null) TestuChip(ask, onTap: () => onAsk(ask)),
      ],
    ),
  );
}

/// Offline demo greeting (Vueling): fixed copy, byte-for-byte as before.
Widget _demoGreeting(BuildContext context, VoidCallback onCalibration,
    ValueChanged<String> onAsk) {
  return SullyMessage(
    delay: 0,
    avatar: false,
    spans: [
      TextSpan(
          text: L('Hello $testuFirstName. Yesterday a misconception surfaced '
                  'on ',
              'Hola, $testuFirstName. Ayer apareció un concepto erróneo '
                  'sobre ')),
      TextSpan(
          text: CL('due diligence', 'la debida diligencia',
              'chock timing', 'el momento de calzar'),
          style: kItalic),
      TextSpan(
          text: L(' — I’ve scheduled it into today’s Daily '
                  'Challenge. Want to talk it through first, or '
                  'is there anything else on your mind?',
              ' — lo he añadido al Reto Diario de hoy. ¿Quieres '
                  'repasarlo primero, o hay algo más en lo que '
                  'estés pensando?')),
    ],
    extra: _chips(context, onCalibration, onAsk,
        primary: L('Review it now', 'Repasarlo ahora'),
        ask: L(client.askEn, client.askEs)),
  );
}

/// Pinned ask bar above the nav, fading up from the page background.
class _AskBar extends StatelessWidget {
  const _AskBar({required this.bottomInset, required this.onSend});

  final double bottomInset;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 26, 16, bottomInset + 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.45],
          colors: [t.bg.withValues(alpha: 0), t.bg],
        ),
      ),
      // House composer, live — same pill as the session chat.
      child: TestuComposer(
        hint: L('Ask ${client.tutor} anything…',
            'Pregunta a ${client.tutor} lo que quieras…'),
        onSend: onSend,
      ),
    );
  }
}
