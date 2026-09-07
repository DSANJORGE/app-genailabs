import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_shell.dart';
import 'package:genai_labs/testu/testu_theme.dart';

AdminMe _me(Set<String> perms, {bool personas = true, bool analytics = true}) => AdminMe('m', 'm@x', 'M', 'x', perms,
    [SuiteModule('personas', 'Personas', ['web'], personas), SuiteModule('analytics', 'Analytics', ['web'], analytics)]);

void main() {
  test('a manager sees people (read-only) and mastery, never teams', () {
    final ids = sectionsFor(_me({'personas_view', 'analytics_view'})).map((s) => s.id).toList();
    expect(ids, ['people', 'mastery']);
  });
  test('training sees people, teams and mastery', () {
    expect(sectionsFor(_me({'personas_operate', 'personas_view', 'analytics_view'})).map((s) => s.id), ['people', 'teams', 'mastery']);
  });
  test('a disabled module hides its sections even with permissions', () {
    expect(sectionsFor(_me({'personas_view', 'analytics_view'}, analytics: false)).map((s) => s.id), ['people']);
  });
  test('no permissions means no sections', () {
    expect(sectionsFor(_me({})), isEmpty);
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
