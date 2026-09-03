import 'package:flutter/material.dart';

import 'testu_client.dart';
import 'testu_i18n.dart';

/// Cinematic launch intro (spec: prototype v6 .splash) — breathing glow in
/// the client's brand colour, its wordmark's letters rise in as tracking
/// tightens, a shine sweeps the
/// wordmark, the rule draws like a runway with a landing light at its tip,
/// then the whole thing lifts off. Tap to skip; auto-dismisses at 4.2 s.
class TestuSplash extends StatefulWidget {
  const TestuSplash({super.key, required this.onDone, this.welcomeBack = true});

  final VoidCallback onDone;

  /// false right after a fresh sign-in ("Ana, welcome."), true on a restored
  /// session ("Ana, welcome back.").
  final bool welcomeBack;

  @override
  State<TestuSplash> createState() => _TestuSplashState();
}

class _TestuSplashState extends State<TestuSplash>
    with TickerProviderStateMixin {
  // Main timeline: 0–4200 ms hold, 4200–4800 ms exit.
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4800))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) widget.onDone();
        })
        ..forward();
  late final AnimationController _glow = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat(reverse: true);

  bool _skipping = false;
  bool _reducedMotionApplied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: skip the letter/runway choreography — jump to the
    // settled composition, hold, then the plain exit fade.
    if (!_reducedMotionApplied && MediaQuery.disableAnimationsOf(context)) {
      _reducedMotionApplied = true;
      _glow.stop();
      _glow.value = 0.7;
      _c.value = 3000 / 4800;
    }
  }

  void _skip() {
    if (_skipping) return;
    _skipping = true;
    // Jump to the exit segment so the lift-off still plays.
    if (_c.value < 4200 / 4800) _c.animateTo(1, duration: const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _c.dispose();
    _glow.dispose();
    super.dispose();
  }

  double _seg(double startMs, double endMs, Curve curve) {
    final v = ((_c.value * 4800 - startMs) / (endMs - startMs)).clamp(0.0, 1.0);
    return curve.transform(v);
  }

  static const _house = Cubic(0.22, 0.9, 0.28, 1.0);
  static const _letterCurve = Cubic(0.16, 1, 0.3, 1);

  @override
  Widget build(BuildContext context) {
    final word = client.wordmark;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: _skip,
        child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final exit = _seg(4200, 4800, Curves.easeIn);
          // Tracking tightens: 0.22em → −0.03em at 46 px.
          final tracking = 10.12 + (-1.38 - 10.12) * _seg(150, 1300, _house);
          final rule = _seg(1500, 2200, Curves.easeOut);
          final tip = _seg(1500, 2600, Curves.linear);
          final sub = _seg(1750, 2650, Curves.easeOut);
          final hi = _seg(2350, 2950, _house);
          return Opacity(
            opacity: 1 - exit,
            child: Container(
              color: const Color(0xFF0A0A0B),
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(0, -46 * exit),
                child: Transform.scale(
                  scale: 1 - 0.03 * exit,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Breathing glow.
                      AnimatedBuilder(
                        animation: _glow,
                        builder: (_, child2) => Transform.scale(
                          scale: 0.82 + 0.36 * _glow.value,
                          child: Opacity(
                            opacity: 0.55 + 0.45 * _glow.value,
                            child: Container(
                              width: 340,
                              height: 340,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    client.brand.withAlpha(0x1F),
                                    client.brand.withAlpha(0),
                                  ],
                                  stops: const [0.0, 0.62],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Wordmark: letters rise out of a mask.
                          // ponytail: the prototype's shine sweep needs
                          // mix-blend-mode overlay — skipped, it reads as a
                          // white streak without it.
                          ClipRect(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 16),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var i = 0; i < word.length; i++)
                                    _Letter(
                                      word[i],
                                      tracking: tracking,
                                      t: _seg(120 + i * 80.0,
                                          870 + i * 80.0, _letterCurve),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // Runway rule with landing-light tip.
                          Padding(
                            padding: const EdgeInsets.only(top: 22, bottom: 18),
                            child: SizedBox(
                              width: 150,
                              height: 6,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 150 * rule,
                                    height: 1,
                                    color: const Color(0xFF2C2C33),
                                  ),
                                  if (tip > 0.1 && tip < 1)
                                    Positioned(
                                      left: 150 * rule - 3,
                                      child: Opacity(
                                        opacity: tip < 0.72
                                            ? 1
                                            : 1 - (tip - 0.72) / 0.28,
                                        child: Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: client.brand,
                                            boxShadow: [
                                              BoxShadow(
                                                  color: client.brand
                                                      .withAlpha(0x90),
                                                  blurRadius: 14,
                                                  spreadRadius: 3),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Opacity(
                            opacity: sub,
                            child: Text(
                              'POWERED BY TESTU LEARN',
                              style: TextStyle(
                                fontFamily: 'GeistMono',
                                fontSize: 9,
                                letterSpacing: 1.08 + 1.62 * sub, // .12→.3em
                                color: const Color(0xFF8B8F98),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 34),
                            child: Opacity(
                              opacity: hi,
                              child: Transform.translate(
                                offset: Offset(0, 10 * (1 - hi)),
                                child: Text(
                                  widget.welcomeBack
                                      ? L('${client.persona}, welcome back.',
                                          '${client.persona}, ${G('bienvenido', 'bienvenida')} de nuevo.')
                                      : L('${client.persona}, welcome.',
                                          '${client.persona}, ${G('bienvenido', 'bienvenida')}.'),
                                  style: const TextStyle(
                                    fontFamily: 'Sora',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    letterSpacing: -0.17,
                                    color: Color(0xFFF4F2EE),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

class _Letter extends StatelessWidget {
  const _Letter(this.char, {required this.tracking, required this.t});

  final String char;
  final double tracking;
  final double t;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: tracking.clamp(0, 12)),
      child: Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 52 * (1 - t)),
          child: Transform.scale(
            scale: 1.15 - 0.15 * t,
            child: Text(
              char,
              style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w800,
                fontSize: 46,
                letterSpacing: tracking < 0 ? tracking : 0,
                color: client.brand,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
