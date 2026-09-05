import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_pdf.dart';
import 'package:genai_labs/testu/testu_sully.dart';
import 'package:genai_labs/testu/testu_theme.dart';

void main() {
  testWidgets('document viewer: a sent question shows as a bubble and gets a tutor line',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
              onPressed: () => showTestuPdf(context, page: 1),
              child: const Text('go')),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(seconds: 1));

    // Keyboard up: the sheet must keep the composer reachable.
    tester.view.viewInsets = const FakeViewPadding(bottom: 336);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'What does this page say?');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(find.text('What does this page say?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining("I'm on p. 1"), findsOneWidget);
  });

  test('agent errors from the server read as "not available"', () {
    expect(
        isSullyError(
            'org.openedit.OpenEditException: OpenAI error: HTTP/1.1 502 Bad Gateway'),
        isTrue);
    expect(isSullyError('Error on AI Agent: OpenAI error: HTTP/1.1 502'), isTrue);
    expect(isSullyError('Los derechos humanos son inherentes a toda persona.'),
        isFalse);
    expect(sullyUnavailable(), 'IRIS is not available right now.');
  });
}
