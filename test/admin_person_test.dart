import 'package:eme_app_package/eme_http.dart';
import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_person.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_i18n.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _path = 'services/testu/analytics/person.json';

final _me = AdminMe('m', 'm@x', 'Diego San Jorge', 'training', {'analytics_view'},
    const [], persona: AdminPersona('Iris', organization: 'Minsur'));

/// A whole person.json, the shape person.groovy sends: `user` carries a flat
/// `name` and eMe's raw `lastlogin` (NOT ISO-8601), two mastery rows, a dense
/// daily series with correct/answers, two topics and the Iris tallies.
Map<String, dynamic> _canned({Map<String, dynamic>? iris}) => {
      'ok': true,
      'user': {
        'id': 'u1',
        'name': 'Ana Quispe',
        'team': 'Operaciones Pisco',
        'role': 'manager',
        'enabled': true,
        'lastlogin': '2026-09-05 22:55:49 -0300',
      },
      'rows': [
        {
          'user': 'u1',
          'entitytopic': 'topic-ddhh',
          'topic': 'Derechos Humanos',
          'componentsection': '5',
          'section': '2. Debida diligencia',
          'questions': 10,
          'answered': 8,
          'mastered': 5,
          'attempts': 11,
          'correct': 5,
          'level': 'competent',
          'lastactivity': '2026-09-05T10:00:00-05:00',
        },
        {
          'user': 'u1',
          'entitytopic': 'topic-ciber',
          'topic': 'Ciberseguridad',
          'componentsection': '2',
          'section': '1. Phishing',
          'questions': 6,
          'answered': 4,
          'mastered': 1,
          'attempts': 6,
          'correct': 1,
          'level': 'beginner',
          'lastactivity': '2026-09-03T10:00:00-05:00',
        },
      ],
      'series': [
        for (var i = 0; i < 7; i++)
          {
            'day': '2026-09-0${i + 1}',
            'answers': 4 + i,
            'correct': 2 + i,
            'minutes': 5,
            'sessions': 1,
            'questions': 1,
          },
      ],
      'calibration': {'cc': 12, 'cu': 4, 'ic': 3, 'iu': 2},
      'topics': [
        {
          'id': 'topic-ddhh',
          'name': 'Derechos Humanos',
          'level': 'competent',
          'mastered': 5,
          'answered': 8,
          'weakest': '2. Debida diligencia',
        },
        {
          'id': 'topic-ciber',
          'name': 'Ciberseguridad',
          'level': 'beginner',
          'mastered': 1,
          'answered': 4,
        },
      ],
      'usage': {'sessions': 4, 'minutes': 37, 'activeDays': 3},
      'iris': iris ??
          {
            'questions': 6,
            'sections': [
              {'section': '5', 'name': 'Debida diligencia', 'questions': 4},
            ],
            'helpfulShare': 0.5,
          },
    };

/// The server's 403 for a manager reading someone outside their teams.
class _Forbidden extends FakeEmeHttp {
  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> query = const {},
    EmeAuth auth = EmeAuth.token,
  }) async =>
      throw EmeHttpException(uri: Uri.parse(path), statusCode: 403);
}

Future<(FakeEmeHttp, ConsoleNav)> _pump(
  WidgetTester tester, {
  Map<String, dynamic>? canned,
  FakeEmeHttp? http,
  double width = 1440,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final client = http ?? FakeEmeHttp();
  if (canned != null) client.canned[_path] = canned;
  final filters = AnalyticsFilters();
  final nav = ConsoleNav(const ConsoleRoute('person', entityId: 'u1'));
  addTearDown(filters.dispose);
  addTearDown(nav.dispose);

  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: ListView(children: [
        AdminPerson(
          api: AdminApi(http: client),
          me: _me,
          filters: filters,
          nav: nav,
          userId: 'u1',
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  return (client, nav);
}

void main() {
  testWidgets('the header names the person and the topic rows carry the '
      "app's own pill", (tester) async {
    await _pump(tester, canned: _canned());

    // person.json sends a flat `name`, not firstName/lastName.
    expect(find.text('Ana Quispe'), findsOneWidget);
    // The app's dashboard wording, verbatim -- console and app must never
    // call the same level two different things.
    expect(find.text('Competent · Review soon'), findsOneWidget);
    expect(find.text('Beginner · Needs practice'), findsWidgets);
    expect(find.text('5 of 8 questions · review Debida diligencia'),
        findsOneWidget);
    // No weakest section for the second topic: the clause is dropped, not
    // printed with a null.
    expect(find.text('1 of 4 questions'), findsOneWidget);
  });

  testWidgets('the usage and Iris lines read as sentences', (tester) async {
    await _pump(tester, canned: _canned());

    expect(find.text('4 sessions · 37 min · 3 active days'), findsOneWidget);
    expect(
      find.text('6 questions to Iris · about Debida diligencia · 50% helpful'),
      findsOneWidget,
    );
  });

  testWidgets('a person who never asked Iris gets no Iris line', (tester) async {
    await _pump(tester, canned: _canned(iris: {'questions': 0}));

    expect(find.textContaining('questions to Iris'), findsNothing);
  });

  testWidgets('the subtopic table lists every row', (tester) async {
    await _pump(tester, canned: _canned());

    expect(find.byType(AdminTable<MasteryRow>), findsOneWidget);
    expect(find.text('Debida diligencia'), findsWidgets);
    expect(find.text('Phishing'), findsWidgets);
    expect(find.text('5/8/10'), findsOneWidget);
  });

  testWidgets('a 403 says the person is outside your scope', (tester) async {
    await _pump(tester, http: _Forbidden());

    expect(find.byType(ConsolePanelError), findsOneWidget);
    expect(find.text('Outside your scope.'), findsOneWidget);
  });

  // 1024 px of window minus the 220 px nav and the 24 px gutters is the
  // narrowest content column the console supports, and Spanish is the
  // shipping language. Any overflow fails the test on its own.
  testWidgets('the Spanish page fits its narrowest supported column',
      (tester) async {
    testuLang.value = 'es';
    addTearDown(() => testuLang.value = 'en');

    await _pump(tester, canned: _canned(), width: 756);

    expect(find.text('Competente · Repasar pronto'), findsOneWidget);
    expect(find.text('4 sesiones · 37 min · 3 días activos'), findsOneWidget);
  });
}
