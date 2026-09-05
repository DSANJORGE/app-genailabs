import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:genai_labs/testu/testu_widgets.dart';

void main() {
  // The fill has no child: without a tight height it laid out 0px tall and
  // every progress hairline in the app showed an empty track (2026-09-04).
  testWidgets('hairline fill spans the fraction at full track height',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: const Center(
        child: SizedBox(width: 200, child: TestuHairline(0.5)),
      ),
    ));
    // The track (Container's own ColoredBox) comes first; the fill is last.
    expect(tester.getSize(find.byType(ColoredBox).last), const Size(100, 2));
  });
}
