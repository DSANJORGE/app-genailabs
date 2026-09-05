import 'dart:async';

import 'package:flutter/material.dart';

import 'testu_client.dart';
import 'testu_i18n.dart';
import 'testu_live.dart';
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

  // Live: the learner's tally per section, fetched once per visit. Null until
  // it arrives (or when it fails): the greeting then reads as "no answers yet".
  TutorProgress? _progress;

  // (fromUser, text), in order.
  final _chat = <(bool, String)>[];
  bool _waiting = false;
  StreamSubscription<String>? _sub;
  Timer? _timeout;

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
      loadTutorProgress().then((p) {
        if (mounted && p != null) setState(() => _progress = p);
      }).catchError((_) {});
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
      if (!mounted || !_waiting) return;
      _timeout?.cancel();
      setState(() {
        _waiting = false;
        _chat.add((false, s));
      });
      _scrollDown();
    }

    _sub ??= sullyReplies().listen(says);
    setState(() => _waiting = true);
    _timeout?.cancel();
    _timeout = Timer(const Duration(seconds: 90), () {
      if (_waiting) says(sullySlowReply());
    });
    askSullyFree(text).catchError((_) => says(sullyUnavailable()));
  }

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          ListView(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(18, 14, 18, bottomInset + 130),
            children: [
              const _Header(),
              const SizedBox(height: 18),
              AnimatedSlide(
                offset: _in ? Offset.zero : const Offset(0, 0.04),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _in ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: testuLive
                      ? _liveGreeting(
                          context, _progress, widget.onCalibration, _send)
                      : _demoGreeting(context, widget.onCalibration, _send),
                ),
              ),
              const SizedBox(height: 14),
              for (final (user, text) in _chat)
                user
                    ? TestuYouMsg(text: text)
                    : SullyMessage.reply(text, avatar: false, bottomPadding: 16),
              // Keyed so the reply that takes its slot gets a fresh State
              // (otherwise it inherits these never-ending dots).
              if (_waiting)
                const SullyMessage(
                    key: ValueKey('tutor-typing'),
                    spans: [],
                    delay: 600000,
                    avatar: false,
                    bottomPadding: 16),
              const _PrivacyNote(),
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
                  const SizedBox(height: 2),
                  Text(
                      CL('Tutor ${client.name} Operations',
                          'Tutor ${client.name} Operaciones',
                          'Tutor ${client.name} Ground Operations',
                          'Tutor ${client.name} Operaciones en Tierra'),
                      style: kLabel),
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
        L('Private to you. ${client.tutor}’s answers always cite their sources. '
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

const _ital = TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFA9A8A4));

/// Live greeting, written from the learner's own record in the live
/// tutorial: the section they last answered and the one they are weakest in
/// (Diego, 2026-09-03). No record yet -> an invitation to start.
Widget _liveGreeting(BuildContext context, TutorProgress? p,
    VoidCallback onCalibration, ValueChanged<String> onAsk) {
  final last = p?.last;
  final weakest = p?.weakest;
  final hi = L('Hello ${client.persona}. ', 'Hola, ${client.persona}. ');
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
          style: _ital),
      TextSpan(text: L('. Shall we start, or is there anything else on your mind?',
          '. ¿Empezamos, o hay algo en lo que estés pensando?')),
    ]);
  } else if (weakest == null || weakest.id == last.id) {
    final clean = weakest == null;
    spans.addAll([
      TextSpan(text: hi + L('The last thing you worked on was ',
          'Lo último que trabajaste fue ')),
      TextSpan(text: name(last), style: _ital),
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
      TextSpan(text: name(last), style: _ital),
      TextSpan(text: L(' (${score(last)}). Where you are weakest is ',
          ' (${score(last)}). Donde más flojeas es ')),
      TextSpan(text: name(weakest), style: _ital),
      TextSpan(
          text: L(' (${score(weakest)}) — I have marked it to revisit. Want to go over it now, or is there anything else on your mind?',
              ' (${score(weakest)}) — lo he marcado para repasar. ¿Quieres repasarlo ahora, o hay algo más en lo que estés pensando?')),
    ]);
  }

  // Third chip: re-explain the weakest section; the client's canned question
  // until there is one.
  final ask = weakest == null
      ? L(client.askEn, client.askEs)
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
    {required String primary, required String ask, String? sectionId}) {
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Chip(primary,
            primary: true,
            onTap: () => showTestuSession(context, sectionId: sectionId)),
        _Chip(L('How is my calibration?', '¿Cómo va mi calibración?'),
            onTap: onCalibration),
        // A canned question: sent as if typed.
        _Chip(ask, onTap: () => onAsk(ask)),
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
          text: L('Hello ${client.persona}. Yesterday a misconception surfaced '
                  'on ',
              'Hola, ${client.persona}. Ayer apareció un concepto erróneo '
                  'sobre ')),
      TextSpan(
          text: CL('due diligence', 'la debida diligencia',
              'chock timing', 'el momento de calzar'),
          style: _ital),
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

/// Suggestion chip — outlined, or white when it's the adaptive recommendation.
class _Chip extends StatelessWidget {
  const _Chip(this.label, {this.primary = false, required this.onTap});

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: primary ? t.primaryAction : null,
          border: Border.all(color: primary ? t.primaryAction : t.line2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 11.5,
            fontWeight: primary ? FontWeight.w700 : FontWeight.w400,
            color: primary ? t.onPrimaryAction : const Color(0xFFC2C1BD),
          ),
        ),
      ),
    );
  }
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
