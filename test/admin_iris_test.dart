import 'dart:convert';

import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_iris.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _path = 'services/testu/analytics/ask.json';

final _persona = AdminPersona('Iris', organization: 'Minsur');

/// The canned `ask.json` reply of the task brief: one answer carrying the
/// `[f1]` marker, one citation, one follow-up.
Map<String, dynamic> _reply({String focus = ''}) => {
      'ok': true,
      'answer': 'Tres personas destacan. Jorge [f1] lleva 9 días sin entrar.',
      'citations': [
        {
          'id': 'f1',
          'label': 'Sin actividad: Jorge',
          'value': 'última actividad 2026-08-28',
          'view': 'person',
          'filters': {'user': 'jorge'},
          if (focus.isNotEmpty) 'focus': focus,
        },
      ],
      'followups': ['¿Qué le recomiendo a Jorge?'],
    };

const _down = {'ok': false, 'error': 'llm'};

/// The panel alone in its 360 px column — the shell's own slot, so the
/// layout under test is the shipped one.
Future<(FakeEmeHttp, ConsoleNav, AnalyticsFilters)> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? canned,
  String screen = 'overview',
  String? selectedUser,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final http = FakeEmeHttp();
  if (canned != null) http.canned[_path] = canned;
  final nav = ConsoleNav(const ConsoleRoute('overview'));
  final filters = AnalyticsFilters();
  addTearDown(nav.dispose);
  addTearDown(filters.dispose);

  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: Row(children: [
        SizedBox(
          width: 360,
          child: IrisPanel(
            api: AdminApi(http: http),
            nav: nav,
            filters: filters,
            persona: _persona,
            screen: screen,
            selectedUser: selectedUser,
            thread: [],
            onClose: () {},
          ),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  return (http, nav, filters);
}

Future<void> _ask(WidgetTester tester, String question) async {
  await tester.enterText(find.byType(TextField), question);
  await tester.testTextInput.receiveAction(TextInputAction.send);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an answer renders its citations as [1], not as [f1]',
      (tester) async {
    await _pump(tester, canned: _reply());
    await _ask(tester, '¿Quién necesita ayuda esta semana?');

    // The question stays in the thread, above the answer.
    expect(find.text('¿Quién necesita ayuda esta semana?'), findsOneWidget);
    expect(find.textContaining('Tres personas destacan.', findRichText: true),
        findsOneWidget);
    expect(find.textContaining('[1]', findRichText: true), findsOneWidget);
    expect(find.textContaining('[f1]', findRichText: true), findsNothing);

    // One chip per citation, numbered the same way the answer is.
    expect(find.byType(CitationChip), findsOneWidget);
    expect(find.text('1 · Sin actividad: Jorge', findRichText: true),
        findsOneWidget);

    // And the reply's follow-up, offered as a chip.
    expect(find.text('¿Qué le recomiendo a Jorge?'), findsOneWidget);
  });

  testWidgets('a follow-up chip asks its question', (tester) async {
    final (http, _, _) = await _pump(tester, canned: _reply());
    await _ask(tester, '¿Quién necesita ayuda esta semana?');
    await tester.tap(find.text('¿Qué le recomiendo a Jorge?'));
    await tester.pumpAndSettle();
    expect(http.posted.length, 2);
    expect(http.posted.last.fields['question'], '¿Qué le recomiendo a Jorge?');
  });

  testWidgets('tapping a citation opens the view it came from', (tester) async {
    final (_, nav, filters) = await _pump(tester, canned: _reply());
    await _ask(tester, '¿Quién necesita ayuda esta semana?');
    await tester.tap(find.byType(CitationChip));
    await tester.pumpAndSettle();
    expect(nav.value.section, 'person');
    expect(nav.value.entityId, 'jorge');
    // No focus key on this fact, so the id is what the screen is handed.
    expect(nav.value.highlight, 'f1');
    // A citation without filters leaves the console's window alone.
    expect(filters.period, Period.d7);
  });

  testWidgets('a citation with a focus key pulses that element',
      (tester) async {
    final (_, nav, _) = await _pump(tester, canned: _reply(focus: 'inactive'));
    await _ask(tester, '¿Quién lleva más de 7 días sin entrar?');
    await tester.tap(find.byType(CitationChip));
    await tester.pumpAndSettle();
    expect(nav.value.highlight, 'inactive');
  });

  testWidgets('the tutor being down keeps the thread and offers a retry',
      (tester) async {
    final (http, _, _) = await _pump(tester, canned: _down);
    await _ask(tester, '¿Quién necesita ayuda esta semana?');

    expect(find.text('Iris is not available right now.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    // The question is still on screen: the thread survives the failure.
    expect(find.text('¿Quién necesita ayuda esta semana?'), findsOneWidget);

    // Retry asks the same question again; a server that recovered answers it.
    http.canned[_path] = _reply();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(http.posted.length, 2);
    expect(http.posted.last.fields['question'],
        '¿Quién necesita ayuda esta semana?');
    expect(find.text('Iris is not available right now.'), findsNothing);
    expect(find.byType(CitationChip), findsOneWidget);
  });

  testWidgets('the last six turns ride along as history', (tester) async {
    final (http, _, _) = await _pump(tester, canned: _reply());
    for (var i = 1; i <= 4; i++) {
      await _ask(tester, 'pregunta $i');
    }
    final first = jsonDecode(http.posted.first.fields['history']!) as List;
    expect(first, isEmpty, reason: 'the opening question has no history');

    final last = jsonDecode(http.posted.last.fields['history']!) as List;
    expect(last.length, 6, reason: 'only the last six turns are sent');
    expect(last.first['text'], 'pregunta 1');
    expect(last.last['role'], 'assistant');
  });

  testWidgets('the screen and the selected person ride along', (tester) async {
    final (http, _, _) = await _pump(tester,
        canned: _reply(), screen: 'person', selectedUser: 'u42');
    await _ask(tester, '¿En qué debería centrarse?');
    expect(http.posted.single.fields['screen'], 'person');
    expect(http.posted.single.fields['user'], 'u42');
  });

  testWidgets("an empty thread offers this screen's questions", (tester) async {
    await _pump(tester, canned: _reply());
    expect(find.text('Which subtopic is the weakest?'), findsOneWidget);
    // Tapping one asks it, and the suggestions give way to the thread.
    await tester.tap(find.text('Which subtopic is the weakest?'));
    await tester.pumpAndSettle();
    expect(find.byType(CitationChip), findsOneWidget);
    expect(find.text('Compare the teams'), findsNothing);
  });
}
