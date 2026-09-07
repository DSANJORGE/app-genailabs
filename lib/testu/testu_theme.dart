import 'package:flutter/material.dart';

/// TestU Learn design tokens, ported from the `testu-learn-design-spec`
/// Traycer artifact (prototype v6, approved 2026-08-29).
///
/// Each semantic accent has exactly ONE meaning — do not mix:
/// orange = brand/progress, blue = source links only, green = positive,
/// amber = caution, red = negative + destructive, gold = certificates,
/// violet = the Support reaction only.
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

  /// Surfaces one step off the card: the well an expanded row opens into,
  /// the raised box a selected option / sent message sits in, and the
  /// darker field an input sits in on a card.
  final Color well = const Color(0xFF0D0D0F);
  final Color raised = const Color(0xFF1A1A1E);
  final Color field = const Color(0xFF101013);

  /// Hairline track (progress, ring, dashed lines) — one step above line.
  final Color track = const Color(0xFF26262C);

  /// Light "paper" behind a diagram or a rendered document page.
  final Color paper = const Color(0xFFF2F1EC);

  /// "Not started": the idle dot and the underline of a quiet text link.
  final Color idle = const Color(0xFF3A3A40);

  // Text — a 3-step ink ramp above mut/faint (homogenised 2026-09-07: the
  // port carried 13 near-identical off-whites; these are the three roles).
  final Color ink = const Color(0xFFECEBE7);

  /// Reading text inside a conversation (tutor bubbles, options, quotes).
  final Color inkSoft = const Color(0xFFD6D4D0);

  /// Secondary running text: chip labels, comment bodies, list lines.
  final Color inkDim = const Color(0xFFC2C1BD);
  final Color mut = const Color(0xFF8B8F98);
  final Color faint = const Color(0xFF6B6F78);

  /// Selected-but-not-submitted: light border + raised tint (options,
  /// report reasons). White fill is reserved for the CTA.
  final Color selectedBorder = const Color(0xFFB9B7B2);

  /// Over photography / video: the scrim behind on-image controls and the
  /// 22% white hairline around them.
  final Color scrim = const Color(0xCC0A0A0B);
  final Color onImgLine = const Color(0x38FFFFFF);

  /// Modal backdrop: #000 at 66%.
  final Color barrier = const Color(0xA8000000);

  // Semantic accents
  final Color orange = const Color(0xFFE8703A);
  final Color blue = const Color(0xFF7FB2E5);
  final Color green = const Color(0xFF4CA97A);
  final Color greenText = const Color(0xFF7DBB9C);
  final Color amber = const Color(0xFFD9A23F);
  final Color red = const Color(0xFFC25555);
  final Color gold = const Color(0xFFCDB96A);
  final Color violet = const Color(0xFF9D8CD6);

  /// Outlined-pill palettes (spec: pills are outlined, never filled). Text
  /// variant + border per semantic colour; the tints are the dark fills
  /// behind a correct/at-risk/wrong state.
  final Color redText = const Color(0xFFD08B8B);
  final Color greenBorder = const Color(0xFF2F6A4C);
  final Color goldBorder = const Color(0xFF8A7A3A);
  final Color amberBorder = const Color(0xFF7A5C1E);
  final Color redBorder = const Color(0xFF6E3535);
  final Color greenTint = const Color(0xFF12231B);
  final Color amberTint = const Color(0xFF291F10);
  final Color redTint = const Color(0xFF2A1516);

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
/// These are the repeated inline styles, hoisted verbatim — same family, size,
/// height, colour. Anything differing in ANY property stays inline at its call
/// site; the prototype's pixels are approved, so nothing is rounded to a shared
/// value. `final` rather than `const` because the token colours hang off the
/// const [TestuTokens.instance] singleton — which is exactly what
/// `TestuTokens.of(context)` returns.
const _t = TestuTokens.instance;

/// H1 — screen headings, Sora greeting.
final kH1 = TextStyle(
  fontFamily: 'Sora',
  fontWeight: FontWeight.w700,
  fontSize: 22,
  letterSpacing: -0.22,
  height: 1.25,
  color: _t.ink,
);

/// Sheet / dialog title — one step under H1.
final kSheetTitle = TextStyle(
  fontFamily: 'Sora',
  fontWeight: FontWeight.w700,
  fontSize: 17,
  letterSpacing: -0.17,
  height: 1.3,
  color: _t.ink,
);

/// Body / chat. Also the implicit default: Material hands `bodyMedium` to the
/// DefaultTextStyle that every unstyled `Text`/`TextSpan` in TestU inherits.
final kBody = TextStyle(
  fontFamily: 'Geist',
  fontSize: 13.5,
  height: 1.6,
  color: _t.ink,
);

/// The tutor's spoken text — every bubble, every surface.
final kChat = TextStyle(
  fontFamily: 'Geist',
  fontSize: 13.5,
  height: 1.62,
  color: _t.inkSoft,
);

/// Emphasis inside tutor prose (a topic name, a section) — dimmer, italic.
final kItalic = TextStyle(fontStyle: FontStyle.italic, color: _t.inkDim);

/// Title of a list row / settings row / card line.
final kRowTitle = TextStyle(
  fontFamily: 'Geist',
  fontWeight: FontWeight.w600,
  fontSize: 12.5,
  color: _t.ink,
);

/// Running secondary copy inside a card — wraps, so it carries a line height.
final kCardBody = TextStyle(
  fontFamily: 'Geist',
  fontSize: 11.5,
  height: 1.5,
  color: _t.mut,
);

/// Secondary label: a trailing value, an author, a one-line descriptor.
final kLabel = TextStyle(fontFamily: 'Geist', fontSize: 11, color: _t.mut);

/// The sub-line directly under a row/card title.
final kMeta = TextStyle(fontFamily: 'Geist', fontSize: 10.5, color: _t.mut);

/// Explanatory note paragraph — smallest thing that still wraps.
final kNote = TextStyle(
  fontFamily: 'Geist',
  fontSize: 10,
  height: 1.55,
  color: _t.faint,
);

/// Caption / media credit — smallest single-line text.
final kCaption =
    TextStyle(fontFamily: 'Geist', fontSize: 9.5, color: _t.faint);

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
    // The one slot Material itself reads: the DefaultTextStyle every
    // unstyled Text in TestU falls back to. The other six were dead.
    textTheme: TextTheme(bodyMedium: kBody),
    dividerColor: t.line,
    splashFactory: NoSplash.splashFactory,
    extensions: const [t],
  );
}
