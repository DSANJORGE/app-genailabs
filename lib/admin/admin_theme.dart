import 'package:flutter/material.dart';

import '../testu/testu_theme.dart';

const _t = TestuTokens.instance;

/// Console extension of the app tokens (spec analytics-v1 §5). Same meanings
/// as the app: orange = the thing in focus, the level trio only inside data,
/// hairlines everywhere. Nothing here invents a colour the app doesn't have —
/// the two exceptions are the correct/incorrect series pair (the app's own
/// week-card bars) and the "no data" level, which has no app equivalent.
class AdminTokens {
  /// The selected series — org, team or person being looked at — plus the
  /// active nav tick and the sort caret. One accent, one meaning.
  static final Color focus = _t.orange;

  /// Medians and previous-period ghosts: present, never competing.
  static final Color compare = _t.mut.withValues(alpha: 0.45);

  /// The app's text-red. `TestuTokens.red` is a fill and border colour — as
  /// 11-13 px text on `card`/`card2` it lands at 4.1:1, under the 4.5:1
  /// floor, so error copy and negative deltas use this instead.
  static final Color redText = _t.redText;

  static const Color seriesPositive = Color(0xFF3F7D5F);
  static const Color seriesNegative = Color(0xFF8F4444);

  static final Color grid = _t.line;
  static final Color axis = _t.faint;
  static final Color hover = _t.card2;

  /// The app's "not started" dot.
  static final Color levelNone = _t.idle;

  static Color level(String? level) => switch (level) {
        'expert' => _t.green,
        'competent' => _t.amber,
        'beginner' => _t.red,
        _ => levelNone,
      };

  /// The app's pill border per level (testu_topics.dart:`masteryOf`): a
  /// darker edge of the same hue as the label it wraps.
  static Color levelEdge(String? level) => switch (level) {
        'expert' => _t.greenBorder,
        'competent' => _t.goldBorder,
        'beginner' => _t.redBorder,
        _ => _t.line2,
      };

  /// Fill for a heatmap or table cell carrying a level. 22 % so the text on
  /// top keeps its contrast; the full colour stays for the 1 px inset.
  static Color levelTint(String? level) => level == null
      ? const Color(0xFF141417)
      : AdminTokens.level(level).withValues(alpha: 0.22);

  static final title = TextStyle(
      fontFamily: 'Sora',
      fontWeight: FontWeight.w700,
      fontSize: 20,
      letterSpacing: -0.2,
      color: _t.ink);

  /// The interpretation sentences that open every analytics screen.
  static final reading = TextStyle(
      fontFamily: 'Sora',
      fontWeight: FontWeight.w600,
      fontSize: 14,
      height: 1.45,
      color: _t.ink);

  static final body =
      TextStyle(fontFamily: 'Geist', fontSize: 13, height: 1.5, color: _t.ink);
  static final table =
      TextStyle(fontFamily: 'Geist', fontSize: 12.5, color: _t.ink);
  static final tableHead = TextStyle(
      fontFamily: 'Geist',
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: _t.mut);
  static final muted =
      TextStyle(fontFamily: 'Geist', fontSize: 12, color: _t.mut);

  /// One-line note under a chart. `kNote`'s size and family, but `mut` rather
  /// than `faint` — `faint` measures 3.7:1 on `card` and this is running copy,
  /// not a mono micro-label.
  static final footnote = TextStyle(
      fontFamily: 'Geist', fontSize: 10, height: 1.55, color: _t.mut);

  /// The console's one label style (spec §5): mono uppercase, +0.14em, one
  /// per card. There is deliberately no second small-label style.
  static final eyebrow = TextStyle(
      fontFamily: 'GeistMono',
      fontWeight: FontWeight.w500,
      fontSize: 9.5,
      letterSpacing: 1.33, // +0.14em
      color: _t.mut);

  /// Tracking for the console eyebrow, so widgets that render it through
  /// [TestuEyebrow] land on the same letterform as [eyebrow].
  static const double eyebrowTracking = 1.33;

  /// The console's one tooltip skin: `card2` on a hairline. Every chart,
  /// cell and bar that explains itself on hover wears this one -- four
  /// hand-rolled copies had already drifted apart by a radius.
  static final BoxDecoration tip = BoxDecoration(
    color: _t.card2,
    border: Border.all(color: _t.line),
    borderRadius: BorderRadius.circular(6),
  );

  /// What a tooltip says it in: the table's Geist at 11, tabular so a date
  /// and a count line up, and NOT the mono at w500 the charts used to wear
  /// -- beside a 9.5 px axis that read as the biggest text on the card.
  static final TextStyle tipStyle = TextStyle(
      fontFamily: 'Geist',
      fontSize: 11,
      height: 1.35,
      fontFeatures: const [FontFeature.tabularFigures()],
      color: _t.ink);
  static const EdgeInsets tipPadding = EdgeInsets.fromLTRB(9, 5, 9, 6);

  /// A sequential ramp of the one accent for categorical data that has no
  /// levels (the question themes): [n] steps from `focus` down to a fifth of
  /// it. Blue, violet and gold are app tokens for links, pills and badges,
  /// and in a bar beside orange charts they read as another product's
  /// palette.
  static List<Color> ramp(int n) => [
        for (var i = 0; i < n; i++)
          focus.withValues(alpha: n == 1 ? 1 : 1 - 0.8 * i / (n - 1)),
      ];

  /// How far a table or grid body may run before it scrolls inside its own
  /// box with the header pinned: the viewport less the chrome above a card.
  /// A page-long roster scrolled its header away with the first wheel.
  static double bodyMax(BuildContext c) =>
      (MediaQuery.sizeOf(c).height - 260).clamp(280.0, 2000.0);

  static TextStyle mono(double size, {Color? color}) => TextStyle(
        fontFamily: 'GeistMono',
        fontWeight: FontWeight.w500,
        fontSize: size,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? _t.ink,
      );

  /// Every duration in the console goes through here, so
  /// `MediaQuery.disableAnimations` zeroes the whole surface at once.
  static Duration dur(BuildContext c, int ms) =>
      MediaQuery.of(c).disableAnimations
          ? Duration.zero
          : Duration(milliseconds: ms);
}
