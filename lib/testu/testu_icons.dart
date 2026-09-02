import 'package:flutter/material.dart';

/// House icon set — hand-drawn 1.5px stroke line glyphs, no emoji, no
/// Material icon font (PRODUCT.md: emoji is an anti-reference). One style
/// everywhere: round caps, 24-unit grid, color from the caller.
///
/// Add glyphs here, never inline emoji/unicode pictographs in screens.
/// thumbUp..laugh are the six reaction glyphs (LinkedIn-style Like menu).
enum TestuGlyph {
  thumbUp,
  applause,
  support,
  love,
  idea,
  laugh,
  chat,
  bell,
  send,
  expand,
  faceId,
}

class TestuIcon extends StatelessWidget {
  const TestuIcon(this.glyph,
      {super.key, this.size = 14, required this.color, this.fill = false});

  final TestuGlyph glyph;
  final double size;
  final Color color;

  /// Filled = active state (e.g. your own vote).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(glyph, color, fill),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter(this.glyph, this.color, this.fill);

  final TestuGlyph glyph;
  final Color color;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2.0 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    Path p;
    switch (glyph) {
      case TestuGlyph.thumbUp:
        p = _thumb(s);
      case TestuGlyph.applause:
        // Two raised mitts in a V + impact ticks between them.
        p = Path()
          ..addPath(_mitt(s, -0.35, Offset(9.2 * s, 20.5 * s)), Offset.zero)
          ..addPath(_mitt(s, 0.35, Offset(14.8 * s, 20.5 * s)), Offset.zero)
          ..moveTo(6.6 * s, 5.6 * s)
          ..lineTo(5.4 * s, 3.6 * s)
          ..moveTo(12 * s, 4.4 * s)
          ..lineTo(12 * s, 2.1 * s)
          ..moveTo(17.4 * s, 5.6 * s)
          ..lineTo(18.6 * s, 3.6 * s);
      case TestuGlyph.support:
        // Small heart held in an open cupped hand.
        p = Path()
          ..addPath(
              _heart(s).transform((Matrix4.translationValues(12 * s, 8 * s, 0)
                    ..scaleByDouble(0.52, 0.52, 0.52, 1)
                    ..translateByDouble(-12 * s, -12.5 * s, 0, 1))
                  .storage),
              Offset.zero)
          ..moveTo(5 * s, 14 * s)
          ..cubicTo(5 * s, 19 * s, 8 * s, 21.5 * s, 12 * s, 21.5 * s)
          ..cubicTo(16 * s, 21.5 * s, 19 * s, 19 * s, 19 * s, 14 * s);
      case TestuGlyph.love:
        p = _heart(s);
      case TestuGlyph.idea:
        // Bulb dome + neck + filament base.
        canvas.drawArc(
            Rect.fromCircle(center: Offset(12 * s, 9 * s), radius: 4.8 * s),
            0.76,
            -4.66,
            false,
            stroke);
        p = Path()
          ..moveTo(8.2 * s, 12.6 * s)
          ..lineTo(9 * s, 16.5 * s)
          ..lineTo(15 * s, 16.5 * s)
          ..lineTo(15.8 * s, 12.6 * s)
          ..moveTo(10 * s, 20 * s)
          ..lineTo(14 * s, 20 * s);
      case TestuGlyph.laugh:
        canvas.drawCircle(Offset(12 * s, 12 * s), 9 * s, stroke);
        canvas.drawArc(
            Rect.fromCircle(center: Offset(12 * s, 12.4 * s), radius: 4.6 * s),
            0.4,
            2.34,
            false,
            stroke);
        p = Path()
          ..moveTo(8.3 * s, 9.2 * s)
          ..lineTo(9.3 * s, 9.2 * s)
          ..moveTo(14.7 * s, 9.2 * s)
          ..lineTo(15.7 * s, 9.2 * s);
      case TestuGlyph.chat:
        // Speech bubble, bottom-left tail folded into the outline.
        p = Path()
          ..moveTo(21 * s, 15 * s)
          ..arcToPoint(Offset(19 * s, 17 * s), radius: Radius.circular(2 * s))
          ..lineTo(7 * s, 17 * s)
          ..lineTo(3 * s, 21 * s)
          ..lineTo(3 * s, 5 * s)
          ..arcToPoint(Offset(5 * s, 3 * s), radius: Radius.circular(2 * s))
          ..lineTo(19 * s, 3 * s)
          ..arcToPoint(Offset(21 * s, 5 * s), radius: Radius.circular(2 * s))
          ..close();
      case TestuGlyph.bell:
        p = Path()
          ..moveTo(5 * s, 17 * s)
          ..lineTo(19 * s, 17 * s)
          ..lineTo(17.5 * s, 14.5 * s)
          ..lineTo(17.5 * s, 10 * s)
          ..arcToPoint(Offset(6.5 * s, 10 * s),
              radius: Radius.circular(5.5 * s), clockwise: false)
          ..lineTo(6.5 * s, 14.5 * s)
          ..close();
        canvas.drawPath(p, stroke);
        // Clapper — tiny arc under the body, always stroked.
        canvas.drawArc(
            Rect.fromCircle(center: Offset(12 * s, 19 * s), radius: 2.2 * s),
            0.35,
            2.44,
            false,
            stroke..style = PaintingStyle.stroke);
        return;
      case TestuGlyph.send:
        // Up arrow in the house style (composer send).
        canvas.drawLine(
            Offset(12 * s, 19 * s), Offset(12 * s, 5.5 * s), stroke);
        canvas.drawPath(
            Path()
              ..moveTo(6.5 * s, 11 * s)
              ..lineTo(12 * s, 5.5 * s)
              ..lineTo(17.5 * s, 11 * s),
            stroke..style = PaintingStyle.stroke);
        return;
      case TestuGlyph.faceId:
        // Face ID: four corner brackets around two eyes + a smile.
        stroke.style = PaintingStyle.stroke;
        canvas.drawPath(
            Path()
              // Corner brackets.
              ..moveTo(3 * s, 8.5 * s)
              ..lineTo(3 * s, 5 * s)
              ..lineTo(6.5 * s, 5 * s)
              ..moveTo(17.5 * s, 5 * s)
              ..lineTo(21 * s, 5 * s)
              ..lineTo(21 * s, 8.5 * s)
              ..moveTo(21 * s, 15.5 * s)
              ..lineTo(21 * s, 19 * s)
              ..lineTo(17.5 * s, 19 * s)
              ..moveTo(6.5 * s, 19 * s)
              ..lineTo(3 * s, 19 * s)
              ..lineTo(3 * s, 15.5 * s)
              // Eyes.
              ..moveTo(9 * s, 9.5 * s)
              ..lineTo(9 * s, 11.5 * s)
              ..moveTo(15 * s, 9.5 * s)
              ..lineTo(15 * s, 11.5 * s)
              // Smile.
              ..moveTo(9 * s, 14.5 * s)
              ..cubicTo(10.4 * s, 16.2 * s, 13.6 * s, 16.2 * s, 15 * s,
                  14.5 * s),
            stroke);
        return;
      case TestuGlyph.expand:
        // Expand-to-fullscreen: arrows to opposite corners (NE + SW).
        stroke.style = PaintingStyle.stroke;
        canvas.drawPath(
            Path()
              ..moveTo(14 * s, 10 * s)
              ..lineTo(20 * s, 4 * s)
              ..moveTo(14.5 * s, 4 * s)
              ..lineTo(20 * s, 4 * s)
              ..lineTo(20 * s, 9.5 * s)
              ..moveTo(10 * s, 14 * s)
              ..lineTo(4 * s, 20 * s)
              ..moveTo(9.5 * s, 20 * s)
              ..lineTo(4 * s, 20 * s)
              ..lineTo(4 * s, 14.5 * s),
            stroke);
        return;
    }
    canvas.drawPath(p, stroke);
  }

  /// Thumb-up: hand with rolled thumb + rounded cuff, standard line-icon
  /// geometry so it reads instantly at 13px.
  Path _thumb(double s) => Path()
    // Hand — thumb rolls over the top, knuckle edge slopes to the right.
    ..moveTo(14 * s, 9 * s)
    ..lineTo(14 * s, 5 * s)
    ..arcToPoint(Offset(11 * s, 2 * s),
        radius: Radius.circular(3 * s), clockwise: false)
    ..lineTo(7 * s, 11 * s)
    ..lineTo(7 * s, 22 * s)
    ..lineTo(18.3 * s, 22 * s)
    ..arcToPoint(Offset(20.3 * s, 20.3 * s),
        radius: Radius.circular(2 * s), clockwise: false)
    ..lineTo(21.7 * s, 11.3 * s)
    ..arcToPoint(Offset(19.7 * s, 9 * s),
        radius: Radius.circular(2 * s), clockwise: false)
    ..close()
    // Cuff — rounded column at the wrist, open toward the hand.
    ..moveTo(7 * s, 22 * s)
    ..lineTo(4 * s, 22 * s)
    ..arcToPoint(Offset(2 * s, 20 * s), radius: Radius.circular(2 * s))
    ..lineTo(2 * s, 13 * s)
    ..arcToPoint(Offset(4 * s, 11 * s), radius: Radius.circular(2 * s))
    ..lineTo(7 * s, 11 * s);

  /// Heart — feather geometry: two round lobes meeting in a center cleft.
  Path _heart(double s) => Path()
    ..moveTo(19 * s, 14 * s)
    ..cubicTo(20.49 * s, 12.54 * s, 22 * s, 10.79 * s, 22 * s, 8.5 * s)
    ..arcToPoint(Offset(16.5 * s, 3 * s),
        radius: Radius.circular(5.5 * s), clockwise: false)
    ..cubicTo(14.74 * s, 3 * s, 13.5 * s, 3.5 * s, 12 * s, 5 * s)
    ..cubicTo(10.5 * s, 3.5 * s, 9.26 * s, 3 * s, 7.5 * s, 3 * s)
    ..arcToPoint(Offset(2 * s, 8.5 * s),
        radius: Radius.circular(5.5 * s), clockwise: false)
    ..cubicTo(2 * s, 10.8 * s, 3.51 * s, 12.54 * s, 5 * s, 14 * s)
    ..lineTo(12 * s, 21 * s)
    ..close();

  /// One rounded mitt for the applause glyph, rotated about its bottom
  /// center [c] so the wrists stay apart while the tops flare into a V.
  Path _mitt(double s, double angle, Offset c) => (Path()
        ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTRB(-2.5 * s, -11 * s, 2.5 * s, 0),
            Radius.circular(2.5 * s))))
      .transform((Matrix4.translationValues(c.dx, c.dy, 0)..rotateZ(angle))
          .storage);

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color || old.fill != fill;
}
