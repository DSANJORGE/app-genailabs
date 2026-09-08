import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_threads.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_social.dart';
import 'package:genai_labs/testu/testu_social_api.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _thread = 'services/testu/social/thread.json';
const _comment = 'services/testu/social/comment.json';

final _manager = AdminMe('m', 'm@x', 'Lider', 'manager', {'analytics_view', 'personas_view'}, const []);

/// FakeEmeHttp keys canned replies by path, and recent() and thread(channel)
/// share thread.json -- so one canned map carries both shapes: `recent` +
/// `flags` for the listing, `comments` for the opened thread.
Map<String, dynamic> _both() => {
      'ok': true,
      'recent': [
        {
          'id': 'c1',
          'channel': 'q-Q1',
          'moduleid': 'entityquestion',
          'entityid': 'Q1',
          'label': '¿Qué son los Derechos Humanos?',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'role': 'users',
          'date': '2026-09-07T10:00:00-05:00',
          'text': 'Me confundió a quiénes aplican.',
          'replytoid': null,
        },
      ],
      'flags': [
        {
          'id': 'f1',
          'entityquestion': 'Q2',
          'entitytutorial': 'TUT1',
          'label': '¿Qué característica los define?',
          'reason': 'unclear',
          'note': 'La opción B se parece a la C',
          'userId': 'rosa',
          'name': 'Rosa Jiménez',
          'date': '2026-09-07T09:00:00-05:00',
        },
      ],
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
          'replies': [],
        },
      ],
    };

Future<FakeEmeHttp> _pump(WidgetTester tester, {Map<String, dynamic>? recent}) async {
  tester.view.physicalSize = const Size(1440, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final http = FakeEmeHttp();
  if (recent != null) http.canned[_thread] = recent;
  http.canned[_comment] = {'ok': true, 'id': 'c9'};
  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: SingleChildScrollView(child: AdminThreads(api: AdminApi(http: http), me: _manager)),
    ),
  ));
  await tester.pumpAndSettle();
  return http;
}

void main() {
  testWidgets('lists recent comments and open question reports', (tester) async {
    await _pump(tester, recent: _both());
    expect(find.text('QUESTION REPORTS · 1'), findsOneWidget);
    expect(find.text('Confusing or badly worded'), findsOneWidget);
    expect(find.text('Rosa Jiménez'), findsOneWidget);
    expect(find.text('RECENT COMMENTS'), findsOneWidget);
    expect(find.text('Lucía Mendoza'), findsOneWidget);
    expect(find.byType(AdminTable<RecentComment>), findsOneWidget);
    expect(find.byType(TestuThread), findsNothing, reason: 'no thread open yet');
  });

  testWidgets('a row opens its thread and a reply posts through comment.json', (tester) async {
    final http = await _pump(tester, recent: _both());
    await tester.tap(find.text('Me confundió a quiénes aplican.').first);
    await tester.pumpAndSettle();
    expect(find.byType(TestuThread), findsOneWidget);
    expect(find.text('¿Qué son los Derechos Humanos?'), findsWidgets);
    await tester.enterText(find.byType(TextField).first, 'Respuesta del manager');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();
    expect(http.posted.single.path, _comment);
    expect(http.posted.single.fields['channel'], 'q-Q1');
    expect(http.posted.single.fields['message'], 'Respuesta del manager');
  });

  testWidgets('empty scope reads as an empty state, not a blank card', (tester) async {
    await _pump(tester, recent: {'ok': true, 'recent': [], 'flags': []});
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Nobody has commented or reported a question yet.'), findsOneWidget);
  });

  testWidgets('a failed load shows the error panel with Retry', (tester) async {
    final http = await _pump(tester);
    expect(find.byType(ConsolePanelError), findsOneWidget);
    http.canned[_thread] = _both();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Lucía Mendoza'), findsOneWidget);
  });
}
