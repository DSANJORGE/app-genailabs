import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_social.dart';
import 'package:genai_labs/testu/testu_social_api.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _thread = 'services/testu/social/thread.json';
const _comment = 'services/testu/social/comment.json';
const _react = 'services/testu/social/react.json';
const _people = 'services/testu/social/mentionables.json';

Map<String, dynamic> _threadJson() => {
      'ok': true,
      'channel': 'q-Q1',
      'comments': [
        {
          'id': 'c1',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'role': 'users',
          'date': '2026-09-07T10:00:00-05:00',
          'text': 'Me confundió a quiénes aplican.',
          'reacts': {'like': 3},
          'mine': null,
          'replies': [
            {
              'id': 'c2',
              'userId': 'jorge',
              'name': 'Jorge Paredes',
              'role': 'training',
              'date': '2026-09-07T10:05:00-05:00',
              'text': 'Aplican a todas las personas.',
              'reacts': {},
              'mine': null,
              'replies': [],
            },
          ],
        },
      ],
    };

Future<FakeEmeHttp> _pump(WidgetTester tester, {bool canned = true, void Function(int)? onCount}) async {
  final http = FakeEmeHttp();
  if (canned) http.canned[_thread] = _threadJson();
  http.canned[_comment] = {'ok': true, 'id': 'c9'};
  http.canned[_react] = {'ok': true, 'mine': 'idea', 'reacts': {'idea': 1}};
  http.canned[_people] = {
    'ok': true,
    'people': [
      {'id': 'jorge', 'name': 'Jorge Paredes', 'role': 'training'},
    ],
  };
  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: SingleChildScrollView(
        child: TestuThread(
          channel: 'q-Q1',
          api: TestuSocialApi(http: http),
          composerHint: 'Reply to the thread…',
          reportEyebrow: 'CONVERSATION · REPORT',
          reportTitle: 'Report this comment',
          onCount: onCount,
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return http;
}

void main() {
  testWidgets('renders live rows with names, badges, initials and reply counts', (tester) async {
    await _pump(tester);
    expect(find.text('Lucía Mendoza'), findsOneWidget);
    expect(find.text('Me confundió a quiénes aplican.'), findsOneWidget);
    // Threads start closed: the reply and its INSTRUCTOR badge appear on «Reply 1».
    expect(find.text('Jorge Paredes'), findsNothing);
    expect(find.text('1'), findsOneWidget);
    expect(find.byType(Image), findsNothing, reason: 'live rows draw initials, no asset photo');
    expect(find.text('LM'), findsOneWidget);
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    expect(find.text('Jorge Paredes'), findsOneWidget);
    expect(find.text('INSTRUCTOR'), findsOneWidget);
  });

  testWidgets('sending posts to comment.json, reloads and clears the composer', (tester) async {
    final http = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'Hola a todos');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(http.posted.single.path, _comment);
    expect(http.posted.single.fields['channel'], 'q-Q1');
    expect(http.posted.single.fields['message'], 'Hola a todos');
    expect(http.posted.single.fields['mentions'], '[]');
    // thread.json was fetched twice: on open and after the send.
    expect(http.requests.where((r) => r.$1 == _thread).length, 2);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty);
  });

  testWidgets('double-tapping send posts only once', (tester) async {
    final http = await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'Hola a todos');
    // Two sends fired back to back, before anything settles: _post's own
    // in-flight guard (not the composer, which has no disabled state) must
    // swallow the second one.
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(http.posted.length, 1);
  });

  testWidgets('a failed send keeps the text and says so', (tester) async {
    final http = await _pump(tester);
    http.canned.remove(_comment); // 404 from the fake
    await tester.enterText(find.byType(TextField).first, 'Se queda');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(find.text('Could not send. Try again.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, 'Se queda');
  });

  testWidgets('a reaction posts to react.json and resyncs the row with the server counts', (tester) async {
    final http = await _pump(tester);
    // Server disagrees with the optimistic local guess (like: 4) on purpose,
    // so the resync is observable: the row must show the server's 3/Idea.
    http.canned[_react] = {
      'ok': true,
      'mine': 'idea',
      'reacts': {'idea': 3},
    };
    await tester.tap(find.text('Like'));
    await tester.pumpAndSettle();
    expect(http.posted.single.path, _react);
    expect(http.posted.single.fields, {'messageid': 'c1', 'name': 'like'});
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Idea'), findsOneWidget);
  });

  testWidgets('the @ picker inserts the name and sends the id', (tester) async {
    final http = await _pump(tester);
    // The `@` button's child is a Text('@'); no semantics handle needed.
    await tester.tap(find.text('@'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jorge Paredes'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, '@Jorge Paredes ');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(http.posted.single.fields['mentions'], '["jorge"]');
  });

  testWidgets(
      'a mention picked in the bottom composer sends there, even with a reply composer also open',
      (tester) async {
    final http = await _pump(tester);
    // Open the reply composer too, so two live composers exist at once.
    await tester.tap(find.text('Reply'));
    await tester.pumpAndSettle();
    // Reply composer's field/`@` sit earlier in the tree than the bottom
    // composer's -- picking a mention in the bottom one must not restore
    // focus to the reply's field (which would swallow the send action).
    await tester.tap(find.text('@').last);
    await tester.pumpAndSettle();
    // Reply expanded the parent's replies, which already show Jorge Paredes'
    // name on his reply row -- the sheet's own row is the later match.
    await tester.tap(find.text('Jorge Paredes').last);
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, '@Jorge Paredes ');
    expect(tester.widget<TextField>(find.byType(TextField).first).controller!.text, isEmpty);
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(http.posted.single.path, _comment);
    expect(http.posted.single.fields['message'], '@Jorge Paredes');
    expect(http.posted.single.fields.containsKey('replytoid'), isFalse);
    expect(http.posted.single.fields['mentions'], '["jorge"]');
  });

  testWidgets('a failed load shows the error and Retry refetches', (tester) async {
    final http = await _pump(tester, canned: false);
    expect(find.text('Could not load the conversation.'), findsOneWidget);
    http.canned[_thread] = _threadJson();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Lucía Mendoza'), findsOneWidget);
  });

  testWidgets('onCount reports comments plus replies', (tester) async {
    int? seen;
    await _pump(tester, onCount: (n) => seen = n);
    expect(seen, 2);
  });

  testWidgets('Tab out of the composer field is not trapped by a focus scope', (tester) async {
    final http = FakeEmeHttp();
    http.canned[_thread] = {'ok': true, 'channel': 'q-Q1', 'comments': []};
    http.canned[_people] = {'ok': true, 'people': []};
    final sibling = FocusNode(debugLabel: 'sibling');
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      // Tab traversal needs a policy group at the harness root; the widget
      // itself introduces none (that's the point of this test).
      home: FocusTraversalGroup(
        child: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              TestuThread(
                channel: 'q-Q1',
                api: TestuSocialApi(http: http),
                composerHint: 'Reply to the thread…',
                reportEyebrow: 'CONVERSATION · REPORT',
                reportTitle: 'Report this comment',
              ),
              Focus(focusNode: sibling, child: const SizedBox(width: 10, height: 10)),
            ]),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField).first);
    await tester.pumpAndSettle();
    final composerFocus = FocusManager.instance.primaryFocus;
    expect(composerFocus, isNotNull);
    expect(composerFocus, isNot(sibling), reason: 'the composer field should hold focus first');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    // A bare FocusScope around the composer would keep primaryFocus inside
    // it (the field is its only focusable descendant); it must instead
    // land on the next stop in the page's traversal order.
    expect(FocusManager.instance.primaryFocus, sibling);
  });

  testWidgets('the demo entry still shows the mock thread', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: const Scaffold(body: SingleChildScrollView(child: SocialThreadEntry())),
    ));
    await tester.pumpAndSettle();
    // _mockThread(): two top-level comments, the first with two replies.
    expect(find.textContaining('Conversations on this question · 4'), findsOneWidget);
  });
}
