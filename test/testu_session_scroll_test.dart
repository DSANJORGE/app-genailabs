import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_session.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The auto-scroll must never bottom-align a question card so far that the
/// framing bubble leaves the viewport. Small viewport = tall card, which is
/// the same condition as a long question on a phone.
void main() {
  testWidgets('auto-scroll keeps the framing bubble on screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        MaterialApp(theme: testuTheme(), home: const TestuSessionScreen()));

    // boot → opener → framing typing → prompt → scroll animation
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 1));
    }

    final framing = find.textContaining('Next up in', findRichText: true);
    expect(framing, findsOneWidget);
    expect(tester.getTopLeft(framing).dy, greaterThanOrEqualTo(0.0));

    // Drain the loading bubble's deliberately-never-firing typing timer.
    await tester.pump(const Duration(minutes: 11));
  });
}
