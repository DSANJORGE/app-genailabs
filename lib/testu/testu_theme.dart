import 'package:flutter/material.dart';

/// TestU Learn design tokens, ported from the `testu-learn-design-spec`
/// Traycer artifact (prototype v6, approved 2026-08-29).
///
/// Each semantic accent has exactly ONE meaning — do not mix:
/// orange = brand/progress, blue = source links only, green = positive,
/// amber = caution, red = negative + destructive, gold = certificates.
@immutable
class TestuTokens extends ThemeExtension<TestuTokens> {
  const TestuTokens._();

  static const instance = TestuTokens._();

  // Backgrounds & lines
  final Color bg = const Color(0xFF0A0A0B);
  final Color card = const Color(0xFF121215);
  final Color card2 = const Color(0xFF17171B);
  final Color line = const Color(0xFF222227);
  final Color line2 = const Color(0xFF2C2C33);

  // Text
  final Color ink = const Color(0xFFECEBE7);
  final Color mut = const Color(0xFF8B8F98);
  final Color faint = const Color(0xFF6B6F78);

  // Semantic accents
  final Color orange = const Color(0xFFE8703A);
  final Color blue = const Color(0xFF7FB2E5);
  final Color green = const Color(0xFF4CA97A);
  final Color greenText = const Color(0xFF7DBB9C);
  final Color amber = const Color(0xFFD9A23F);
  final Color red = const Color(0xFFC25555);
  final Color gold = const Color(0xFFCDB96A);

  // The white CTA — the only filled button color in the app.
  final Color primaryAction = const Color(0xFFF4F2EE);
  final Color onPrimaryAction = const Color(0xFF0A0A0B);

  // Confidence ramp (colors the confidence bar and nothing else)
  final Color confGuessing = const Color(0xFFC25555);
  final Color confUnsure = const Color(0xFFD9A23F);
  final Color confFairlySure = const Color(0xFF9DB55C);
  final Color confCertain = const Color(0xFF4CA97A);

  /// House motion curve — cubic-bezier(.22,.9,.28,1). No bounce, no elastic.
  static const Curve curve = Cubic(0.22, 0.9, 0.28, 1.0);

  static TestuTokens of(BuildContext context) =>
      Theme.of(context).extension<TestuTokens>()!;

  @override
  TestuTokens copyWith() => this;

  @override
  TestuTokens lerp(TestuTokens? other, double t) => this;
}

/// Typography scale from the spec (390pt frame):
/// Sora = display (headings, greetings, question text, −0.01em),
/// Geist = everything else, GeistMono = uppercase tracked micro-labels.
TextTheme _testuTextTheme(TestuTokens t) => TextTheme(
      // Splash / big display moments ("Ana, welcome back.")
      displaySmall: TextStyle(
        fontFamily: 'Sora',
        fontWeight: FontWeight.w800,
        fontSize: 26,
        letterSpacing: -0.26,
        height: 1.2,
        color: t.ink,
      ),
      // H1 — screen headings, Sora greeting
      headlineSmall: TextStyle(
        fontFamily: 'Sora',
        fontWeight: FontWeight.w700,
        fontSize: 22,
        letterSpacing: -0.22,
        height: 1.25,
        color: t.ink,
      ),
      // Question text / sheet titles
      titleMedium: TextStyle(
        fontFamily: 'Sora',
        fontWeight: FontWeight.w700,
        fontSize: 15.5,
        letterSpacing: -0.15,
        height: 1.4,
        color: t.ink,
      ),
      // Body / chat
      bodyMedium: TextStyle(
        fontFamily: 'Geist',
        fontSize: 13.5,
        height: 1.6,
        color: t.ink,
      ),
      // Secondary text
      bodySmall: TextStyle(
        fontFamily: 'Geist',
        fontSize: 11.5,
        height: 1.5,
        color: t.mut,
      ),
      // Buttons / options
      labelLarge: TextStyle(
        fontFamily: 'Geist',
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: t.ink,
      ),
      // Mono micro-labels: eyebrows, nav items, numbers. Uppercase at call
      // site — Flutter has no text-transform.
      labelSmall: TextStyle(
        fontFamily: 'GeistMono',
        fontWeight: FontWeight.w500,
        fontSize: 10,
        letterSpacing: 1.5, // ≈ +0.15em
        color: t.faint,
      ),
    );

/// The TestU Learn [ThemeData]. Wrap TestU screens in this (via `Theme` or a
/// dedicated route/navigator); the rest of the app keeps its own theme.
ThemeData testuTheme() {
  const t = TestuTokens.instance;
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Geist',
    scaffoldBackgroundColor: t.bg,
    colorScheme: ColorScheme.dark(
      surface: t.bg,
      surfaceContainer: t.card,
      primary: t.primaryAction,
      onPrimary: t.onPrimaryAction,
      secondary: t.orange,
      error: t.red,
      outline: t.line,
      outlineVariant: t.line2,
      onSurface: t.ink,
      onSurfaceVariant: t.mut,
    ),
    textTheme: _testuTextTheme(t),
    dividerColor: t.line,
    splashFactory: NoSplash.splashFactory,
    extensions: const [t],
  );
}
