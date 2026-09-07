import 'dart:async';

import 'package:dio/dio.dart' show MultipartFile;
import 'package:eme_app_package/eme_http.dart';
import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_activity.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_iris.dart';
import 'package:genai_labs/admin/admin_mastery.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_overview.dart';
import 'package:genai_labs/admin/admin_people.dart';
import 'package:genai_labs/admin/admin_person.dart';
import 'package:genai_labs/admin/admin_shell.dart';
import 'package:genai_labs/admin/admin_team.dart';
import 'package:genai_labs/admin/admin_teams.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_theme.dart';

/// Every console screen, in its three states (spec analytics-v1 5): the
/// skeleton while the reply is out, the empty state when the reply is empty,
/// and the error panel when it fails.
///
/// One file for all of them on purpose. Each screen's own test file proves
/// what that screen SAYS; this one proves that none of them can ever show a
/// reader a blank card, a spinner or a thrown object -- which is a property of
/// the set, not of any one screen, and the kind of thing that rots the moment
/// a screen is added without being asked the same three questions.

/// A server that never answers. The screens must sit on their skeleton
/// rather than paint a half-built page off null data.
class _Pending implements EmeHttp {
  final _never = Completer<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>> getJson(String path,
          {Map<String, String> query = const {},
          EmeAuth auth = EmeAuth.token}) =>
      _never.future;

  @override
  Future<Map<String, dynamic>> postForm(
    String path,
    Iterable<MapEntry<String, String>> fields, {
    EmeAuth auth = EmeAuth.token,
  }) =>
      _never.future;

  @override
  Future<Map<String, dynamic>> post(String path,
          {Iterable<MapEntry<String, String>> query = const [],
          List<MapEntry<String, MultipartFile>>? files,
          EmeAuth auth = EmeAuth.token}) =>
      _never.future;
}

/// Every endpoint the console reads, answering `{ok:true}` and nothing else --
/// a brand-new organisation on its first day. The lists a full reply carries
/// are absent rather than empty on purpose: that is what an endpoint with
/// nothing to report actually sends.
const _paths = [
  'services/testu/analytics/overview.json',
  'services/testu/analytics/activity.json',
  'services/testu/analytics/report.json',
  'services/testu/analytics/person.json',
  'services/testu/personas/users.json',
  'services/testu/personas/teams.json',
];

FakeEmeHttp _emptyHttp() {
  final http = FakeEmeHttp();
  for (final p in _paths) {
    http.canned[p] = const {'ok': true};
  }
  return http;
}

/// No canned reply anywhere: every read throws a 404 [EmeHttpException],
/// which is the same shape a 500 or a dead connection arrives in.
FakeEmeHttp _failingHttp() => FakeEmeHttp();

final _me = AdminMe(
  'm',
  'm@x',
  'Diego San Jorge',
  'orgadmin',
  const {
    'analytics_view',
    'analytics_operate',
    'personas_view',
    'personas_operate',
  },
  [
    SuiteModule('analytics', 'Analytics', const ['web'], true),
    SuiteModule('personas', 'Personas', const ['web'], true),
  ],
  persona: AdminPersona('Iris', organization: 'Minsur'),
);

typedef _Screen = ({
  String name,
  Widget Function(AdminApi api, AnalyticsFilters filters, ConsoleNav nav) build,
  String? emptyCopy,
});

final _screens = <_Screen>[
  (
    name: 'Resumen',
    build: (api, filters, nav) =>
        AdminOverview(api: api, me: _me, filters: filters, nav: nav),
    emptyCopy: null,
  ),
  (
    name: 'Actividad',
    build: (api, filters, nav) =>
        AdminActivity(api: api, me: _me, filters: filters, nav: nav),
    emptyCopy: null,
  ),
  (
    name: 'Dominio',
    build: (api, filters, nav) =>
        AdminMastery(api: api, me: _me, filters: filters, nav: nav),
    emptyCopy: null,
  ),
  (
    name: 'Persona',
    build: (api, filters, nav) => AdminPerson(
        api: api, me: _me, filters: filters, nav: nav, userId: 'u1'),
    emptyCopy: 'Nothing answered yet.',
  ),
  (
    name: 'Equipo',
    build: (api, filters, nav) => AdminTeamPage(
        api: api, me: _me, filters: filters, nav: nav, teamId: 'team-pisco'),
    emptyCopy: 'Nobody is in this team yet.',
  ),
  (
    name: 'Colaboradores',
    build: (api, filters, nav) => AdminPeople(api: api, me: _me, nav: nav),
    emptyCopy: 'No collaborators yet.',
  ),
  (
    name: 'Equipos',
    build: (api, filters, nav) => AdminTeams(api: api, me: _me, nav: nav),
    emptyCopy: 'No teams yet.',
  ),
];

/// Mirrors AdminScaffold, which already hands every screen a ListView.
Future<void> _pump(WidgetTester tester, EmeHttp http, _Screen screen) async {
  tester.view.physicalSize = const Size(1440, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final filters = AnalyticsFilters();
  final nav = ConsoleNav(ConsoleRoute('overview'));
  addTearDown(filters.dispose);
  addTearDown(nav.dispose);

  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: ListView(
        children: [screen.build(AdminApi(http: http), filters, nav)],
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final screen in _screens) {
    testWidgets('${screen.name}: a reply that has not landed is a skeleton',
        (tester) async {
      await _pump(tester, _Pending(), screen);

      expect(find.byType(Skeleton), findsWidgets);
      expect(find.byType(ConsolePanelError), findsNothing);
      // A reply that has not landed is not an empty organisation: showing
      // "nobody has answered yet" while the answer is still in flight is the
      // one wrong thing a loading state can say.
      expect(find.byType(EmptyState), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${screen.name}: an empty reply teaches instead of blanking',
        (tester) async {
      await _pump(tester, _emptyHttp(), screen);

      expect(tester.takeException(), isNull);
      expect(find.byType(Skeleton), findsNothing);
      expect(find.byType(ConsolePanelError), findsNothing,
          reason: 'nothing failed: the organisation is simply new');
      final copy = screen.emptyCopy;
      if (copy == null) {
        expect(find.byType(EmptyState), findsWidgets);
      } else {
        expect(find.text(copy), findsWidgets);
      }
    });

    testWidgets('${screen.name}: a failed read says so and offers a retry',
        (tester) async {
      await _pump(tester, _failingHttp(), screen);

      expect(tester.takeException(), isNull);
      expect(find.byType(ConsolePanelError), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(Skeleton), findsNothing);
    });
  }

  // The shell is the ninth screen: it owns the frame every state above is
  // drawn inside, and a state that only works outside the frame is not a
  // state the console has.
  Future<void> pumpShell(WidgetTester tester, EmeHttp http, String state) async {
    tester.view.physicalSize = const Size(1440, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: AdminShell(
        // A key per state: without one the second pump reuses the first
        // shell's State, and the screen under test never fetches again.
        key: ValueKey(state),
        me: _me,
        api: AdminApi(http: http),
        onSignOut: () {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Shell: the frame carries each of the three states',
      (tester) async {
    await pumpShell(tester, _Pending(), 'loading');
    expect(find.byType(Skeleton), findsWidgets);
    expect(tester.takeException(), isNull);

    await pumpShell(tester, _emptyHttp(), 'empty');
    expect(find.byType(EmptyState), findsWidgets);
    expect(tester.takeException(), isNull);

    await pumpShell(tester, _failingHttp(), 'error');
    expect(find.byType(ConsolePanelError), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Iris is a panel, not a fetch screen: its three states are the empty
  // thread, the question in flight, and the tutor being down.
  group('Iris', () {
    Future<void> pumpPanel(WidgetTester tester, EmeHttp http) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final nav = ConsoleNav(ConsoleRoute('overview'));
      final filters = AnalyticsFilters();
      final thread = IrisThread();
      addTearDown(nav.dispose);
      addTearDown(filters.dispose);
      addTearDown(thread.dispose);

      await tester.pumpWidget(MaterialApp(
        theme: testuTheme(),
        home: Scaffold(
          body: IrisPanel(
            api: AdminApi(http: http),
            nav: nav,
            filters: filters,
            persona: AdminPersona('Iris', organization: 'Minsur'),
            screen: 'overview',
            thread: thread,
            onClose: () {},
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('an empty thread offers openers rather than a blank panel',
        (tester) async {
      await pumpPanel(tester, _emptyHttp());

      expect(find.text('Ask me about activity, mastery or one person.'),
          findsOneWidget);
      expect(find.text('Who needs help this week?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a question in flight says it is thinking', (tester) async {
      await pumpPanel(tester, _Pending());

      await tester.tap(find.text('Who needs help this week?'));
      await tester.pump();

      expect(find.bySemanticsLabel('Thinking'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a tutor that cannot answer says so and offers a retry',
        (tester) async {
      await pumpPanel(tester, _failingHttp());

      await tester.tap(find.text('Who needs help this week?'));
      await tester.pumpAndSettle();

      expect(find.text('Iris is not available right now.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
