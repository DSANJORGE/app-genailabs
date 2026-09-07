import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_shell.dart';
import 'package:genai_labs/testu/testu_theme.dart';

AdminMe _me(Set<String> perms, {bool personas = true, bool analytics = true}) => AdminMe('m', 'm@x', 'M', 'x', perms,
    [SuiteModule('personas', 'Personas', ['web'], personas), SuiteModule('analytics', 'Analytics', ['web'], analytics)]);

void main() {
  test('a manager sees the three analytics screens and people, never teams', () {
    final ids = sectionsFor(_me({'personas_view', 'analytics_view'})).map((s) => s.id).toList();
    expect(ids, ['overview', 'activity', 'mastery', 'people']);
  });
  test('training also sees teams', () {
    expect(sectionsFor(_me({'personas_operate', 'personas_view', 'analytics_view'})).map((s) => s.id),
        ['overview', 'activity', 'mastery', 'people', 'teams']);
  });
  test('a disabled module hides its sections even with permissions', () {
    expect(sectionsFor(_me({'personas_view', 'analytics_view'}, analytics: false)).map((s) => s.id), ['people']);
  });
  test('no permissions means no sections', () {
    expect(sectionsFor(_me({})), isEmpty);
  });

  testWidgets('the nav lists exactly what the manager may open', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final http = FakeEmeHttp()
      ..canned['services/testu/analytics/report.json'] = {'rows': [], 'summary': {}, 'topics': []}
      ..canned['services/testu/personas/teams.json'] = {'teams': []};
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: AdminShell(
        me: _me({'personas_view', 'analytics_view'}),
        api: AdminApi(http: http),
        onSignOut: () {},
      ),
    ));
    await tester.pumpAndSettle();
    for (final label in ['Overview', 'Activity', 'Mastery', 'People']) {
      expect(find.text(label), findsWidgets, reason: '$label is missing from the nav');
    }
    expect(find.text('Teams'), findsNothing);
  });

  testWidgets('the no-access screen can sign out', (tester) async {
    var signOuts = 0;
    final noAccessMe = AdminMe('m', 'm@x', 'M', 'x', {}, const []);
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: AdminShell(me: noAccessMe, api: AdminApi(), onSignOut: () => signOuts++),
    ));
    await tester.tap(find.text('Sign out'));
    expect(signOuts, 1);
  });
}
