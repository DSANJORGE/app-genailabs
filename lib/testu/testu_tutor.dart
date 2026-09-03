import 'package:flutter/material.dart';

import 'testu_i18n.dart';
import 'testu_session.dart';
import 'testu_sully.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';
import 'testu_client.dart';

/// Tutor tab — Sully's standalone chat (spec: Sully on every screen; this is
/// where you talk to him outside a session). One white element: the
/// "Review it now" chip, the adaptive recommendation.
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

  void _enter() {
    setState(() => _in = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _in = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(18, 14, 18, bottomInset + 130),
            children: [
              const _TutorHeader(),
              const SizedBox(height: 18),
              AnimatedSlide(
                offset: _in ? Offset.zero : const Offset(0, 0.04),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: AnimatedOpacity(
                  opacity: _in ? 1 : 0,
                  duration: const Duration(milliseconds: 400),
                  child: _greeting(context, widget.onCalibration),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
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
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _AskBar(bottomInset: bottomInset),
          ),
        ],
      ),
    );
  }
}

class _TutorHeader extends StatelessWidget {
  const _TutorHeader();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Row(
      children: [
        ClipOval(
          child: Image.asset('assets/img/sully.png',
              width: 40, height: 40, fit: BoxFit.cover),
        ),
        const SizedBox(width: 12),
        // Expanded: lets the subtitle wrap instead of overflowing the Row.
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              client.tutor,
              style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w700,
                fontSize: 19,
                letterSpacing: -0.19,
                color: t.ink,
              ),
            ),
            Text(
              L('Your tutor · ${client.name} Ground Operations',
                  'Tu tutor · ${client.name} Operaciones en Tierra'),
              style: kLabel,
            ),
          ],
        )),
      ],
    );
  }
}

Widget _greeting(BuildContext context, VoidCallback onCalibration) {
  return SullyMessage(
    delay: 0,
    spans: [
      TextSpan(
          text: L('Hello ${client.persona}. Yesterday a misconception surfaced '
                  'on ',
              'Hola, ${client.persona}. Ayer apareció un concepto erróneo '
                  'sobre ')),
      TextSpan(
        text: L('chock timing', 'el momento de calzar'),
        style: const TextStyle(
            fontStyle: FontStyle.italic, color: Color(0xFFA9A8A4)),
      ),
      TextSpan(
          text: L(' — I’ve scheduled it into today’s Daily '
                  'Challenge. Want to talk it through first, or '
                  'is there anything else on your mind?',
              ' — lo he añadido al Reto Diario de hoy. ¿Quieres '
                  'repasarlo primero, o hay algo más en lo que '
                  'estés pensando?')),
    ],
    extra: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Chip(L('Review it now', 'Repasarlo ahora'),
              primary: true, onTap: () => showTestuSession(context)),
          _Chip(L('How is my calibration?', '¿Cómo va mi calibración?'),
              onTap: onCalibration),
          // ponytail: free-form tutor answers need the backend.
          _Chip(L('Explain the FOD walk again',
                  'Explícame otra vez la inspección FOD'),
              onTap: _noop),
        ],
      ),
    ),
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
  const _AskBar({required this.bottomInset});

  final double bottomInset;

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
      // House composer in facade mode — same pill as the session chat.
      // ponytail: becomes a live input once Sully talks to the backend.
      child: TestuComposer(
        hint: L('Ask ${client.tutor} anything…', 'Pregunta a ${client.tutor} lo que quieras…'),
        onTap: _noop,
      ),
    );
  }
}

void _noop() {}
