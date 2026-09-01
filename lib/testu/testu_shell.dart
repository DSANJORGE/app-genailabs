import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_dashboard.dart';
import 'testu_i18n.dart';
import 'testu_profile.dart';
import 'testu_schedule_sheet.dart';
import 'testu_session.dart';
import 'testu_theme.dart';
import 'testu_topics.dart';
import 'testu_tutor.dart';
import 'testu_widgets.dart';

/// TestU Learn shell: four-tab surface with the pinned translucent bottom nav
/// (spec: screens artifact — Today · Topics · Tutor · Dashboard).
class TestuShell extends StatefulWidget {
  const TestuShell({super.key});

  /// Debrief CTAs land on a specific tab after popping back to the shell.
  static final tabRequest = ValueNotifier<int?>(null);

  @override
  State<TestuShell> createState() => _TestuShellState();
}

class _TestuShellState extends State<TestuShell> {
  int _tab = 0;

  List<String> get _tabs => [
        L('TODAY', 'HOY'),
        L('TOPICS', 'TEMAS'),
        L('TUTOR', 'TUTOR'),
        L('DASHBOARD', 'DASHBOARD'),
      ];

  @override
  void initState() {
    super.initState();
    TestuShell.tabRequest.addListener(_onTabRequest);
    testuLang.addListener(_onLang);
  }

  @override
  void dispose() {
    TestuShell.tabRequest.removeListener(_onTabRequest);
    testuLang.removeListener(_onLang);
    super.dispose();
  }

  // Language switch: remount the tabs so every (const) subtree re-reads L().
  void _onLang() => setState(() {});

  void _onTabRequest() {
    final i = TestuShell.tabRequest.value;
    if (i != null) {
      TestuShell.tabRequest.value = null;
      setState(() => _tab = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody so screen content scrolls (blurred) underneath the nav.
      extendBody: true,
      body: KeyedSubtree(
        key: ValueKey(testuLang.value),
        child: IndexedStack(
          index: _tab,
          children: [
            const TestuTodayScreen(),
            const TestuTopicsScreen(),
            TestuTutorScreen(
              active: _tab == 2,
              onCalibration: () => setState(() => _tab = 3),
            ),
            const TestuDashboardScreen(),
          ],
        ),
      ),
      bottomNavigationBar: TestuNav(
        items: _tabs,
        current: _tab,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _tab = i);
        },
      ),
    );
  }
}

/// Spec: translucent #0b0b0d @94% + 16px blur, top hairline, text-only mono
/// 9.5px labels, active = lighter + 2px orange tick above. Pinned to the
/// viewport — never inside a scrollable.
class TestuNav extends StatelessWidget {
  const TestuNav({
    super.key,
    required this.items,
    required this.current,
    required this.onTap,
  });

  final List<String> items;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF00B0B0D), // #0b0b0d at 94%
            border: Border(top: BorderSide(color: t.line)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: TestuTokens.curve,
                            height: 2,
                            width: 26,
                            color: i == current ? t.orange : Colors.transparent,
                          ),
                          const SizedBox(height: 9),
                          Text(
                            items[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'GeistMono',
                              fontWeight: FontWeight.w500,
                              fontSize: 9.5,
                              letterSpacing: 1.14, // +0.12em
                              color: i == current ? t.ink : t.faint,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Today (home) — Sully's daily plan in the PRD's mandated priority order.
/// Header is pinned; cards scroll underneath with a 16px fade.
class TestuTodayScreen extends StatefulWidget {
  const TestuTodayScreen({super.key});

  @override
  State<TestuTodayScreen> createState() => _TestuTodayScreenState();
}

class _TestuTodayScreenState extends State<TestuTodayScreen> {
  // One white CTA per screen: null → Schedule is white; once scheduled the
  // white hands off to the hero CTA and Schedule shows a green ✓ ghost.
  String? _scheduled;

  void _openSchedule() {
    showTestuScheduleSheet(
      context,
      onScheduled: (label) => setState(() => _scheduled = label),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const _TodayHeader(),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
                  children: [
                    _CertificationCard(
                        scheduled: _scheduled, onSchedule: _openSchedule),
                    const SizedBox(height: 11),
                    const _DailyChallengeCard(),
                    const SizedBox(height: 12),
                    _ContinueHero(promoted: _scheduled != null),
                    const SizedBox(height: 12),
                    const _RiskNote(),
                  ],
                ),
                // Cards fade out as they slide under the pinned header.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 16,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [t.bg, t.bg.withValues(alpha: 0)],
                        ),
                      ),
                    ),
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

class _TodayHeader extends StatelessWidget {
  const _TodayHeader();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    L('Friday, August 29 · Vueling Ground Operations · BCN',
                        'Viernes, 29 de agosto · Vueling Operaciones en Tierra · BCN'),
                    style: kCardBody,
                  ),
                ),
              ),
              // Profile & settings opens from here, not from the nav.
              TestuPressable(
                onTap: () => showTestuProfile(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.line2),
                  ),
                  child: ValueListenableBuilder<String>(
                    valueListenable: testuAvatar,
                    builder: (_, src, child) => ClipOval(
                      child: Image(
                          image: testuAvatarImage(src), fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: kH1,
              children: [
                TextSpan(
                    text: L('Good morning, Ana.\nHere’s what ',
                        'Buenos días, Ana.\nEsto es lo que ')),
                TextSpan(text: 'Sully', style: TextStyle(color: t.orange)),
                TextSpan(
                    text: L(' recommends today.', ' te recomienda hoy.')),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              ClipOval(
                child: Image.asset('assets/img/sully.png',
                    width: 40, height: 40, fit: BoxFit.cover),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L('SULLY · YOUR TUTOR', 'SULLY · TU TUTOR'),
                      style: TextStyle(
                        fontFamily: 'GeistMono',
                        fontSize: 9,
                        letterSpacing: 1.44, // +0.16em
                        color: t.faint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      L('Two priorities today — one certification deadline, then reinforcement.',
                          'Dos prioridades hoy — una certificación que vence, y después refuerzo.'),
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12,
                        color: Color(0xFFC9C8C4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CertificationCard extends StatelessWidget {
  const _CertificationCard({required this.scheduled, required this.onSchedule});

  /// Confirmed slot label, or null while unscheduled.
  final String? scheduled;
  final VoidCallback onSchedule;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuCard(
      accent: t.amber,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TestuEyebrow(L('CERTIFICATION', 'CERTIFICACIÓN'), color: t.amber),
          const SizedBox(height: 7),
          _CardTitle(L('Ramp Safety certificate expires in 12 days',
              'Tu certificado de Seguridad en Rampa caduca en 12 días')),
          const SizedBox(height: 4),
          _CardBody(L(
              'Sully says: complete the renewal evaluation this week to keep your readiness status stable.',
              'Sully dice: completa la evaluación de renovación esta semana para mantener estable tu preparación.')),
          const SizedBox(height: 12),
          scheduled == null
              ? TestuAct(L('Schedule evaluation', 'Programar evaluación'),
                  primary: true, onTap: onSchedule)
              : TestuAct('✓ ${L('Scheduled', 'Programada')} · $scheduled',
                  borderColor: const Color(0xFF2F6A4C),
                  color: t.greenText,
                  onTap: onSchedule),
        ],
      ),
    );
  }
}

class _DailyChallengeCard extends StatelessWidget {
  const _DailyChallengeCard();

  @override
  Widget build(BuildContext context) {
    return TestuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TestuEyebrow(L('DAILY CHALLENGE', 'RETO DIARIO')),
          const SizedBox(height: 10),
          Row(
            children: [
              const _ChallengeRing(fraction: 0.5, label: '5/10'),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardTitle(L(
                        'Cross-topic reinforcement', 'Refuerzo entre temas')),
                    const SizedBox(height: 4),
                    _CardBody(L(
                        '5 questions remaining · about 4 minutes. Today revisits your fragile answers from Tuesday.',
                        'Quedan 5 preguntas · unos 4 minutos. Hoy repasamos tus respuestas frágiles del martes.')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TestuAct(L('Continue with Sully', 'Continuar con Sully'),
              onTap: () => showTestuSession(context)),
        ],
      ),
    );
  }
}

class _ContinueHero extends StatelessWidget {
  const _ContinueHero({required this.promoted});

  /// True once the evaluation is scheduled — the CTA handoff makes this the
  /// screen's white button.
  final bool promoted;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuPressable(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TestuTopicHomeScreen())),
      child: SizedBox(
        height: 340,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/img/ramp.jpg',
                fit: BoxFit.cover,
                alignment: const Alignment(0, 0.44), // center 72%
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: [0.25, 0.72, 1.0],
                    colors: [
                      Color(0x080A0A0B),
                      Color(0xD80A0A0B),
                      Color(0xF80A0A0B),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TestuEyebrow(
                        L('CONTINUE LEARN MODE', 'CONTINUAR MODO APRENDER'),
                        color: t.orange),
                    const SizedBox(height: 8),
                    Text(
                      L('Ramp Safety & Aircraft Turnaround',
                          'Seguridad en Rampa y Turnaround'),
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                        letterSpacing: -0.2,
                        height: 1.2,
                        color: t.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        TestuPill(
                            L('Competent · Review soon',
                                'Competente · Repasar pronto'),
                            color: t.gold,
                            borderColor: const Color(0xFF8A7A3A)),
                        const SizedBox(width: 10),
                        // Flexible: overflows at 360dp otherwise (Spanish).
                        Flexible(
                          child: Text(
                            L('21 of 36 questions', '21 de 36 preguntas'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 11.5,
                              color: Color(0xFFB5B4B0),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const TestuHairline(0.58, trackColor: Color(0x28FFFFFF)),
                    const SizedBox(height: 14),
                    // Quiet until the evaluation is scheduled, then promoted
                    // to white (one white CTA per screen).
                    TestuButton(
                        L('CONTINUE WITH YOUR TUTOR', 'CONTINUAR CON TU TUTOR'),
                        variant: promoted
                            ? TestuButtonVariant.primary
                            : TestuButtonVariant.onimg,
                        onTap: () => showTestuSession(context)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RiskNote extends StatelessWidget {
  const _RiskNote();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuCard(
      accent: t.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TestuEyebrow(L('NEEDS REINFORCEMENT', 'NECESITA REFUERZO'),
              color: const Color(0xFFD08B8B)),
          const SizedBox(height: 7),
          _CardBody(L(
              'Radio Communication needs reinforcement. Sully recommends a 10-minute session today.',
              'Comunicación por Radio necesita refuerzo. Sully recomienda una sesión de 10 minutos hoy.')),
          const SizedBox(height: 10),
          TestuAct(L('Start training', 'Empezar a entrenar'),
              onTap: () => showTestuSession(context)),
        ],
      ),
    );
  }
}

/// Orange progress ring (Daily Challenge only — the sole ring in the app).
class _ChallengeRing extends StatelessWidget {
  const _ChallengeRing({required this.fraction, required this.label});

  final double fraction;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return SizedBox(
      width: 52,
      height: 52,
      child: CustomPaint(
        painter: _RingPainter(fraction: fraction, color: t.orange),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'GeistMono',
              fontWeight: FontWeight.w500,
              fontSize: 10.5,
              color: Color(0xFFD8D7D3),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = 21.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, paint..color = const Color(0xFF26262C));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // start at 12 o'clock
      6.2832 * fraction,
      false,
      paint
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.color != color;
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: 'Geist',
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Color(0xFFE9E8E4),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Geist',
        fontSize: 12,
        height: 1.55,
        color: t.mut,
      ),
    );
  }
}

