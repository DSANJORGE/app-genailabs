import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_teams.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_theme.dart';

Future<(FakeEmeHttp, ConsoleNav)> _pump(WidgetTester tester, {AdminMe? me}) async {
  final http = FakeEmeHttp();
  http.canned['services/testu/personas/teams.json'] = {
    'teams': [
      {'id': 'norte', 'name': 'Norte', 'manager': 'lider.norte'},
      {'id': 'sur', 'name': 'Sur'},
    ],
  };
  http.canned['services/testu/personas/users.json'] = {
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

  testWidgets("tapping 'View team' navigates to the team", (tester) async {
    final (_, nav) = await _pump(tester);

    await tester.tap(find.text('View team').first);
    await tester.pumpAndSettle();

    expect(nav.value.section, 'team');
    expect(nav.value.entityId, 'norte');
  });
}
