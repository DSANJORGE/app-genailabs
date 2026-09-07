import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_teams.dart';
import 'package:genai_labs/testu/testu_theme.dart';

void main() {
  testWidgets('shows team names and the manager name', (tester) async {
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
        },
      ],
    };
    final api = AdminApi(http: http);
    final me = AdminMe('lider.norte', 'lider.norte@minsur.test', 'Lider Norte', 'manager', {'personas_operate'}, const []);

    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: Scaffold(body: AdminTeams(api: api, me: me)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Norte'), findsOneWidget);
    expect(find.text('Sur'), findsOneWidget);
    expect(find.text('Lider Norte'), findsOneWidget);
  });
}
