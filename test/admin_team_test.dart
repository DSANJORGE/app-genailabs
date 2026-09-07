import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_team.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_i18n.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _overview = 'services/testu/analytics/overview.json';
const _report = 'services/testu/analytics/report.json';
const _users = 'services/testu/personas/users.json';
const _teams = 'services/testu/personas/teams.json';

final _me = AdminMe('m', 'm@x', 'Diego San Jorge', 'training',
    {'analytics_view', 'personas_view'}, const [],
    persona: AdminPersona('Iris', organization: 'Minsur'));

/// The roster endpoints need personas_view and answer 403 without it -- and
/// that 403 ends the session, so they must not be called at all.
final _analyticsOnly = AdminMe('m', 'm@x', 'Diego San Jorge', 'training',
    {'analytics_view'}, const [],
    persona: AdminPersona('Iris', organization: 'Minsur'));

/// Yesterday, so the "active 7 d" column has something true in it whenever
/// this test runs.
final _recent = DateTime.now().subtract(const Duration(days: 1));

String _iso(DateTime d) => d.toIso8601String();

Map<String, dynamic> _overviewJson({Map<String, dynamic>? median}) => {
      'ok': true,
      'cohort': {'total': 9, 'activated': 8, 'active7d': 6, 'active30d': 8},
      'series': [
        for (var i = 0; i < 7; i++)
          {
            'day': '2026-09-0${i + 1}',
            'people': 3 + i,
            'answers': 20 + i,
            'minutes': 10 + i,
            'certainwrong': 1,
            'questions': 2,
          },
      ],
      'levels': {'notstarted': 1, 'beginner': 2, 'competent': 4, 'expert': 2},
      'topics': const [],
      'calibration': {'cc': 10, 'cu': 2, 'ic': 3, 'iu': 1},
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
      ],
      'median': median ?? {'activeShare': 0.48, 'expertShare': 0.2},
      'previous': {'active7d': 4},
      'gaps': const [],
      'iris': {
        'questions': 12,
        'people': 4,
        'sections': [
          {'section': '5', 'name': 'Debida diligencia', 'questions': 7},
          {'section': '2', 'name': 'Phishing', 'questions': 5},
        ],
      },
    };

/// Two members of the team plus one outsider who must never appear.
Map<String, dynamic> _usersJson() => {
      'users': [
        {
          'id': 'u1',
          'email': 'ana@x',
          'firstName': 'Ana',
          'lastName': 'Quispe',
          'team': 'team-pisco',
          'role': 'users',
          'enabled': true,
          'lastactivity': _iso(_recent),
        },
        {
          'id': 'u2',
          'email': 'luis@x',
          'firstName': 'Luis',
          'lastName': 'Rojas',
          'team': 'team-pisco',
          'role': 'manager',
          'enabled': true,
        },
        {
          'id': 'u9',
          'email': 'otro@x',
          'firstName': 'Otro',
          'lastName': 'Equipo',
          'team': 'team-lima',
          'role': 'users',
          'enabled': true,
        },
      ],
    };

Map<String, dynamic> _teamsJson() => {
      'teams': [
        {
          'id': 'team-pisco',
          'name': 'Operaciones Pisco',
          'parent': 'team-peru',
          'manager': 'u2',
          'members': 9,
        },
        {'id': 'team-peru', 'name': 'Perú', 'members': 24},
      ],
    };

/// u1 has answered in two topics (weakest is Ciberseguridad); u2 has rows
/// but has answered nothing, so they have not started.
Map<String, dynamic> _reportJson() => {
      'rows': [
        {
          'user': 'u1',
          'name': 'Ana Quispe',
          'team': 'team-pisco',
          'entitytopic': 'topic-ddhh',
          'topic': 'Derechos Humanos',
          'componentsection': '5',
          'section': '2. Debida diligencia',
          'questions': 10,
          'answered': 8,
          'mastered': 5,
          'level': 'competent',
          'lastactivity': _iso(_recent),
        },
        {
          'user': 'u1',
          'name': 'Ana Quispe',
          'team': 'team-pisco',
          'entitytopic': 'topic-ciber',
          'topic': 'Ciberseguridad',
          'componentsection': '2',
          'section': '1. Phishing',
          'questions': 6,
          'answered': 4,
          'mastered': 1,
          'level': 'beginner',
          'lastactivity': _iso(_recent),
        },
        {
          'user': 'u2',
          'name': 'Luis Rojas',
          'team': 'team-pisco',
          'entitytopic': 'topic-ddhh',
          'topic': 'Derechos Humanos',
          'componentsection': '5',
          'section': '2. Debida diligencia',
          'questions': 10,
          'answered': 0,
          'mastered': 0,
        },
      ],
      'summary': {'activeusers7d': 1, 'answers7d': 12, 'levels': {}},
      'topics': [
        {'id': 'topic-ddhh', 'name': 'Derechos Humanos'},
        {'id': 'topic-ciber', 'name': 'Ciberseguridad'},
      ],
    };

Future<(FakeEmeHttp, AnalyticsFilters, ConsoleNav)> _pump(
  WidgetTester tester, {
  bool canned = true,
  Map<String, dynamic>? overview,
  AdminMe? me,
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final http = FakeEmeHttp();
  if (canned) {
    http.canned[_overview] = overview ?? _overviewJson();
    http.canned[_users] = _usersJson();
    http.canned[_teams] = _teamsJson();
    http.canned[_report] = _reportJson();
  }
  final filters = AnalyticsFilters();
  final nav = ConsoleNav(const ConsoleRoute('team', entityId: 'team-pisco'));
  addTearDown(filters.dispose);
  addTearDown(nav.dispose);

  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: ListView(children: [
        AdminTeamPage(
          api: AdminApi(http: http),
          me: me ?? _me,
          filters: filters,
          nav: nav,
          teamId: 'team-pisco',
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  return (http, filters, nav);
}

void main() {
  testWidgets('the team is fetched with its own id and the org without one',
      (tester) async {
    final (http, _, _) = await _pump(tester);

    final overviews =
        http.requests.where((r) => r.$1 == _overview).toList();
    expect(overviews.length, 2, reason: 'the team and the whole organisation');
    expect(
      overviews.map((r) => (r.$2 as Map)['team']).toSet(),
      {'team-pisco', null},
    );
  });

  testWidgets('the header and the reading open the screen', (tester) async {
    await _pump(tester);

    expect(find.text('Operaciones Pisco'), findsWidgets);
    // The manager is stored as a user id; the page shows the person.
    expect(find.textContaining('Luis Rojas'), findsWidgets);
    expect(
      find.text('Operaciones Pisco: 6 of 9 people active this week, 67%.'),
      findsOneWidget,
    );
    expect(find.text('ACTIVE 7 D'), findsOneWidget);
    expect(find.text('organisation median 48%'), findsOneWidget);
    // The stats follow a period this page has no control over, so it says
    // which one out loud.
    expect(find.textContaining('Period 30 d'), findsOneWidget);
  });

  testWidgets('an organisation under five people gets no median line',
      (tester) async {
    final canned = _overviewJson()..remove('median');
    await _pump(tester, overview: canned);

    expect(find.textContaining('organisation median'), findsNothing);
  });

  testWidgets('the member table joins users with their mastery rows',
      (tester) async {
    await _pump(tester);

    expect(find.text('Ana Quispe'), findsOneWidget);
    expect(find.text('Luis Rojas'), findsWidgets);
    // The outsider is not in this team.
    expect(find.text('Otro Equipo'), findsNothing);
    // u1 answered in two topics and is weakest in Ciberseguridad.
    expect(find.text('Ciberseguridad'), findsWidgets);
  });

  testWidgets('a viewer without personas_view keeps the analytics half',
      (tester) async {
    final (http, _, _) = await _pump(tester, me: _analyticsOnly);

    expect(http.requests.where((r) => r.$1 == _users), isEmpty);
    expect(http.requests.where((r) => r.$1 == _teams), isEmpty);
    expect(find.text('ACTIVE 7 D'), findsOneWidget);
    expect(find.text('Your account cannot list people.'), findsOneWidget);
  });

  testWidgets('the level bar and the started column read per person',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester);

    // u1 has answered two subtopics, one of each level; u2 has a row but no
    // answers, so nothing has started for them.
    expect(find.bySemanticsLabel(RegExp('Beginner 1, Competent 1')),
        findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('No data 1')), findsOneWidget);
    // Han empezado / Activos 7 d, two members: yes-yes and no-no.
    expect(find.text('Yes'), findsNWidgets(2));
    expect(find.text('No'), findsNWidgets(2));
    semantics.dispose();
  });

  testWidgets('a member row drills into that person', (tester) async {
    final (_, _, nav) = await _pump(tester);

    await tester.tap(find.text('Ana Quispe'));
    await tester.pumpAndSettle();

    expect(nav.value.section, 'person');
    expect(nav.value.entityId, 'u1');
  });

  testWidgets('a failed load offers exactly one way out', (tester) async {
    await _pump(tester, canned: false);

    expect(find.byType(ConsolePanelError), findsOneWidget);
  });

  testWidgets('the Spanish page fits its narrowest supported column',
      (tester) async {
    testuLang.value = 'es';
    addTearDown(() => testuLang.value = 'en');

    await _pump(tester, width: 756);

    expect(find.text('mediana de la organización 48 %'), findsOneWidget);
    expect(find.text('ACTIVOS 7 D'), findsOneWidget);
  });

  // The team aggregate fact opens this page, and what it describes is the
  // stat row -- so the row answers to `team` as well as `stat`.
  testWidgets('a team citation pulses the stat row', (tester) async {
    final (_, _, nav) = await _pump(tester);

    nav.go('team', entityId: 'team-pisco', highlight: 'team');
    await tester.pump();
    expect(
        tester
            .widget<Pulse>(find
                .ancestor(
                    of: find.byType(StatRow), matching: find.byType(Pulse))
                .first)
            .active,
        isTrue);
  });

}
