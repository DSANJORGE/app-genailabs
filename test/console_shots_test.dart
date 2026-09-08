@Tags(['shots'])
library;

import 'package:eme_app_package/eme_http.dart' show EmeAuth;
import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_shell.dart';
import 'package:genai_labs/admin/admin_signin.dart';
import 'package:genai_labs/testu/testu_i18n.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:genai_labs/testu/testu_widgets.dart';

/// Screenshot rig, not a regression suite: renders every console screen at
/// 1280x800 and 1024x768 in Spanish, with the real fonts and a canned server,
/// and writes PNGs to test/console_shots/. That is how the console gets
/// eyeballed against the spec wireframes without a browser. Skipped in normal
/// runs (dart_test.yaml tag); capture with:
///   flutter test --update-goldens --run-skipped --tags shots test/console_shots_test.dart
///
/// The fixtures are the Task 11-16 canned replies, widened into one coherent
/// cohort (24 people, 3 teams, 2 topics) so every screen tells the same story.

// ---------------------------------------------------------------- endpoints

const _overviewPath = 'services/testu/analytics/overview.json';
const _activityPath = 'services/testu/analytics/activity.json';
const _reportPath = 'services/testu/analytics/report.json';
const _personPath = 'services/testu/analytics/person.json';
const _usersPath = 'services/testu/personas/users.json';
const _teamsPath = 'services/testu/personas/teams.json';
const _askPath = 'services/testu/analytics/ask.json';

/// Every console verb plus the tutor persona: the rig renders what a training
/// lead at Minsur sees, which is the whole console.
final _me = AdminMe(
  'u-diego',
  'diego@minsur.test',
  'Diego San Jorge',
  'training',
  const {
    'analytics_view',
    'analytics_operate',
    'personas_view',
    'personas_operate',
    'personas_manage',
  },
  [
    SuiteModule('analytics', 'Analytics', const ['web'], true),
    SuiteModule('personas', 'Personas', const ['web'], true),
  ],
  persona: AdminPersona('Iris', organization: 'Minsur'),
);

// ----------------------------------------------------------------- fixtures

const _people = [7, 11, 9, 14, 8, 12, 10];
const _answers = [96, 168, 121, 204, 88, 175, 142];
const _minutes = [212, 340, 266, 411, 190, 372, 301];

Map<String, dynamic> _day(int i) => {
      'day': '2026-09-0${i + 1}',
      'people': _people[i],
      'answers': _answers[i],
      'minutes': _minutes[i],
      'sessions': 6 + (i * 3) % 7,
      'certainwrong': [1, 4, 2, 5, 1, 3, 2][i],
      'questions': [4, 9, 6, 11, 3, 7, 5][i],
    };

Map<String, dynamic> _gap(String section, String name, String topicId,
        String topic, int beginners, int questions, int misconceptions,
        int unanswered) =>
    {
      'section': section,
      'name': name,
      'topic': topic,
      'topicId': topicId,
      'score': 0.9,
      'people': 20,
      'levels': {
        'notstarted': 2,
        'beginner': beginners,
        'competent': 8,
        'expert': 4,
      },
      'beginners': beginners,
      'questions': questions,
      'misconceptions': misconceptions,
      'unanswered': unanswered,
    };

Map<String, dynamic> _overviewJson() => {
      'ok': true,
      'cohort': {'total': 24, 'activated': 20, 'active7d': 12, 'active30d': 20},
      'series': [for (var i = 0; i < 7; i++) _day(i)],
      'previousSeries': [
        for (var i = 0; i < 7; i++)
          {
            'day': '2026-08-2${i + 1}',
            'people': [4, 6, 5, 9, 4, 7, 8][i],
            'answers': [58, 92, 71, 130, 60, 104, 118][i],
            'minutes': [110, 180, 140, 240, 120, 200, 220][i],
            'certainwrong': 1,
            'questions': [2, 3, 1, 4, 2, 3, 3][i],
          },
      ],
      'levels': {'notstarted': 4, 'beginner': 6, 'competent': 9, 'expert': 5},
      'topics': [
        {
          'id': 't1',
          'name': 'Derechos Humanos',
          'people': 20,
          'levels': {'notstarted': 2, 'beginner': 6, 'competent': 8, 'expert': 4},
          'weakest': {'section': 's2', 'name': 'Debida diligencia', 'beginners': 6},
        },
        {
          'id': 't2',
          'name': 'Ciberseguridad',
          'people': 18,
          'levels': {'notstarted': 4, 'beginner': 8, 'competent': 6, 'expert': 2},
          'weakest': {'section': 'c2', 'name': 'Phishing', 'beginners': 8},
        },
      ],
      'calibration': {'cc': 612, 'cu': 240, 'ic': 333, 'iu': 99},
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
        {
          'id': 'team-mant',
          'name': 'Mantenimiento',
          'members': 8,
          'activated': 5,
          'active7d': 3,
          'levels': {'notstarted': 3, 'beginner': 3, 'competent': 2},
          'weakest': 'Derechos Humanos',
        },
        {
          'id': 'team-lima',
          'name': 'Administración Lima',
          'members': 7,
          'activated': 7,
          'active7d': 3,
          'levels': {'beginner': 1, 'competent': 3, 'expert': 3},
          'weakest': 'Ciberseguridad',
        },
        {
          'id': '',
          'name': '',
          'members': 3,
          'activated': 1,
          'active7d': 0,
          'levels': {'notstarted': 2, 'beginner': 1},
        },
      ],
      'median': {'activeShare': 0.48, 'expertShare': 0.2},
      'previous': {
        'active7d': 9,
        'answers': 500,
        'minutes': 900,
        'certainwrong': 3,
        'questions': 8,
      },
      'gaps': [
        _gap('c2', 'Phishing', 't2', 'Ciberseguridad', 8, 14, 5, 3),
        _gap('s2', 'Debida diligencia', 't1', 'Derechos Humanos', 6, 11, 3, 2),
        _gap('c10', 'Datos personales', 't2', 'Ciberseguridad', 5, 7, 2, 4),
        _gap('s3', 'Canales de denuncia', 't1', 'Derechos Humanos', 4, 6, 1, 1),
        _gap('c1', 'Contraseñas', 't2', 'Ciberseguridad', 3, 4, 1, 0),
      ],
      'iris': {'questions': 42, 'people': 9},
    };

/// The same window scoped to one team: the fake keys on the path alone, so
/// without this the Equipo shot would show org totals under a team's name.
Map<String, dynamic> _teamOverviewJson() => {
      'ok': true,
      'cohort': {'total': 9, 'activated': 8, 'active7d': 6, 'active30d': 8},
      'series': [
        for (var i = 0; i < 7; i++)
          {
            'day': '2026-09-0${i + 1}',
            'people': [3, 5, 4, 6, 2, 5, 4][i],
            'answers': [22, 41, 30, 52, 18, 44, 35][i],
            'minutes': [48, 90, 66, 112, 40, 95, 74][i],
            'certainwrong': i % 2,
            'questions': [1, 3, 2, 4, 1, 2, 2][i],
          },
      ],
      'levels': {'notstarted': 1, 'beginner': 2, 'competent': 4, 'expert': 2},
      'topics': const [],
      'calibration': {'cc': 180, 'cu': 60, 'ic': 90, 'iu': 21},
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
      'previous': {'active7d': 4},
      'gaps': const [],
      'iris': {
        'questions': 12,
        'people': 4,
        'sections': [
          {'section': 'c2', 'name': '2. Phishing', 'questions': 7},
          {'section': 's2', 'name': '2. Debida diligencia', 'questions': 5},
        ],
      },
    };

Map<String, dynamic> _activityJson() => {
      'ok': true,
      'series': [
        for (var i = 0; i < 7; i++) {..._day(i), 'minutes': 0, 'sessions': 0},
      ],
      'funnel': {
        'cohort': 24,
        'signedin': 19,
        'answered': 17,
        'active7d': 12,
        'active30d': 20,
      },
      'hours': [
        for (var wd = 0; wd < 5; wd++)
          for (final h in const [8, 9, 10, 12, 14, 15, 18, 20])
            [wd, h, 1 + (wd * 7 + h) % 11],
        [5, 10, 4],
        [6, 19, 2],
      ],
      'inactive': [
        {
          'user': 'u-jorge',
          'name': 'Jorge Palomino',
          'team': 'Mantenimiento',
          'lastactivity': '2026-08-29T10:00:00Z',
        },
        {
          'user': 'u-maria',
          'name': 'María Torres',
          'team': 'Mantenimiento',
          'lastactivity': '2026-08-27T10:00:00Z',
        },
        {
          'user': 'u-carlos',
          'name': 'Carlos Mendoza',
          'team': 'Administración Lima',
          'lastactivity': '2026-08-25T09:00:00Z',
        },
        {'user': 'u-rosa', 'name': 'Rosa Cárdenas', 'team': 'Operaciones Pisco'},
      ],
      'iris': {
        'questions': 42,
        'people': 9,
        'citedShare': 0.81,
        'ratedShare': 0.52,
        'helpfulShare': 0.75,
        'themes': [
          {'theme': 'concept', 'count': 18},
          {'theme': 'procedure', 'count': 11},
          {'theme': 'example', 'count': 5},
          {'theme': 'source', 'count': 3},
          {'theme': 'offtopic', 'count': 2},
          {'theme': 'other', 'count': 3},
        ],
        'sections': [
          {'section': 'c2', 'name': '2. Phishing', 'questions': 18, 'helpfulShare': 0.8},
          {'section': 's2', 'name': '2. Debida diligencia', 'questions': 11, 'helpfulShare': 0.6},
          {'section': 'c10', 'name': '10. Datos personales', 'questions': 7},
          {'section': 's1', 'name': '1. Principios', 'questions': 6, 'helpfulShare': 1.0},
        ],
        'labels': [
          {'label': 'correo sospechoso', 'count': 9},
          {'label': 'contraseñas seguras', 'count': 6},
          {'label': 'denunciar a un proveedor', 'count': 4},
          {'label': 'datos de terceros', 'count': 3},
        ],
      },
    };

Map<String, Object?> _row(
  String user,
  String name,
  String team,
  String topicId,
  String topic,
  String section,
  String title, {
  int questions = 6,
  int answered = 5,
  int mastered = 3,
  int attempts = 8,
}) =>
    {
      'user': user,
      'name': name,
      'team': team,
      'entitytopic': topicId,
      'topic': topic,
      'componentsection': section,
      'section': title,
      'questions': questions,
      'answered': answered,
      'mastered': mastered,
      'attempts': attempts,
      'correct': mastered,
      'certaincorrect': mastered,
      'certainwrong': 2,
      'unsurecorrect': 1,
      'unsurewrong': 1,
      'lastactivity': '2026-09-0${1 + user.length % 5}T10:00:00Z',
      'computedat': '2026-09-07T06:00:00Z',
    };

/// Six people over two topics and six subtopics: enough grid for the tints to
/// read as a shape, small enough to fit a laptop viewport.
List<Map<String, Object?>> _reportRows() {
  const people = [
    ('u-ana', 'Ana Quispe', 'team-pisco'),
    ('u-luis', 'Luis Huamán', 'team-pisco'),
    ('u-jorge', 'Jorge Palomino', 'team-mant'),
    ('u-maria', 'María Torres', 'team-mant'),
    ('u-rosa', 'Rosa Cárdenas', 'team-lima'),
    ('u-carlos', 'Carlos Mendoza', 'team-lima'),
  ];
  const sections = [
    ('t1', 'Derechos Humanos', 's1', '1. Principios'),
    ('t1', 'Derechos Humanos', 's2', '2. Debida diligencia'),
    ('t1', 'Derechos Humanos', 's3', '3. Canales de denuncia'),
    ('t2', 'Ciberseguridad', 'c1', '1. Contraseñas'),
    ('t2', 'Ciberseguridad', 'c2', '2. Phishing'),
    ('t2', 'Ciberseguridad', 'c10', '10. Datos personales'),
  ];
  final out = <Map<String, Object?>>[];
  for (var p = 0; p < people.length; p++) {
    for (var s = 0; s < sections.length; s++) {
      // A couple of holes, so "never touched" reads as a hole rather than a
      // zero, and a spread of levels across the grid.
      if ((p + s) % 7 == 3) continue;
      final answered = 4 + (p + s) % 3;
      final mastered =
          [0, 1, 2, 3, 4, 5, 6][(p * 3 + s * 2) % 7].clamp(0, answered);
      out.add(_row(
        people[p].$1,
        people[p].$2,
        people[p].$3,
        sections[s].$1,
        sections[s].$2,
        sections[s].$3,
        sections[s].$4,
        answered: answered,
        mastered: mastered,
        attempts: answered + 3,
      ));
    }
  }
  return out;
}

Map<String, dynamic> _reportJson() => {
      'rows': _reportRows(),
      'summary': {'activeusers7d': 12, 'answers7d': 910, 'levels': {}},
      'topics': [
        {'id': 't1', 'name': 'Derechos Humanos'},
        {'id': 't2', 'name': 'Ciberseguridad'},
      ],
    };

Map<String, dynamic> _personJson() => {
      'ok': true,
      'user': {
        'id': 'u-ana',
        'name': 'Ana Quispe',
        'team': 'team-pisco',
        'role': 'users',
        'enabled': true,
        'lastlogin': '2026-09-06 22:55:49 -0300',
      },
      'rows': [
        for (final r in _reportRows())
          if (r['user'] == 'u-ana') r,
      ],
      'series': [
        for (var i = 0; i < 21; i++)
          {
            'day': '2026-08-${(18 + i).toString().padLeft(2, '0')}',
            'answers': i % 5 == 0 ? 0 : 3 + i % 6,
            'correct': i % 5 == 0 ? 0 : 1 + i % 4,
            'minutes': 6 + i % 9,
            'sessions': 1,
            'questions': i % 3,
          },
      ],
      'calibration': {'cc': 41, 'cu': 12, 'ic': 9, 'iu': 6},
      'topics': [
        {
          'id': 't1',
          'name': 'Derechos Humanos',
          'level': 'competent',
          'mastered': 8,
          'answered': 13,
          'weakest': '2. Debida diligencia',
        },
        {
          'id': 't2',
          'name': 'Ciberseguridad',
          'level': 'beginner',
          'mastered': 3,
          'answered': 10,
          'weakest': '2. Phishing',
        },
      ],
      'usage': {'sessions': 14, 'minutes': 137, 'activeDays': 9},
      'iris': {
        'questions': 12,
        'sections': [
          {'section': 'c2', 'name': '2. Phishing', 'questions': 7},
          {'section': 's2', 'name': '2. Debida diligencia', 'questions': 5},
        ],
        'helpfulShare': 0.8,
      },
    };

Map<String, dynamic> _usersJson() => {
      'users': [
        for (final (id, first, last, team, role, active) in const [
          ('u-ana', 'Ana', 'Quispe', 'team-pisco', 'users', '2026-09-06'),
          ('u-luis', 'Luis', 'Huamán', 'team-pisco', 'users', '2026-09-05'),
          ('u-rosa', 'Rosa', 'Cárdenas', 'team-lima', 'manager', ''),
          ('u-jorge', 'Jorge', 'Palomino', 'team-mant', 'users', '2026-08-29'),
          ('u-maria', 'María', 'Torres', 'team-mant', 'users', '2026-08-27'),
          ('u-carlos', 'Carlos', 'Mendoza', 'team-lima', 'users', '2026-08-25'),
          ('u-diego', 'Diego', 'San Jorge', 'team-lima', 'training', '2026-09-07'),
          ('u-pilar', 'Pilar', 'Villanueva', '', 'orgadmin', '2026-09-04'),
        ])
          {
            'id': id,
            'email': '${first.toLowerCase()}@minsur.test',
            'firstName': first,
            'lastName': last,
            'team': team,
            'role': role,
            'enabled': id != 'u-carlos',
            if (active.isNotEmpty) 'lastactivity': '${active}T10:00:00Z',
          },
      ],
    };

Map<String, dynamic> _teamsJson() => {
      'teams': [
        {
          'id': 'team-pisco',
          'name': 'Operaciones Pisco',
          'parent': 'team-peru',
          'manager': 'u-rosa',
          'location': 'Pisco',
          'costcenter': 'CC-1042',
          'members': 9,
        },
        {
          'id': 'team-mant',
          'name': 'Mantenimiento',
          'parent': 'team-peru',
          'location': 'Pisco',
          'costcenter': 'CC-1043',
          'members': 8,
        },
        {
          'id': 'team-lima',
          'name': 'Administración Lima',
          'parent': 'team-peru',
          'manager': 'u-rosa',
          'location': 'Lima',
          'costcenter': 'CC-2001',
          'members': 7,
        },
        {'id': 'team-peru', 'name': 'Perú', 'members': 24},
      ],
    };

Map<String, dynamic> _askJson() => {
      'ok': true,
      'answer': 'Tres personas destacan esta semana. **Jorge Palomino** '
          '(Mantenimiento) está en Principiante en los dos temas y lleva 9 '
          'días sin entrar [f1]. Mantenimiento es además el equipo con menos '
          'personas activas: 3 de 8 [f2]. Empezaría por ahí.',
      'citations': [
        {
          'id': 'f1',
          'label': 'Sin actividad · Jorge Palomino',
          'value': 'última actividad 2026-08-29',
          'view': 'activity',
          'focus': 'inactive',
          'filters': {'period': 'd7'},
        },
        {
          'id': 'f2',
          'label': 'Resumen · Equipos · Activos 7 d',
          'value': '3 de 8',
          'view': 'overview',
          'focus': 'stat',
          'filters': {'period': 'd7', 'team': 'team-mant'},
        },
      ],
      'followups': [
        '¿Qué le recomiendo a Jorge?',
        '¿Qué otros conceptos erróneos hay?',
      ],
    };

/// The canned server. [FakeEmeHttp] keys on the path and ignores the query,
/// so the team-scoped overview is answered here instead.
class _ShotHttp extends FakeEmeHttp {
  _ShotHttp() {
    canned[_overviewPath] = _overviewJson();
    canned[_activityPath] = _activityJson();
    canned[_reportPath] = _reportJson();
    canned[_personPath] = _personJson();
    canned[_usersPath] = _usersJson();
    canned[_teamsPath] = _teamsJson();
    canned[_askPath] = _askJson();
  }

  final _teamOverview = _teamOverviewJson();

  @override
  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String> query = const {},
    EmeAuth auth = EmeAuth.token,
  }) async {
    if (path == _overviewPath && (query['team'] ?? '').isNotEmpty) {
      requests.add((path, query));
      return _teamOverview;
    }
    return super.getJson(path, query: query, auth: auth);
  }
}

// --------------------------------------------------------------------- rig

/// The three shipped families, and nothing else.
///
/// The rig deliberately has no fallback font: a glyph that is missing here is
/// a glyph the console is asking a system font to supply, and the PNGs are
/// where that has to be visible. (Task 17 saw `▾ ▲ ✕ ↓` as empty boxes;
/// `▲ ↓` turned out to be in Geist after all, and `▾ ✕` were swapped for the
/// `▼ ×` the shipped fonts do carry.)
Future<void> _loadFonts() async {
  const fonts = {
    'Sora': ['Sora-Regular.ttf', 'Sora-Bold.ttf', 'Sora-ExtraBold.ttf'],
    'Geist': [
      'Geist-Regular.ttf',
      'Geist-Medium.ttf',
      'Geist-SemiBold.ttf',
      'Geist-Bold.ttf',
    ],
    'GeistMono': ['GeistMono-Regular.ttf', 'GeistMono-Medium.ttf'],
  };
  for (final e in fonts.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await _loadFonts();
    // Spanish is the shipping language and the longer one: the PNGs are for
    // judging the layout that actually ships.
    testuLang.value = 'es';
  });
  tearDownAll(() => testuLang.value = 'en');

  /// The two supported laptop viewports, and one tall render per screen.
  /// `full` is not a window anybody has -- it is the whole page in one image,
  /// which is the only way to look at what sits below the fold.
  const sizes = [
    ('1280', Size(1280, 800), true),
    ('1024', Size(1024, 768), true),
    ('full', Size(1280, 2400), false),
  ];

  Future<void> shot(WidgetTester tester, String name) => expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('console_shots/$name.png'));

  Future<_ShotHttp> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final http = _ShotHttp();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: testuTheme(),
      home: AdminShell(me: _me, api: AdminApi(http: http), onSignOut: () {}),
    ));
    await tester.pumpAndSettle();
    return http;
  }

  Future<void> open(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();
  }

  for (final (tag, size, viewport) in sizes) {
    testWidgets('resumen $tag', (tester) async {
      await pumpShell(tester, size);
      await shot(tester, 'resumen_$tag');
    });

    testWidgets('actividad $tag', (tester) async {
      await pumpShell(tester, size);
      await open(tester, 'Actividad');
      await shot(tester, 'actividad_$tag');
    });

    testWidgets('dominio $tag', (tester) async {
      await pumpShell(tester, size);
      await open(tester, 'Dominio');
      await shot(tester, 'dominio_$tag');
    });

    testWidgets('colaboradores $tag', (tester) async {
      await pumpShell(tester, size);
      await open(tester, 'Colaboradores');
      await shot(tester, 'colaboradores_$tag');
    });

    testWidgets('equipos $tag', (tester) async {
      await pumpShell(tester, size);
      await open(tester, 'Equipos');
      await shot(tester, 'equipos_$tag');
    });

    testWidgets('persona $tag', (tester) async {
      await pumpShell(tester, size);
      await open(tester, 'Colaboradores');
      await open(tester, 'Ana Quispe');
      await shot(tester, 'persona_$tag');
    });

    testWidgets('equipo $tag', (tester) async {
      await pumpShell(tester, size);
      // Resumen's teams table is below the fold at 800 px; Equipos puts the
      // same drill-down at the top of the page.
      await open(tester, 'Equipos');
      await open(tester, 'Operaciones Pisco');
      await shot(tester, 'equipo_$tag');
    });

    testWidgets('resumen with the Iris panel $tag', (tester) async {
      await pumpShell(tester, size);
      await tester.tap(find.widgetWithText(TestuPressable, 'Iris'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byType(TextField), '¿Quién necesita ayuda esta semana?');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();
      await shot(tester, 'iris_$tag');
    });

    // The sign-in screen is one card in the middle of the window: a tall
    // render says nothing a viewport render does not.
    if (!viewport) continue;

    testWidgets('sign-in $tag', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: testuTheme(),
        home: AdminSignin(
          onSignedIn: () {},
          sendCode: (_) async => 'ok',
          login: (_, _) async => true,
        ),
      ));
      await tester.pumpAndSettle();
      await shot(tester, 'signin_email_$tag');

      await tester.enterText(find.byType(TextField), 'diego@minsur.test');
      await tester.tap(find.text('Enviar código'));
      // Not pumpAndSettle: the resend cooldown ticks for 30 s, and the shot
      // is of the state a reader lands on, countdown and all.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await shot(tester, 'signin_code_$tag');
      // Let the cooldown run out, so no timer outlives the test.
      await tester.pump(const Duration(seconds: 31));
    });
  }
}
