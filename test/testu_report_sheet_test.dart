import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_report_sheet.dart';
import 'package:genai_labs/testu/testu_theme.dart';

void main() {
  testWidgets('picking a reason sends its index, not the label', (tester) async {
    int? sentIndex;
    String? sentNote;
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTestuReportSheet(
              context,
              eyebrow: 'REPORT',
              title: 'Report this',
              subtitle: 'subtitle',
              reasons: const ['Wrong', 'Outdated', 'Confusing'],
              onSend: (reasonIndex, note) {
                sentIndex = reasonIndex;
                sentNote = note;
              },
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Picking the second reason must send index 1, never the label 'Outdated'.
    await tester.tap(find.text('Outdated'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEND REPORT'));
    await tester.pumpAndSettle();
    expect(sentIndex, 1);
    expect(sentNote, isNull);
  });
}
