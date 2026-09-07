import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_iris.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_shell.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:genai_labs/testu/testu_widgets.dart';

AdminMe _me(Set<String> perms,
        {bool personas = true, bool analytics = true, AdminPersona? persona}) =>
    AdminMe('m', 'm@x', 'M', 'x', perms, [
      SuiteModule('personas', 'Personas', ['web'], personas),
      SuiteModule('analytics', 'Analytics', ['web'], analytics),
    ], persona: persona);

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

  group('routeFromUri', () {
    // Flutter web's default strategy puts our route in the fragment; a
    // console served under usePathUrlStrategy() puts it in the path.
    test('reads a hash URL', () {
      final r = routeFromUri(Uri.parse('http://x/admin/#/person?id=u42'))!;
      expect(r.section, 'person');
      expect(r.entityId, 'u42');
    });
    test('reads a path URL', () {
      final r = routeFromUri(Uri.parse('http://x/activity'))!;
      expect(r.section, 'activity');
      expect(r.entityId, isNull);
    });
    test('an addressless load has no route', () {
      expect(routeFromUri(Uri.parse('http://x/')), isNull);
      expect(routeFromUri(Uri.parse('http://x/admin/#/')), isNull);
    });
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

  group('the Iris panel', () {
    /// A shell with the analytics trio, its label fetches canned, and one
    /// canned answer waiting behind ask.json.
    Future<FakeEmeHttp> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final http = FakeEmeHttp()
        ..canned['services/testu/analytics/report.json'] =
            {'rows': [], 'summary': {}, 'topics': []}
        ..canned['services/testu/personas/teams.json'] = {'teams': []}
        ..canned['services/testu/analytics/overview.json'] = {'ok': true}
        ..canned['services/testu/analytics/activity.json'] = {'ok': true}
        ..canned['services/testu/analytics/ask.json'] = {
          'ok': true,
          'answer': 'Doce personas activas.',
          'citations': const [],
          'followups': const [],
        };
      await tester.pumpWidget(MaterialApp(
        theme: testuTheme(),
        home: AdminShell(
          me: _me({'analytics_view'},
              persona: AdminPersona('Iris', organization: 'Minsur')),
          api: AdminApi(http: http),
          onSignOut: () {},
        ),
      ));
      await tester.pumpAndSettle();
      return http;
    }

    testWidgets('opens from the title row and closes on Ctrl-/', (tester) async {
      await pump(tester);
      expect(find.byType(IrisPanel), findsNothing);

      await tester.tap(find.widgetWithText(TestuPressable, 'Iris'));
      await tester.pumpAndSettle();
      expect(find.byType(IrisPanel), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.byType(IrisPanel), findsNothing);
    });

    testWidgets('keeps its thread across a section change', (tester) async {
      await pump(tester);
      await tester.tap(find.widgetWithText(TestuPressable, 'Iris'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '¿Cuántas activas?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      expect(find.text('Doce personas activas.', findRichText: true),
          findsOneWidget);

      await tester.tap(find.text('Activity').first);
      await tester.pumpAndSettle();
      expect(find.text('Doce personas activas.', findRichText: true),
          findsOneWidget,
          reason: 'the thread lives in the shell, not in the screen');
    });
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

  // Mastery is cumulative: the period control on Dominio was a lever wired to
  // nothing, and its footnote already says so.
  testWidgets('Dominio offers no period control, the other two do',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final http = FakeEmeHttp()
      ..canned['services/testu/analytics/report.json'] =
          {'rows': [], 'summary': {}, 'topics': []}
      ..canned['services/testu/personas/teams.json'] = {'teams': []}
      ..canned['services/testu/analytics/overview.json'] = {'ok': true};
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: AdminShell(
        me: _me({'analytics_view'}),
        api: AdminApi(http: http),
        onSignOut: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('7 d'), findsOneWidget, reason: 'Resumen reads a period');

    await tester.tap(find.text('Mastery').first);
    await tester.pumpAndSettle();
    expect(find.text('7 d'), findsNothing);
    // The two filters mastery DOES read are still on the bar.
    expect(find.text('All topics'), findsOneWidget);
    expect(find.text('All teams'), findsOneWidget);
  });

  // At 1024 a pushed panel leaves 396 px of content and every table in the
  // console overflows it. The panel floats over the column instead.
  testWidgets('the Iris panel never squeezes the content below its floor',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<double> contentWidth(Size size) async {
      tester.view.physicalSize = size;
      final http = FakeEmeHttp()
        ..canned['services/testu/analytics/report.json'] =
            {'rows': [], 'summary': {}, 'topics': []}
        ..canned['services/testu/personas/teams.json'] = {'teams': []}
        ..canned['services/testu/analytics/overview.json'] = {'ok': true};
      await tester.pumpWidget(MaterialApp(
        theme: testuTheme(),
        home: AdminShell(
          // A fresh shell per size: without a key the second pump reuses the
          // first one's state, panel already open.
          key: ValueKey(size.width),
          me: _me({'analytics_view'},
              persona: AdminPersona('Iris', organization: 'Minsur')),
          api: AdminApi(http: http),
          onSignOut: () {},
        ),
      ));
      await tester.pumpAndSettle();
      final before = tester.getSize(find.byType(ContextBar)).width;
      await tester.tap(find.widgetWithText(TestuPressable, 'Iris'));
      await tester.pumpAndSettle();
      expect(find.byType(IrisPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
      return tester.getSize(find.byType(ContextBar)).width / before;
    }

    // 1440: the panel pushes, and the content still clears the floor.
    expect(await contentWidth(const Size(1440, 900)), lessThan(1));
    // 1024: it floats, so the screen underneath keeps its width.
    expect(await contentWidth(const Size(1024, 768)), 1);
  });

}
