import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_mastery.dart';
import 'package:genai_labs/admin/admin_heatmap.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_theme.dart';
import 'package:genai_labs/testu/testu_i18n.dart';
import 'package:genai_labs/testu/testu_theme.dart';

Map<String, Object?> _row(
  String user,
  String name,
  String team,
  String topicId,
  String topic,
  String section,
  String sectionName, {
  int questions = 5,
  int answered = 4,
  int mastered = 1,
  int attempts = 6,
  int certainWrong = 2,
}) => {
  'user': user,
  'name': name,
  'team': team,
  'entitytopic': topicId,
  'topic': topic,
  'componentsection': section,
  'section': sectionName,
  'questions': questions,
  'answered': answered,
  'mastered': mastered,
  'attempts': attempts,
  'correct': mastered,
  'certaincorrect': 1,
  'certainwrong': certainWrong,
  'unsurecorrect': 1,
  'unsurewrong': 1,
  'lastactivity': '2026-09-01T00:00:00Z',
  'computedat': '2026-09-05T00:00:00Z',
};

/// Two teams, two topics, three subtopics — the smallest fixture that has a
/// column per subtopic and a group row per team.
final _cohort = [
  _row(
    'ana',
    'Ana Quispe',
    'ops',
    't1',
    'Derechos Humanos',
    's1',
    '1. Principios',
  ),
  _row(
    'ana',
    'Ana Quispe',
    'ops',
    't1',
    'Derechos Humanos',
    's2',
    '2. Debida diligencia',
    answered: 1,
    mastered: 0,
  ),
  _row(
    'ana',
    'Ana Quispe',
    'ops',
    't2',
    'Ciberseguridad',
    's3',
    '1. Phishing',
    answered: 6,
    mastered: 6,
  ),
  _row(
    'luis',
    'Luis Huamán',
    'mant',
    't1',
    'Derechos Humanos',
    's1',
    '1. Principios',
    answered: 5,
    mastered: 5,
  ),
];

Map<String, Object?> _report(List<Map<String, Object?>> rows) => {
  'rows': rows,
  'summary': {'activeusers7d': 2, 'answers7d': 9, 'levels': {}},
  'topics': [
    {'id': 't1', 'name': 'Derechos Humanos'},
    {'id': 't2', 'name': 'Ciberseguridad'},
  ],
};

FakeEmeHttp _http(List<Map<String, Object?>> rows) {
  final http = FakeEmeHttp();
  http.canned['services/testu/analytics/report.json'] = _report(rows);
  http.canned['services/testu/personas/teams.json'] = {
    'teams': [
      {'id': 'ops', 'name': 'Operaciones Pisco'},
      {'id': 'mant', 'name': 'Mantenimiento'},
    ],
  };
  http.canned['services/testu/analytics/recompute.json'] = {'ok': true};
  return http;
}

AdminMe _admin({bool operate = false}) => AdminMe(
  'orgadmin',
  'admin@minsur.test',
  'Admin',
  'orgadmin',
  {'analytics_view', if (operate) 'analytics_operate'},
  const [],
);

Future<ConsoleNav> _pump(
  WidgetTester tester, {
  List<Map<String, Object?>>? rows,
  double width = 1400,
  FakeEmeHttp? http,
  bool operate = false,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final nav = ConsoleNav();
  addTearDown(nav.dispose);
  final filters = AnalyticsFilters();
  addTearDown(filters.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: testuTheme(),
      home: Scaffold(
        // The shell renders every screen inside its own scroller: the grid has
        // to size itself in unbounded height, not assume a viewport.
        body: ListView(
          children: [
            AdminMastery(
              api: AdminApi(http: http ?? _http(rows ?? _cohort)),
              me: _admin(operate: operate),
              filters: filters,
              nav: nav,
            ),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return nav;
}

void main() {
  group('levelOf', () {
    test('0 answered is not started (null)', () {
      expect(levelOf(0, 0), isNull);
    });
    test('4/5 (80%) is competent', () {
      expect(levelOf(4, 5), 'competent');
    });
    test('9/10 (90%) is expert', () {
      expect(levelOf(9, 10), 'expert');
    });
    test('1/5 (20%) is beginner', () {
      expect(levelOf(1, 5), 'beginner');
    });
  });

  testWidgets('one column per subtopic and one group row per team', (
    tester,
  ) async {
    await _pump(tester);
    // Columns: the three subtopics present in the rows, under their topics.
    for (final name in ['Principios', 'Debida diligencia', 'Phishing']) {
      expect(find.text(name), findsOneWidget, reason: '$name is not a column');
    }
    expect(find.text('Derechos Humanos'), findsOneWidget);
    expect(find.text('Ciberseguridad'), findsOneWidget);
    // One group row per team, each carrying its headcount.
    expect(find.textContaining('Operaciones Pisco'), findsOneWidget);
    expect(find.textContaining('Mantenimiento'), findsOneWidget);
    // And the people themselves.
    expect(find.text('Ana Quispe'), findsOneWidget);
    expect(find.text('Luis Huamán'), findsOneWidget);

    // Ana is the only Beginner in both Principios and Debida diligencia: a
    // real tie, broken on the column order, so the underlined column is the
    // one masteryReading's sentence names and not whichever came first out
    // of a map.
    final underline = find.byWidgetPredicate(
      (w) => w is Container && w.color == AdminTokens.focus,
    );
    expect(underline, findsOneWidget);
    expect(
      tester.getCenter(underline).dx,
      moreOrLessEquals(
        tester
            .getCenter(
              find.bySemanticsLabel(RegExp(r'Ana Quispe · Principios')),
            )
            .dx,
        epsilon: 0.5,
      ),
    );

    // The pinned name column and the scrolling cells are two separate
    // widget subtrees: if their row heights ever drift apart, every name
    // lines up with the wrong person's cells.
    expect(
      tester.getCenter(find.text('Ana Quispe')).dy,
      moreOrLessEquals(
        tester
            .getCenter(find.bySemanticsLabel(RegExp(r'Ana Quispe · Phishing')))
            .dy,
        epsilon: 0.5,
      ),
    );
  });

  testWidgets('a cell reads its own numbers, aggregated per subtopic', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    // Ana's two Derechos Humanos sections stay two cells, never one sum.
    expect(
      find.bySemanticsLabel(RegExp(r'Ana Quispe · Principios.*1/4')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp(r'Ana Quispe · Debida diligencia.*0/1')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('hovering a cell shows its count and its tooltip', (
    tester,
  ) async {
    await _pump(tester);
    // Nothing but the tint until the pointer arrives.
    expect(find.text('1/4'), findsNothing);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);
    await tester.pump();
    await pointer.moveTo(
      tester.getCenter(
        find.bySemanticsLabel(RegExp(r'Ana Quispe · Principios')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1/4'), findsOneWidget);
    // The tooltip is a real widget tree: title, level pill, sentence.
    expect(find.text('Ana Quispe · Principios'), findsOneWidget);
    expect(find.text('Beginner'), findsWidgets);
    expect(
      find.textContaining('1 of 4 questions mastered · 6 attempts'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a person row opens their Persona page', (tester) async {
    final nav = await _pump(tester);
    await tester.tap(find.text('Ana Quispe'));
    await tester.pump();
    expect(nav.value.section, 'person');
    expect(nav.value.entityId, 'ana');
  });

  testWidgets('the empty state stands in for the grid', (tester) async {
    await _pump(tester, rows: const []);
    expect(find.text('Ana Quispe'), findsNothing);
    expect(find.text('NO MASTERY YET'), findsOneWidget);
  });

  // 1024 px of window minus the 220 px nav and the 24 px gutters is the
  // narrowest content column the console supports, and Spanish is 20-30 %
  // longer than the English the rest of these tests assert. An overflow, a
  // clipped column header or a wrapped toolbar fails here on its own.
  testWidgets('the Spanish grid fits its narrowest supported column', (
    tester,
  ) async {
    testuLang.value = 'es';
    addTearDown(() => testuLang.value = 'en');

    await _pump(tester, width: 756);

    expect(find.text('PERSONAS × SUBTEMAS'), findsOneWidget);
    expect(find.text('Personas por nivel'), findsOneWidget);
    expect(find.text('Por equipo'), findsOneWidget);
    expect(find.text('Orden: equipo'), findsOneWidget);
    expect(find.textContaining('Dominio acumulado'), findsOneWidget);
  });

  testWidgets('Recalcular polls until computedat moves', (tester) async {
    final http = _http(_cohort);
    await _pump(tester, http: http, operate: true);
    expect(find.textContaining('Recomputing'), findsNothing);

    await tester.tap(find.text('Recompute'));
    await tester.pump();
    // expect(http.posted.single.path, 'services/testu/analytics/recompute.json');
    expect(find.textContaining('Recomputing'), findsOneWidget);

    // First poll: the rollup has not landed, so nothing changes.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.textContaining('Recomputing'), findsOneWidget);
    expect(find.text('Rosa Nueva'), findsNothing);

    // Second poll: a newer computedat, and the screen swaps to it.
    http.canned['services/testu/analytics/report.json'] = _report([
      ..._cohort,
      {
        ..._row(
          'rosa',
          'Rosa Nueva',
          'ops',
          't1',
          'Derechos Humanos',
          's1',
          '1. Principios',
        ),
        'computedat': '2026-09-06T00:00:00Z',
      },
    ]);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Rosa Nueva'), findsOneWidget);
    expect(find.textContaining('Recomputing'), findsNothing);
    expect(find.text('Mastery recomputed.'), findsOneWidget);
    // Let the toast retire so the test leaves no timer behind.
    await tester.pump(const Duration(seconds: 5));
  });

  group('masteryCsv', () {
    test('carries the four calibration counters', () {
      final csv = masteryCsv([for (final r in _cohort) MasteryRow(r)]);
      final header = csv.split('\r\n').first.split(',');
      expect(header, contains('certainwrong'));
      expect(
        header,
        containsAll(['certaincorrect', 'unsurecorrect', 'unsurewrong']),
      );
      // Row order and values survive the export.
      expect(csv.split('\r\n')[1].split(','), contains('Ana Quispe'));
    });
  });

  // Section facts and a topic's weakest subtopic both open Dominio, and the
  // grid is the only thing here either can be about.
  testWidgets('a weakest-subtopic citation pulses the grid', (tester) async {
    final nav = await _pump(tester);

    nav.go('mastery', highlight: 'weakest');
    await tester.pump();
    expect(
      tester
          .widget<Pulse>(
            find
                .ancestor(
                  of: find.byType(HeatmapGrid),
                  matching: find.byType(Pulse),
                )
                .first,
          )
          .active,
      isTrue,
    );
  });

  // Section titles carry the course's own ordinal. Sorted as text, "10." lands
  // between "1." and "2." -- the columns of the one view whose order IS the
  // course order, scrambled.
  testWidgets('subtopic columns follow the ordinal, not the string', (
    tester,
  ) async {
    await _pump(
      tester,
      rows: [
        _row(
          'ana',
          'Ana Quispe',
          'ops',
          't2',
          'Ciberseguridad',
          'c1',
          '1. Contraseñas',
        ),
        _row(
          'ana',
          'Ana Quispe',
          'ops',
          't2',
          'Ciberseguridad',
          'c10',
          '10. Datos personales',
        ),
        _row(
          'ana',
          'Ana Quispe',
          'ops',
          't2',
          'Ciberseguridad',
          'c2',
          '2. Phishing',
        ),
      ],
    );

    double x(String name) => tester.getTopLeft(find.text(name)).dx;
    expect(x('Contraseñas') < x('Phishing'), isTrue);
    expect(
      x('Phishing') < x('Datos personales'),
      isTrue,
      reason: '"10." sorts after "2.", not between "1." and "2."',
    );
  });
}
