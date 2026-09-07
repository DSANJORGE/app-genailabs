import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_overview.dart';
import 'package:genai_labs/admin/admin_theme.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_i18n.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _path = 'services/testu/analytics/overview.json';

final _me = AdminMe('m', 'm@x', 'Diego San Jorge', 'training', {'analytics_view'},
    const [], persona: AdminPersona('Iris', organization: 'Minsur'));

/// A whole overview.json, the shape aggregate.groovy sends: seven days of
/// series, two topics, two teams (one of them the id-less "no team" bucket),
/// a previous window and one gap.
Map<String, dynamic> _canned({int activated = 20, int active7d = 12}) => {
      'ok': true,
      'cohort': {'total': 24, 'activated': activated, 'active7d': active7d, 'active30d': 20},
      'series': [
        for (var i = 0; i < 7; i++)
          {
            'day': '2026-09-0${i + 1}',
            'people': 5 + i,
            'answers': 100 + i * 10,
            'minutes': 200 + i * 5,
            'certainwrong': 1,
            'questions': 2,
          },
      ],
      'previousSeries': [
        for (var i = 0; i < 7; i++)
          {
            'day': '2026-08-2${i + 1}',
            'people': 3 + i,
            'answers': 60 + i * 10,
            'minutes': 120 + i * 5,
            'certainwrong': 1,
            'questions': 1,
          },
      ],
      'levels': {'notstarted': 4, 'beginner': 6, 'competent': 9, 'expert': 5},
      'topics': [
        {
          'id': 'topic-ddhh',
          'name': 'Derechos Humanos',
          'people': 20,
          'levels': {'notstarted': 2, 'beginner': 6, 'competent': 8, 'expert': 4},
          'weakest': {'section': 's1', 'name': 'Debida diligencia', 'beginners': 6},
        },
        {
          'id': 'topic-ciber',
          'name': 'Ciberseguridad',
          'people': 18,
          'levels': {'notstarted': 4, 'beginner': 8, 'competent': 6, 'expert': 2},
          'weakest': {'section': 's2', 'name': 'Phishing', 'beginners': 8},
        },
      ],
      'calibration': {'cc': 612, 'cu': 240, 'ic': 333, 'iu': 99},
      'teams': [
        {
          'id': 'team-pisco',
          'name': 'Operaciones Pisco',
          'members': 9,
          'activated': 8,
          'active7d': 6,
          'levels': {'notstarted': 1, 'beginner': 2, 'competent': 4, 'expert': 2},
          'weakest': 'Ciberseguridad',
        },
        {
          'id': '',
          'name': '',
          'members': 3,
          'activated': 1,
          'active7d': 0,
          'levels': {'notstarted': 2, 'beginner': 1},
        },
      ],
      'median': {'activeShare': 0.48, 'expertShare': 0.2},
      'previous': {
        'active7d': 9,
        'answers': 500,
        'minutes': 900,
        'certainwrong': 3,
        'questions': 8,
      },
      'gaps': [
        {
          'section': 's1',
          'name': 'Debida diligencia',
          'topic': 'Derechos Humanos',
          'topicId': 'topic-ddhh',
          'score': 0.91,
          'people': 20,
          'levels': {'notstarted': 2, 'beginner': 6, 'competent': 8, 'expert': 4},
          'beginners': 6,
          'questions': 14,
          'misconceptions': 3,
          'unanswered': 2,
        },
      ],
      'iris': {'questions': 42, 'people': 9},
    };

/// Mirrors AdminScaffold, which already hands every screen a ListView: the
/// page is a Column, and the frame is what scrolls it.
Future<(FakeEmeHttp, AnalyticsFilters, ConsoleNav)> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? canned,
  String? highlight,
  String? topic,
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final http = FakeEmeHttp();
  if (canned != null) http.canned[_path] = canned;
  final filters = AnalyticsFilters();
  if (topic != null) filters.set(topic: topic);
  final nav = ConsoleNav(ConsoleRoute('overview', highlight: highlight));
  addTearDown(filters.dispose);
  addTearDown(nav.dispose);

  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: ListView(children: [
        AdminOverview(api: AdminApi(http: http), me: _me, filters: filters, nav: nav),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  return (http, filters, nav);
}

void main() {
  testWidgets('the reading opens the screen and the five stats follow it',
      (tester) async {
    await _pump(tester, canned: _canned());

    expect(find.text('IRIS'), findsOneWidget);
    expect(
      find.text('12 of 24 people active this week, 3 more than the week before.'),
      findsOneWidget,
    );
    for (final label in [
      'ACTIVE 7 D',
      'ANSWERS',
      'MINUTES IN THE APP',
      'MISCONCEPTIONS',
      'QUESTIONS TO IRIS',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }
    // Period sums off the series, not off the cumulative blocks.
    expect(find.text('910'), findsOneWidget, reason: 'answers = sum of the series');
    expect(find.text('42'), findsOneWidget, reason: 'iris questions');
    // 1505 minutes over the 20 people who have ever answered -- NOT over the
    // 12 active this week, which would inflate it on a 30 or 90 day window.
    expect(find.text('≈ 75 min per person'), findsOneWidget);
    // previousSeries arrived, so the chart claims its ghost line.
    expect(find.text('Previous period'), findsOneWidget);
    expect(
      tester.widget<ChartCard>(find.widgetWithText(ChartCard, 'DAILY ACTIVITY')).legend.length,
      3,
    );
  });

  testWidgets('a server without previousSeries claims no ghost line', (tester) async {
    final canned = _canned()..remove('previousSeries');
    await _pump(tester, canned: canned);

    expect(find.text('Previous period'), findsNothing);
    expect(
      tester.widget<ChartCard>(find.widgetWithText(ChartCard, 'DAILY ACTIVITY')).legend.length,
      2,
    );
  });

  testWidgets('a team row drills into that team', (tester) async {
    final (_, _, nav) = await _pump(tester, canned: _canned());

    await tester.tap(find.text('Operaciones Pisco'));
    await tester.pumpAndSettle();

    expect(nav.value.section, 'team');
    expect(nav.value.entityId, 'team-pisco');
  });

  testWidgets('the id-less bucket is named and does not drill', (tester) async {
    final (_, _, nav) = await _pump(tester, canned: _canned());

    expect(find.text('No team'), findsOneWidget);
    await tester.tap(find.text('No team'));
    await tester.pumpAndSettle();

    expect(nav.value.section, 'overview', reason: 'there is no team page to open');
  });

  testWidgets('a gap row opens Dominio filtered to its topic', (tester) async {
    final (_, filters, nav) = await _pump(tester, canned: _canned());

    await tester.tap(find.text('Debida diligencia'));
    await tester.pumpAndSettle();

    expect(filters.topic, 'topic-ddhh');
    expect(nav.value.section, 'mastery');
  });

  testWidgets('a cohort with nothing answered teaches instead of charting',
      (tester) async {
    await _pump(tester, canned: _canned(activated: 0, active7d: 0));

    expect(
      find.text('Nobody has answered yet. '
          'Data appears 15 minutes after the first session.'),
      findsOneWidget,
    );
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('ACTIVE 7 D'), findsOneWidget, reason: 'the stat row still renders');
    expect(find.text('Operaciones Pisco'), findsNothing);
  });

  testWidgets('a failed load offers exactly one way out', (tester) async {
    final (http, _, _) = await _pump(tester);

    expect(find.byType(ConsolePanelError), findsOneWidget);

    http.canned[_path] = _canned();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(ConsolePanelError), findsNothing);
    expect(find.text('ACTIVE 7 D'), findsOneWidget);
  });

  testWidgets('rapid filter changes cost one refetch, not four', (tester) async {
    final (http, filters, _) = await _pump(tester, canned: _canned());
    int calls() => http.requests.where((r) => r.$1 == _path).length;
    expect(calls(), 1);

    filters.set(period: Period.d30);
    filters.set(period: Period.d90);
    filters.set(topic: 'topic-ciber');
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls(), 1, reason: 'still inside the debounce window');

    await tester.pumpAndSettle();
    expect(calls(), 2);
    expect(http.requests.last.$2, containsPair('entitytopic', 'topic-ciber'));
  });

  // 1024 px of window minus the 220 px nav and the 24 px gutters is the
  // narrowest content column the console supports -- and Spanish is the
  // shipping language, 20-30 % longer than the English the rest of these
  // tests assert. Any overflow here fails the test on its own.
  testWidgets('the Spanish console fits its narrowest supported column',
      (tester) async {
    testuLang.value = 'es';
    addTearDown(() => testuLang.value = 'en');

    await _pump(tester, canned: _canned(), width: 756);

    expect(
      find.text('12 de 24 personas activas esta semana, 3 más que la anterior.'),
      findsOneWidget,
    );
    expect(find.text('CONCEPTOS ERRÓNEOS'), findsOneWidget);
    expect(find.text('Sin equipo'), findsOneWidget);
  });

  // A citation lights the ONE element it quotes. Pulsing the stat row for
  // every highlight would make the ring mean "something over there", which
  // is the opposite of a citation.
  bool pulsing(WidgetTester tester, Finder inner) {
    final pulse = find.ancestor(of: inner, matching: find.byType(Pulse));
    // An element no fact can cite is deliberately not wrapped at all.
    return pulse.evaluate().isNotEmpty &&
        tester.widget<Pulse>(pulse.first).active;
  }

  /// True while the [Pulse] wrapping [inner] is showing its focus ring. The
  /// widget's `active` flag is not enough: it stays true for as long as the
  /// citation points here, and what this task is about is the ring firing
  /// *again* for a second citation carrying the same key.
  bool ringing(WidgetTester tester, Finder inner) {
    final pulse = find.ancestor(of: inner, matching: find.byType(Pulse));
    if (pulse.evaluate().isEmpty) return false;
    final box = find
        .descendant(of: pulse.first, matching: find.byType(AnimatedContainer))
        .first;
    final d = tester.widget<AnimatedContainer>(box).decoration as BoxDecoration;
    return d.border?.top.color == AdminTokens.focus;
  }

  testWidgets('a stat citation pulses the stat row and nothing else',
      (tester) async {
    await _pump(tester, canned: _canned(), highlight: 'stat');

    expect(pulsing(tester, find.byType(StatRow)), isTrue);
    expect(pulsing(tester, find.byType(AdminTable<TeamStat>)), isFalse);
    expect(pulsing(tester, find.byType(AdminTable<Gap>)), isFalse);
  });

  testWidgets('a gap citation leaves the stat row alone', (tester) async {
    await _pump(tester, canned: _canned(), highlight: 'gap');

    expect(pulsing(tester, find.byType(StatRow)), isFalse);
    expect(pulsing(tester, find.byType(AdminTable<Gap>)), isTrue);
    expect(pulsing(tester, find.byType(AdminTable<TeamStat>)), isFalse);
  });

  // Every team fact opens the team page, so nothing on Resumen can be cited
  // with 'team' -- the teams table is deliberately unwrapped.
  testWidgets('the teams table is not a citation target', (tester) async {
    await _pump(tester, canned: _canned(), highlight: 'team');

    expect(pulsing(tester, find.byType(AdminTable<TeamStat>)), isFalse);
    expect(pulsing(tester, find.byType(StatRow)), isFalse);
  });

  // The focus vocabulary is small, so two citations in a row usually carry
  // the same key. The second one still has to ring.
  testWidgets('a second citation on the same element rings again',
      (tester) async {
    final (_, _, nav) = await _pump(tester, canned: _canned());

    nav.go('overview', highlight: 'stat');
    await tester.pump();
    expect(ringing(tester, find.byType(StatRow)), isTrue);

    await tester.pumpAndSettle();
    expect(ringing(tester, find.byType(StatRow)), isFalse);

    nav.go('overview', highlight: 'stat');
    await tester.pump();
    expect(ringing(tester, find.byType(StatRow)), isTrue,
        reason: 'the same highlight twice is still two citations');
  });

  // "1 conceptos erróneos" is the kind of thing a training lead screenshots.
  testWidgets('the gap sentence counts in singular and in plural',
      (tester) async {
    final canned = _canned();
    // Replace the list rather than an element of it: the literal in _canned
    // is a List<Map<String, Object>> and will not take a dynamic map.
    canned['gaps'] = [
      {
        ...(canned['gaps'] as List).first as Map,
        'questions': 1,
        'misconceptions': 1,
      },
    ];
    await _pump(tester, canned: canned);
    expect(find.text('6 at Beginner, 1 question to IRIS, 1 misconception'),
        findsOneWidget);

    testuLang.value = 'es';
    addTearDown(() => testuLang.value = 'en');
    await _pump(tester, canned: canned);
    expect(
      find.text('6 en Principiante, 1 pregunta a IRIS, 1 concepto erróneo'),
      findsOneWidget,
    );

  });

  // The plural side of the same sentence, in its own test: re-pumping the
  // screen reuses its State (and therefore its already-fetched data), so one
  // test cannot show two different replies.
  testWidgets('and in plural, with the numbers the server sent',
      (tester) async {
    testuLang.value = 'es';
    addTearDown(() => testuLang.value = 'en');

    await _pump(tester, canned: _canned());

    expect(
      find.text('6 en Principiante, 14 preguntas a IRIS, 3 conceptos erróneos'),
      findsOneWidget,
    );
  });

  // ------------------------------------------------- topic filter honesty

  // The Iris stat's value is topic-filtered; its delta and sparkline come
  // from `tutordaily`, which has no topic. Under a filter they would answer a
  // different question from the number above them.
  testWidgets('a topic filter strips the Iris delta, sparkline and warns on the chart',
      (tester) async {
    await _pump(tester, canned: _canned(), topic: 'topic-ddhh');

    final iris = tester.widget<StatBlock>(
        find.widgetWithText(StatBlock, 'QUESTIONS TO IRIS'));
    expect(iris.value, '42');
    expect(iris.delta, isNull);
    expect(iris.spark, isNull);

    final daily = tester.widget<ChartCard>(
        find.widgetWithText(ChartCard, 'DAILY ACTIVITY'));
    expect(daily.footnote, contains('Daily activity includes every topic.'));
  });

  testWidgets('without a topic filter the delta, sparkline and no footnote',
      (tester) async {
    await _pump(tester, canned: _canned());

    final iris = tester.widget<StatBlock>(
        find.widgetWithText(StatBlock, 'QUESTIONS TO IRIS'));
    expect(iris.delta, isNotNull);
    expect(iris.spark, isNotNull);

    final daily = tester.widget<ChartCard>(
        find.widgetWithText(ChartCard, 'DAILY ACTIVITY'));
    expect(daily.footnote, isNot(contains('every topic')));
  });
}
