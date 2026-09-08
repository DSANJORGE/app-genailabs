import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:genai_labs/testu/testu_widgets.dart';

/// TestuPressable in the browser (spec: minsur-pilot-readiness E1): a real
/// button to the keyboard (focus ring, Enter/Space) and the screen reader.

Widget _app(Widget child) => MaterialApp(
      theme: testuTheme(),
      home: Scaffold(body: Center(child: child)),
    );

BoxDecoration? _ring(WidgetTester tester, String text) {
  final box = tester.widget<Container>(find
      .ancestor(of: find.text(text), matching: find.byType(Container))
      .first);
  return box.foregroundDecoration as BoxDecoration?;
}

void main() {
  setUp(() {
    // What a keyboard/mouse session sets; FocusableActionDetector's
    // highlight callbacks are gated on it (same as admin_ui_test.dart).
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() => FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.automatic);

  testWidgets('focus draws the 2px orange ring; Enter and Space press it',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        _app(TestuPressable(onTap: () => taps++, child: const Text('Go'))));
    expect(_ring(tester, 'Go'), isNull, reason: 'no ring at rest');

    Focus.of(tester.element(find.text('Go'))).requestFocus();
    await tester.pumpAndSettle();
    final border = _ring(tester, 'Go')!.border! as Border;
    expect(border.top.color, TestuTokens.instance.orange);
    expect(border.top.width, 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(taps, 2);
  });

  testWidgets('hover dims like a half-press; the ring belongs to focus only',
      (tester) async {
    await tester
        .pumpWidget(_app(TestuPressable(onTap: () {}, child: const Text('Go'))));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Go')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.88);
    expect(_ring(tester, 'Go'), isNull);
  });

  testWidgets('a disabled pressable takes no focus and no key', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_app(Column(children: [
      TestuPressable(onTap: () => taps++, child: const Text('Go')),
      const TestuPressable(child: Text('No')),
    ])));
    Focus.of(tester.element(find.text('No'))).requestFocus();
    await tester.pumpAndSettle();
    expect(_ring(tester, 'No'), isNull);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('semantics: one button node carrying the given label',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(TestuPressable(
        onTap: () {}, semanticLabel: 'Abrir', child: const Text('Go'))));
    expect(
        tester.getSemantics(find.bySemanticsLabel('Abrir')),
        isSemantics(label: 'Abrir', isButton: true, hasTapAction: true));
    handle.dispose();
  });
}
