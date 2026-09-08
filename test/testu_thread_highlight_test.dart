import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_social.dart';
import 'package:genai_labs/testu/testu_theme.dart';

/// A notification tap opens the thread with the parent of the highlighted
/// reply unfolded and the reply's row tinted for two seconds.
void main() {
  // ponytail: demo comments only (no `channel`) -- with both set, actual
  // TestuThread._live reads off `channel` and would hit the live loader
  // instead of the passed-in list (Part C shipped after this brief).
  Widget host(List<TestuComment> comments, {String? highlight}) => MaterialApp(
        theme: testuTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: TestuThread(
              comments: comments,
              composerHint: 'Reply…',
              reportEyebrow: 'R',
              reportTitle: 'R',
              highlightMessageId: highlight,
            ),
          ),
        ),
      );

  // Adapt to Part C's TestuComment constructor: the fields used here are
  // `id`, `who`, `text`, `replies`.
  TestuComment c(String id, String text) =>
      TestuComment('Ana', null, 'assets/img/p_laia.jpg', text, id: id);

  testWidgets('highlighted reply: parent expanded, row tinted, tint gone at 2 s',
      (tester) async {
    final parent = c('M1', 'parent');
    parent.replies.add(c('M2', 'the reply'));
    await tester.pumpWidget(host([parent], highlight: 'M2'));
    await tester.pump();
    expect(find.text('the reply'), findsOneWidget); // parent unfolded
    Color? fill() {
      final box = tester.widget<Container>(find.ancestor(
          of: find.text('the reply'), matching: find.byType(Container)).first);
      return (box.decoration as BoxDecoration?)?.color;
    }
    expect(fill(), TestuTokens.instance.amberTint);
    await tester.pump(const Duration(seconds: 2));
    expect(fill(), isNot(TestuTokens.instance.amberTint));
  });

  testWidgets('no highlight: threads start closed', (tester) async {
    final parent = c('M1', 'parent');
    parent.replies.add(c('M2', 'the reply'));
    await tester.pumpWidget(host([parent]));
    expect(find.text('the reply'), findsNothing);
  });
}
