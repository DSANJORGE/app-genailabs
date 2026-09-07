import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_activity.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_i18n.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _path = 'services/testu/analytics/activity.json';

final _me = AdminMe('m', 'm@x', 'Diego San Jorge', 'training', {'analytics_view'},
    const [], persona: AdminPersona('Iris', organization: 'Minsur'));

/// A whole activity.json, the shape aggregate.groovy sends: seven days of
/// series with the 1.1.1 counters still at zero, the adoption funnel, a
/// sparse hours grid (never 7 x 24 -- the server sends only the cells it
/// has), two people who have gone quiet (one of them never started), and the
/// aggregated Iris usage of §6.8.
Map<String, dynamic> _canned({int answered = 17}) => {
      'ok': true,
      'series': [
        for (var i = 0; i < 7; i++)
          {
            'day': '2026-09-0${i + 1}',
            'people': 5 + i,
            'answers': 100 + i * 10,
            // minutes and sessions stay 0 until the 1.1.1 app ships.
            'minutes': 0,
            'sessions': 0,
            'questions': 4 + i,
          },
      ],
      'funnel': {
        'cohort': 24,
        'signedin': 19,
        'answered': answered,
        'active7d': 12,
        'active30d': 20,
      },
      'hours': [
        // Monday is 0 on the wire, not 1: `(DAY_OF_WEEK + 5) % 7`.
        [0, 7, 5],
        [1, 9, 12],
        [1, 14, 3],
        [3, 20, 7],
        [5, 8, 21],
      ],
      'inactive': [
        {
          'user': 'u-luis',
          'name': 'Luis Huamán',
          'team': 'Operaciones Pisco',
          'lastactivity': '2026-08-20T10:00:00Z',
        },
        {'user': 'u-rosa', 'name': 'Rosa Cárdenas'},
      ],
      'iris': {
        'questions': 42,
        'people': 9,
        'citedShare': 0.8,
        'ratedShare': 0.5,
        'helpfulShare': 0.75,
        'themes': [
          {'theme': 'concept', 'count': 20},
          {'theme': 'procedure', 'count': 12},
          {'theme': 'offtopic', 'count': 3},
          {'theme': 'other', 'count': 4},
          {'theme': 'unclassified', 'count': 3},
        ],
        'sections': [
          {'section': 's2', 'name': 'Phishing', 'questions': 18, 'helpfulShare': 0.8},
          {'section': 's1', 'name': 'Debida diligencia', 'questions': 9},
        ],
        'labels': [
          {'label': 'correo sospechoso', 'count': 6},
          {'label': 'contraseñas seguras', 'count': 3},
        ],
      },
    };

/// Mirrors AdminScaffold, which already hands every screen a ListView: the
/// page is a Column, and the frame is what scrolls it.
Future<(FakeEmeHttp, AnalyticsFilters, ConsoleNav)> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? canned,
  String? highlight,
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final http = FakeEmeHttp();
  if (canned != null) http.canned[_path] = canned;
  final filters = AnalyticsFilters();
  final nav = ConsoleNav(ConsoleRoute('activity', highlight: highlight));
  addTearDown(filters.dispose);
  addTearDown(nav.dispose);

  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: ListView(children: [
        AdminActivity(api: AdminApi(http: http), me: _me, filters: filters, nav: nav),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  return (http, filters, nav);
}

void main() {
  testWidgets('the adoption funnel names all five steps', (tester) async {
    await _pump(tester, canned: _canned());

    expect(find.text('IRIS'), findsOneWidget);
    expect(
      find.text('19 of 24 people have opened the app; '
          '17 have answered at least one question.'),
      findsOneWidget,
    );
    for (final label in [
      'Cohort',
      'Signed in',
      'Answered',
      'Active 7 d',
      'Active 30 d',
    ]) {
      expect(find.text(label), findsOneWidget, reason: '$label is missing');
    }
    // The widest step is the denominator every other share is read against.
    expect(find.text('19 · 79%'), findsOneWidget);
    // Monday is weekday 0 on the wire; reading it as 1 drops the row.
    expect(find.byTooltip('Mon 07:00 · 5'), findsOneWidget);
  });

  testWidgets('the inactive table names the people who went quiet',
      (tester) async {
    final (_, _, nav) = await _pump(tester, canned: _canned());

    expect(find.text('Luis Huamán'), findsOneWidget);
    // No lastactivity at all is "never started", not "0 days".
    expect(find.text('Rosa Cárdenas'), findsOneWidget);
    expect(find.text('Never'), findsWidgets);

    await tester.tap(find.text('Luis Huamán'));
    await tester.pumpAndSettle();
    expect(nav.value.section, 'person');
    expect(nav.value.entityId, 'u-luis');
  });

  testWidgets('an all-zero minutes series says where minutes come from',
      (tester) async {
    await _pump(tester, canned: _canned());

    const note = 'Available from app version 1.1.1.';
    expect(find.text(note), findsNothing, reason: 'people is not a 1.1.1 counter');

    await tester.tap(find.text('Minutes'));
    await tester.pumpAndSettle();
    expect(find.text(note), findsOneWidget);

    await tester.tap(find.text('Sessions'));
    await tester.pumpAndSettle();
    expect(find.text(note), findsOneWidget);

    await tester.tap(find.text('Answers'));
    await tester.pumpAndSettle();
    expect(find.text(note), findsNothing, reason: 'answers are not zero');
  });

  testWidgets('Iris usage is aggregated and says so', (tester) async {
    await _pump(tester, canned: _canned());

    expect(find.text('RATED'), findsOneWidget);
    expect(find.text('HELPFUL'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    // Subtopic bars: the name and the count, both as text.
    expect(find.text('Phishing'), findsOneWidget);
    expect(
      tester.widget<BarRow>(find.widgetWithText(BarRow, 'Phishing')).value,
      18,
    );
    // Themes: `other` and `unclassified` are one bucket, not two.
    expect(find.text('Clarify a concept · 20'), findsOneWidget);
    expect(find.text('Other · 7'), findsOneWidget);
    // The chip cloud, and the promise the app makes to every learner.
    expect(find.text('correo sospechoso'), findsOneWidget);
    expect(
      find.text('Aggregated: no individual question is ever shown.'),
      findsOneWidget,
    );
  });

  testWidgets('a theme the console has no colour for still counts',
      (tester) async {
    final canned = _canned();
    (canned['iris'] as Map)['themes'] = [
      {'theme': 'concept', 'count': 20},
      {'theme': 'brandnew', 'count': 2},
    ];
    await _pump(tester, canned: canned);

    // The bar has to add up to the total, so an unknown theme joins "Other"
    // instead of vanishing from it.
    expect(find.text('Other · 2'), findsOneWidget);
  });

  testWidgets('a privacy-gated label list renders no chips and no error',
      (tester) async {
    final canned = _canned();
    (canned['iris'] as Map)['labels'] = [];
    await _pump(tester, canned: canned);

    expect(find.text('correo sospechoso'), findsNothing);
    expect(find.text('Clarify a concept · 20'), findsOneWidget);
  });

  testWidgets('a cohort with nothing answered teaches instead of charting',
      (tester) async {
    await _pump(tester, canned: _canned(answered: 0));

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Cohort'), findsOneWidget, reason: 'adoption still reads');
    expect(find.text('Luis Huamán'), findsOneWidget, reason: 'and so does the list');
    expect(find.text('Phishing'), findsNothing);
  });

  testWidgets('a failed load offers exactly one way out', (tester) async {
    final (http, _, _) = await _pump(tester);

    expect(find.byType(ConsolePanelError), findsOneWidget);

    http.canned[_path] = _canned();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.byType(ConsolePanelError), findsNothing);
    expect(find.text('Cohort'), findsOneWidget);
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

    expect(find.text('Han respondido'), findsOneWidget);
    expect(find.text('CUÁNDO APRENDEN'), findsOneWidget);
    expect(find.byTooltip('Lun 07:00 · 5'), findsOneWidget);
    expect(find.text('Nunca'), findsWidgets);
    expect(
      find.text('Agregado: nunca se muestra ninguna pregunta individual.'),
      findsOneWidget,
    );

    // Spanish is also where the 1.1.1 footnote is longest.
    await tester.tap(find.text('Minutos'));
    await tester.pumpAndSettle();
    expect(
      find.text('Disponible desde la versión 1.1.1 de la app.'),
      findsOneWidget,
    );
  });

  bool pulsing(WidgetTester tester, Finder inner) {
    final pulse = find.ancestor(of: inner, matching: find.byType(Pulse));
    // The adoption funnel is cohort data, and every cohort fact opens
    // Resumen -- so nothing here can cite it, and it is left unwrapped.
    return pulse.evaluate().isNotEmpty &&
        tester.widget<Pulse>(pulse.first).active;
  }

  testWidgets('an Iris citation pulses the Iris cards and nothing else',
      (tester) async {
    await _pump(tester, canned: _canned(), highlight: 'iris');

    expect(pulsing(tester, find.byType(Funnel)), isFalse);
    expect(pulsing(tester, find.byType(AdminTable<InactivePerson>)), isFalse);
    expect(pulsing(tester, find.byType(StackedBar)), isTrue);
  });

  testWidgets('an inactivity citation pulses the list', (tester) async {
    await _pump(tester, canned: _canned(), highlight: 'inactive');

    expect(pulsing(tester, find.byType(AdminTable<InactivePerson>)), isTrue);
    expect(pulsing(tester, find.byType(Funnel)), isFalse);
  });

  // Spec §6.8: the reading is "42 questions from 9 people", never 42 alone.
  testWidgets('Iris usage says how many people are asking', (tester) async {
    await _pump(tester, canned: _canned());

    expect(find.text('PEOPLE'), findsOneWidget);
    expect(
      tester.widget<StatBlock>(find.widgetWithText(StatBlock, 'PEOPLE')).value,
      '9',
    );
  });

  // The card used to render a grey stub of a bar and an empty legend: a
  // heading with nothing under it, which reads as breakage rather than as
  // "nobody has asked anything".
  testWidgets('no questions at all is a sentence, not a bare bar',
      (tester) async {
    final canned = _canned();
    (canned['iris'] as Map)['questions'] = 0;
    (canned['iris'] as Map)['themes'] = [];
    (canned['iris'] as Map)['labels'] = [];
    await _pump(tester, canned: canned);

    expect(find.byType(StackedBar), findsNothing);
    expect(find.text('NO QUESTIONS YET'), findsOneWidget);
    expect(find.textContaining('Nobody has asked Iris anything'),
        findsOneWidget);
    // The promise the app makes every learner holds in the empty state too.
    expect(find.text('Aggregated: no individual question is ever shown.'),
        findsOneWidget);
  });

  // The other way into the same empty card: the period HAS questions, and the
  // server sent no theme split for them at all. A bar of zeros under a heading
  // is what this guard exists to prevent.
  testWidgets('questions with no theme split at all still read as empty',
      (tester) async {
    final canned = _canned();
    (canned['iris'] as Map)['themes'] = [];
    (canned['iris'] as Map)['labels'] = [];
    await _pump(tester, canned: canned);

    expect((canned['iris'] as Map)['questions'], 42, reason: 'not the zero case');
    expect(find.byType(StackedBar), findsNothing);
    expect(find.text('NO QUESTIONS YET'), findsOneWidget);
  });

  // Questions with no theme split yet (the classifier runs on its own clock)
  // is not the same state as no themes at all: `unclassified` folds into
  // "Other", so the segments are non-zero and the bar stays.
  testWidgets('questions the classifier has not reached keep their bar',
      (tester) async {
    final canned = _canned();
    (canned['iris'] as Map)['themes'] = [
      {'theme': 'unclassified', 'count': 42},
    ];
    await _pump(tester, canned: canned);

    expect(find.byType(StackedBar), findsOneWidget);
    expect(find.text('Other · 42'), findsOneWidget);
  });

  // The counts are on hover, and the footnote used to promise them in the
  // cells themselves.
  testWidgets('the hours footnote says where the counts are', (tester) async {
    await _pump(tester, canned: _canned());

    expect(find.text('Answers by weekday and hour. Hover a cell for its count.'),
        findsOneWidget);
  });

}
