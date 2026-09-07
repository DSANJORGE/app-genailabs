import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_charts.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/testu/testu_theme.dart';

void main() {
  // Two tooltips on the same x, one for this period and one for the ghost:
  // without its own day the compare line reads as a second figure for the
  // same date, which is the one thing it is not.
  test('the compare tooltip names the day it is quoting', () {
    final tip = compareTip(
      DayPoint(DateTime(2026, 8, 24), people: 7),
      'active people',
    );
    expect(tip, contains('24/8'));
    expect(tip, contains('7 active people'));
    expect(tip, contains('previous period'));
  });

  testWidgets('the hours grid fills the width it is given', (tester) async {
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<double> widthAt(double box) async {
      await tester.pumpWidget(MaterialApp(
        theme: testuTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: box,
              child: hoursHeatmap(const [(1, 9, 4), (3, 15, 9)]),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return tester.getSize(find.byTooltip('Tue 09:00 · 4')).width;
    }

    final narrow = await widthAt(500);
    final wide = await widthAt(980);
    expect(wide, greaterThan(narrow),
        reason: 'a fixed 14 px cell leaves 560 px of the card empty');
    // 24 cells plus their gaps and the weekday gutter, inside the box.
    expect(34 + 24 * (wide + 2), lessThanOrEqualTo(980 + 2));
    expect(34 + 24 * (wide + 2), greaterThan(980 * 0.9));
  });
}
