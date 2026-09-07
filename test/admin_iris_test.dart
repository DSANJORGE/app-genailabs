import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart' show MultipartFile;
import 'package:eme_app_package/eme_http.dart';
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
Map<String, dynamic> _reply({String focus = '', Map<String, String>? filters}) => {
      'ok': true,
      'answer': 'Tres personas destacan. Jorge [f1] lleva 9 días sin entrar.',
      'citations': [
        {
          'id': 'f1',
          'label': 'Sin actividad: Jorge',
          'value': 'última actividad 2026-08-28',
          'view': 'person',
          'filters': filters ?? {'user': 'jorge'},
          if (focus.isNotEmpty) 'focus': focus,
        },
      ],
      'followups': ['¿Qué le recomiendo a Jorge?'],
    };

/// An EmeHttp whose one POST never completes until the test says so — the
/// only way to observe what happens to a question that is still in flight.
class _HeldHttp implements EmeHttp {
  final held = Completer<Map<String, dynamic>>();
  final posted = <Map<String, String>>[];

  @override
  Future<Map<String, dynamic>> postForm(
    String path,
    Iterable<MapEntry<String, String>> fields, {
    EmeAuth auth = EmeAuth.token,
  }) {
    posted.add(Map.fromEntries(fields));
    return held.future;
  }

  @override
  Future<Map<String, dynamic>> getJson(String path,
          {Map<String, String> query = const {}, EmeAuth auth = EmeAuth.token}) =>
      throw UnimplementedError();

  @override
  Future<Map<String, dynamic>> post(String path,
          {Iterable<MapEntry<String, String>> query = const [],
          List<MapEntry<String, MultipartFile>>? files,
          EmeAuth auth = EmeAuth.token}) =>
      throw UnimplementedError();
}

const _down = {'ok': false, 'error': 'llm'};

/// The panel alone in its 360 px column — the shell's own slot, so the
/// layout under test is the shipped one.
Future<(FakeEmeHttp, ConsoleNav, AnalyticsFilters)> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? canned,
  String screen = 'overview',
  String? selectedUser,
  EmeHttp? http,
  IrisThread? thread,
}) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fake = FakeEmeHttp();
  if (canned != null) fake.canned[_path] = canned;
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
            api: AdminApi(http: http ?? fake),
            nav: nav,
            filters: filters,
            persona: _persona,
            screen: screen,
            selectedUser: selectedUser,
            thread: thread ?? IrisThread(),
            onClose: () {},
          ),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  return (fake, nav, filters);
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

  /// The text of every bold run in the answer bubble.
  List<String> boldRuns(WidgetTester tester) {
    final out = <String>[];
    tester
        .widget<Text>(find
            .byWidgetPredicate((w) =>
                w is Text &&
                (w.textSpan?.toPlainText() ?? '').startsWith('Jorge y Ana'))
            .first)
        .textSpan!
        .visitChildren((s) {
      if (s is TextSpan && s.style?.fontWeight == FontWeight.w700) {
        out.add(s.text ?? '');
      }
      return true;
    });
    return out;
  }

  testWidgets('markers do not cut the markdown around them', (tester) async {
    await _pump(tester, canned: {
      ..._reply(),
      // A bold run straddling a marker, and a literal asterisk right after
      // one: parsing the answer in fragments breaks the first and reads the
      // second as a bullet.
      'answer': '**Jorge y Ana** [f1] * ambos en Principiante.',
    });
    await _ask(tester, '¿Quién necesita ayuda esta semana?');

    expect(find.textContaining('• ambos', findRichText: true), findsNothing);
    expect(boldRuns(tester), ['Jorge y Ana']);
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
  });

  testWidgets("a citation puts the console on the fact's own window",
      (tester) async {
    final (_, nav, filters) = await _pump(tester,
        canned: _reply(filters: {
          'period': 'd30',
          'team': 't1',
          'entitytopic': 'x',
          'user': 'jorge',
        }));
    await _ask(tester, '¿Quién necesita ayuda esta semana?');
    await tester.tap(find.byType(CitationChip));
    await tester.pumpAndSettle();
    expect(filters.period, Period.d30);
    expect(filters.team, 't1');
    expect(filters.topic, 'x');
    // The view is a person drill-down, so the person is the entity.
    expect(nav.value.entityId, 'jorge');
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

  testWidgets('the facts list shows every cited label beside its value',
      (tester) async {
    await _pump(tester, canned: _reply());
    await _ask(tester, '¿Quién necesita ayuda esta semana?');
    expect(find.text('última actividad 2026-08-28'), findsNothing);

    await tester.tap(find.text('See the data used'));
    await tester.pumpAndSettle();
    expect(find.text('Sin actividad: Jorge'), findsOneWidget);
    expect(find.text('última actividad 2026-08-28'), findsOneWidget);

    await tester.tap(find.text('Hide the data used'));
    await tester.pumpAndSettle();
    expect(find.text('última actividad 2026-08-28'), findsNothing);
  });

  testWidgets('the composer is inert while a question is in flight',
      (tester) async {
    final http = _HeldHttp();
    final thread = IrisThread();
    addTearDown(thread.dispose);
    await _pump(tester, http: http, thread: thread);

    await _ask(tester, '¿Quién necesita ayuda?');
    expect(thread.busy, isTrue);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

    // And a second question cannot start behind it, from any affordance.
    await thread.ask(AdminApi(http: http),
        question: 'otra', screen: 'overview');
    await tester.pumpAndSettle();
    expect(http.posted.length, 1);

    http.held.complete(_reply());
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets('an answer that lands while the panel is closed is not lost',
      (tester) async {
    final http = _HeldHttp();
    final thread = IrisThread();
    addTearDown(thread.dispose);
    await _pump(tester, http: http, thread: thread);
    await _ask(tester, '¿Quién necesita ayuda?');

    // The manager closes the panel — or leaves the analytics screens — with
    // the question still out.
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: const Scaffold(body: SizedBox.shrink()),
    ));
    await tester.pumpAndSettle();

    http.held.complete(_reply());
    await tester.pumpAndSettle();
    expect(thread.busy, isFalse);

    await _pump(tester, http: http, thread: thread);
    expect(find.textContaining('Tres personas destacan.', findRichText: true),
        findsOneWidget);
    expect(find.byType(CitationChip), findsOneWidget);
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
