import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_teams.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_i18n.dart';
import 'package:genai_labs/testu/testu_theme.dart';

Map<String, dynamic> _teamsJson() => {
      'teams': [
        {'id': 'norte', 'name': 'Norte', 'manager': 'lider.norte'},
        {'id': 'sur', 'name': 'Sur'},
      ],
    };

Map<String, dynamic> _usersJson() => {
      'users': [
        {
          'id': 'lider.norte',
          'email': 'lider.norte@minsur.test',
          'firstName': 'Lider',
          'lastName': 'Norte',
          'role': 'manager',
          'team': 'norte',
        },
        {
          'id': 'ana',
          'email': 'ana@minsur.test',
          'firstName': 'Ana',
          'lastName': 'Quispe',
          'role': 'users',
          'team': 'norte',
        },
      ],
    };

Future<(FakeEmeHttp, ConsoleNav)> _pump(
  WidgetTester tester, {
  AdminMe? me,
  Map<String, dynamic>? teams,
  Map<String, dynamic>? users,
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final http = FakeEmeHttp();
  http.canned['services/testu/personas/teams.json'] = teams ?? _teamsJson();
  http.canned['services/testu/personas/users.json'] = users ?? _usersJson();
  final api = AdminApi(http: http);
  final nav = ConsoleNav();
  addTearDown(nav.dispose);
  final defaultMe = AdminMe('lider.norte', 'lider.norte@minsur.test', 'Lider Norte',
      'manager', {'personas_operate', 'analytics_view'}, const []);

  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(body: AdminTeams(api: api, me: me ?? defaultMe, nav: nav)),
  ));
  await tester.pumpAndSettle();
  return (http, nav);
}

void main() {
  testWidgets('shows team names, the manager name and the member count',
      (tester) async {
    await _pump(tester);

    expect(find.byType(AdminTable<AdminTeam>), findsOneWidget);
    expect(find.text('Norte'), findsOneWidget);
    expect(find.text('Sur'), findsOneWidget);
    expect(find.text('Lider Norte'), findsOneWidget);
    // Norte has two members in users.json; Sur has none.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('tapping a row navigates to the team', (tester) async {
    final (_, nav) = await _pump(tester);

    await tester.tap(find.text('Norte'));
    await tester.pumpAndSettle();

    expect(nav.value.section, 'team');
    expect(nav.value.entityId, 'norte');
  });

  // 1024 px of window minus the 220 px nav and the 24 px gutters is the
  // narrowest content column the console supports (see
  // test/admin_person_test.dart), minus this screen's own 20 px padding.
  testWidgets('the Spanish page fits its narrowest supported column',
      (tester) async {
    testuLang.value = 'es';
    addTearDown(() => testuLang.value = 'en');

    await _pump(
      tester,
      width: 756,
      teams: {
        'teams': [
          {
            'id': 'norte',
            'name': 'Operaciones Pisco Norte',
            'manager': 'lider.norte',
            'location': 'Pisco, Ica',
            'costcenter': 'CC-1042-OPERACIONES',
          },
        ],
      },
      users: {
        'users': [
          {
            'id': 'lider.norte',
            'email': 'lider.norte.contreras@operaciones-minsur.test',
            'firstName': 'Lider',
            'lastName': 'Norte',
            'role': 'manager',
            'team': 'norte',
          },
        ],
      },
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Operaciones Pisco Norte'), findsOneWidget);
    expect(find.text('Lider Norte'), findsOneWidget);
  });
}
