import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_pdf.dart';
import 'package:genai_labs/testu/testu_theme.dart';

void main() {
  const rects = [Rect.fromLTWH(0.1, 0.2, 0.5, 0.05)];

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
      MaterialApp(theme: testuTheme(), home: Center(child: child)));

  // The orange wash painter (private to testu_pdf.dart).
  final wash = find.byWidgetPredicate(
      (w) => w is CustomPaint && '${w.painter.runtimeType}' == '_Wash');

  testWidgets('a turned page swaps its aspect and keeps the wash',
      (tester) async {
    await pump(
        tester,
        const SizedBox(
          width: 200,
          child: TestuPageImage(
              src: 'assets/docs/pages/p-01.jpg',
              aspect: 0.5,
              turns: 1,
              rects: rects),
        ));
    // Outer box is landscape (1/aspect), the image inside is still portrait.
    expect(tester.getSize(find.byType(TestuPageImage)), const Size(200, 100));
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
    expect(tester.getSize(find.byType(Image)), const Size(100, 200));
    // The wash is painted over the image, so it rotates with it.
    expect(wash, findsOneWidget);
  });

  testWidgets('zoom lightbox draws the wash and its ↻ turns the page',
      (tester) async {
    await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showTestuZoom(context,
                asset: 'assets/docs/pages/p-01.jpg',
                label: 'p. 1',
                aspect: 0.7,
                rects: rects),
            child: const Text('zoom'),
          ),
        ));
    await tester.tap(find.text('zoom'));
    await tester.pumpAndSettle();
    expect(wash, findsOneWidget);
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 0);
    await tester.tap(find.text('↻'));
    await tester.pumpAndSettle();
    expect(tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns, 1);
  });
}
