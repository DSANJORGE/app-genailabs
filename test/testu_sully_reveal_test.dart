import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_sully.dart';
import 'package:genai_labs/testu/testu_theme.dart';

/// A pending-reply dots bubble that is replaced in the same list slot by the
/// real reply must not keep the dots' State (and its 10-minute timer). The
/// session screen keys its dots bubbles for exactly this reason.
void main() {
  Widget host(List<Widget> children) => MaterialApp(
        theme: testuTheme(),
        home: Scaffold(body: ListView(children: children)),
      );

  testWidgets('reply replacing a keyed dots bubble reveals on its own delay',
      (tester) async {
    await tester.pumpWidget(host(const [
      SullyMessage(key: ValueKey('typing'), spans: [], delay: 600000),
    ]));
    await tester.pumpWidget(host(const [
      SullyMessage(spans: [TextSpan(text: 'No sources available')], delay: 500),
    ]));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('No sources available'), findsOneWidget);
  });

  testWidgets('without a key the slot keeps the dots (the bug)',
      (tester) async {
    await tester.pumpWidget(host(const [
      SullyMessage(spans: [], delay: 600000),
    ]));
    await tester.pumpWidget(host(const [
      SullyMessage(spans: [TextSpan(text: 'No sources available')], delay: 500),
    ]));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('No sources available'), findsNothing);
    await tester.pump(const Duration(minutes: 10)); // drain the dots timer
  });
}
