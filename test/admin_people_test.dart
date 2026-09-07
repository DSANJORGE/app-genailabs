import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_people.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_i18n.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _usersPath = 'services/testu/personas/users.json';
const _teamsPath = 'services/testu/personas/teams.json';

Map<String, dynamic> _usersJson() => {
      'users': [
        {
          'id': 'u1',
          'email': 'ana@minsur.test',
          'firstName': 'Ana',
          'lastName': 'Quispe',
          'team': 'norte',
          'role': 'users',
          'enabled': true,
        },
      ],
    };

Map<String, dynamic> _teamsJson() => {
      'teams': [
        {'id': 'norte', 'name': 'Norte'},
      ],
    };

final _fullAccess = AdminMe('m', 'm@x', 'Lider', 'orgadmin',
    {'analytics_view', 'personas_view', 'personas_operate', 'personas_manage'},
    const []);

final _noManage = AdminMe('m', 'm@x', 'Lider', 'manager',
    {'analytics_view', 'personas_view', 'personas_operate'}, const []);

/// A viewer who can disable people but isn't allowed near an orgadmin/
/// training account -- `disableuser.json` 403s for them, and a 403 ends the
/// whole console session.
final _operateOnly = AdminMe('m', 'm@x', 'Lider', 'manager',
    {'analytics_view', 'personas_view', 'personas_operate'}, const []);

Future<(FakeEmeHttp, ConsoleNav)> _pump(
  WidgetTester tester, {
  AdminMe? me,
  Map<String, dynamic>? users,
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final http = FakeEmeHttp();
  http.canned[_usersPath] = users ?? _usersJson();
  http.canned[_teamsPath] = _teamsJson();
  final nav = ConsoleNav();
  addTearDown(nav.dispose);

  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: AdminPeople(api: AdminApi(http: http), me: me ?? _fullAccess, nav: nav),
    ),
  ));
  await tester.pumpAndSettle();
  return (http, nav);
}

void main() {
  testWidgets('the row list renders through AdminTable, not DataTable',
      (tester) async {
    await _pump(tester);

    expect(find.byType(AdminTable<AdminUser>), findsOneWidget);
    expect(find.text('Ana Quispe'), findsOneWidget);
  });

  testWidgets('tapping a row navigates to the person', (tester) async {
    final (_, nav) = await _pump(tester);

    await tester.tap(find.text('Ana Quispe'));
    await tester.pumpAndSettle();

    expect(nav.value.section, 'person');
    expect(nav.value.entityId, 'u1');
  });

  testWidgets('the role select only appears with personas_manage',
      (tester) async {
    // Select itself renders the selected item's label as its box text, so
    // this can't be told apart by searching for "Learner" -- assert on the
    // Select widget count instead: team select always shows (personas_operate
    // is set on both), role select only with personas_manage.
    await _pump(tester, me: _fullAccess);
    expect(find.byType(Select<String>), findsNWidgets(2));

    await _pump(tester, me: _noManage);
    expect(find.byType(Select<String>), findsOneWidget);
  });

  testWidgets('the search box matches the team name, not its raw id',
      (tester) async {
    await _pump(tester, me: _noManage);

    await tester.enterText(find.byType(TextField).first, 'norte');
    await tester.pumpAndSettle();

    expect(find.text('Ana Quispe'), findsOneWidget);
  });

  testWidgets('the empty state distinguishes an empty org from no matches',
      (tester) async {
    await _pump(tester, users: {'users': <Map<String, dynamic>>[]});
    expect(find.text('No collaborators yet.'), findsOneWidget);

    await _pump(tester, me: _noManage);
    await tester.enterText(find.byType(TextField).first, 'nobody-matches-this');
    await tester.pumpAndSettle();
    expect(find.text('No one matches.'), findsOneWidget);
  });

  testWidgets(
      'Desactivar is hidden for an orgadmin row when the viewer lacks '
      'personas_manage', (tester) async {
    await _pump(
      tester,
      me: _operateOnly,
      users: {
        'users': [
          {
            'id': 'u2',
            'email': 'admin@minsur.test',
            'firstName': 'Ada',
            'lastName': 'Min',
            'team': 'norte',
            'role': 'orgadmin',
            'enabled': true,
          },
        ],
      },
    );

    expect(find.text('Disable'), findsNothing);
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
      users: {
        'users': [
          {
            'id': 'u1',
            'email': 'ana.quispe.contreras@operaciones-minsur.test',
            'firstName': 'Ana',
            'lastName': 'Quispe Contreras',
            'team': 'norte',
            // 'orgadmin' carries the longest Spanish role label ("Admin de
            // organización") and the Select that renders it is fixed to the
            // column's width: the label has to give way, not paint overflow
            // stripes over the row.
            'role': 'orgadmin',
            'enabled': true,
          },
        ],
      },
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Ana Quispe Contreras'), findsOneWidget);
  });

  // Every row on this screen drills into a person, and two of its cells are
  // controls of their own. A tap on the team select must open the menu and
  // leave the reader where they are -- a row that navigates out from under an
  // open menu is the worst kind of surprise.
  testWidgets('a control inside a row does not also open the row',
      (tester) async {
    final (http, nav) = await _pump(tester, me: _fullAccess);
    http.canned['services/testu/personas/setteam.json'] = {'ok': true};
    http.canned['services/testu/personas/disableuser.json'] = {'ok': true};
    expect(nav.value.section, 'resumen');

    await tester.tap(find.byType(Select<String>).first);
    await tester.pumpAndSettle();
    expect(nav.value.section, 'resumen', reason: 'the row must not navigate');
    // The menu is open: the team is on screen twice now (the closed box and
    // the menu entry).
    expect(find.text('Norte'), findsNWidgets(2));

    // Picking from it is a mutation, still not a navigation.
    await tester.tap(find.text('Norte').last);
    await tester.pumpAndSettle();
    expect(http.posted.single.path, 'services/testu/personas/setteam.json');
    expect(nav.value.section, 'resumen');

    // Same for the row's own TextButton.
    await tester.tap(find.text('Disable').first);
    await tester.pumpAndSettle();
    expect(http.posted.last.path, 'services/testu/personas/disableuser.json');
    expect(nav.value.section, 'resumen');
  });

  group('the CSV import dialog', () {
    Future<void> paste(WidgetTester tester, String csv) async {
      await tester.tap(find.text('Import CSV'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, csv);
      await tester.pumpAndSettle();
    }

    testWidgets('text it cannot read says what the file must look like',
        (tester) async {
      await _pump(tester);
      await paste(tester, 'pegué cualquier cosa');

      expect(
        find.textContaining('No rows recognised.'),
        findsOneWidget,
      );
      expect(find.text('Import 0 rows'), findsOneWidget);
    });

    testWidgets('rows it rejects are counted, not just coloured',
        (tester) async {
      await _pump(tester);
      await paste(
        tester,
        'email,firstName,lastName,team\n'
        'no-arroba,Ana,Quispe,norte\n'
        'luis@minsur.test,Luis,Huamán,equipo-que-no-existe\n',
      );

      expect(find.text('Invalid email'), findsOneWidget);
      expect(find.textContaining('Unknown team'), findsOneWidget);
      expect(find.textContaining('No row can be imported'), findsOneWidget);
      expect(find.text('Import 0 rows'), findsOneWidget);
    });

    testWidgets('a good paste says how many rows are ready', (tester) async {
      await _pump(tester);
      await paste(
        tester,
        'email,firstName,lastName,team\n'
        'luis@minsur.test,Luis,Huamán,norte\n'
        'rosa@minsur.test,Rosa,Cárdenas,norte\n',
      );

      expect(find.text('2 rows ready to import.'), findsOneWidget);
      expect(find.text('Import 2 rows'), findsOneWidget);
    });
  });

}
