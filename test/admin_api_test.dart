import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';

void main() {
  late FakeEmeHttp http;
  late AdminApi api;
  setUp(() {
    http = FakeEmeHttp();
    api = AdminApi(http: http);
  });

  test('me parses role, permissions and enabled modules', () async {
    http.canned['services/testu/personas/me.json'] = {
      'user': {'id': 'a@b.c', 'email': 'a@b.c', 'firstName': 'A', 'lastName': 'B'},
      'role': 'manager',
      'permissions': ['personas_view', 'analytics_view'],
      'modules': [
        {'id': 'personas', 'name': 'Personas', 'surfaces': ['web'], 'enabled': true},
        {'id': 'agentes', 'name': 'Agentes', 'surfaces': ['web'], 'enabled': false},
      ],
    };
    final me = await api.me();
    expect(me.role, 'manager');
    expect(me.can('analytics_view'), isTrue);
    expect(me.can('personas_operate'), isFalse);
    expect(me.webModules.map((m) => m.id), ['personas']);
  });

  test('report parses rows and summary', () async {
    http.canned['services/testu/analytics/report.json'] = {
      'rows': [
        {
          'user': 'u',
          'name': 'U',
          'team': 't',
          'entitytopic': 'T1',
          'topic': 'DDHH',
          'componentsection': 's',
          'section': 'Intro',
          'questions': 10,
          'answered': 4,
          'mastered': 3,
          'attempts': 5,
          'correct': 3,
          'level': 'competent',
          'lastactivity': '2026-09-06T10:00:00',
        },
      ],
      'summary': {
        'activeusers7d': 1,
        'answers7d': 5,
        'levels': {'beginner': 0, 'competent': 1, 'expert': 0},
      },
      'topics': [
        {'id': 'T1', 'name': 'DDHH'},
      ],
    };
    final r = await api.report(topic: 'T1');
    expect(r.rows.single.level, 'competent');
    expect(r.summary.activeUsers7d, 1);
    // FakeEmeHttp records (path, query) for getJson -- the query filter
    // rides the `query` map, not the path string, so it's checked on the
    // recorded map rather than as a literal 'entitytopic=T1' substring.
    expect(http.requests.single.$1, 'services/testu/analytics/report.json');
    expect(http.requests.single.$2, containsPair('entitytopic', 'T1'));
  });

  test('createUser posts form fields', () async {
    http.canned['services/testu/personas/createuser.json'] = {'ok': true, 'id': 'x@y.z'};
    await api.createUser(email: 'X@y.z', firstName: 'X', lastName: 'Y', team: 'norte', role: 'users');
    expect(http.requests.single.$1, 'services/testu/personas/createuser.json');
  });

  test('overview parses series, levels, topics, calibration, teams, gaps, iris', () async {
    http.canned['services/testu/analytics/overview.json'] = {
      'cohort': {'total': 10, 'activated': 8, 'active7d': 5, 'active30d': 7},
      'series': [
        {
          'day': '2026-09-01',
          'people': 3,
          'answers': 10,
          'minutes': 20,
          'sessions': 2,
          'certainwrong': 1,
          'questions': 12,
        },
        {
          'day': '2026-09-02',
          'people': 4,
          'answers': 15,
          'minutes': 25,
          'sessions': 3,
          'certainwrong': 2,
          'questions': 16,
        },
      ],
      'levels': {'notstarted': 1, 'beginner': 2, 'competent': 3, 'expert': 4},
      'topics': [
        {
          'id': 'T1',
          'name': 'DDHH',
          'people': 5,
          'levels': {'notstarted': 0, 'beginner': 1, 'competent': 2, 'expert': 2},
          'weakest': {'section': 's1', 'name': 'Intro', 'beginners': 3},
        },
      ],
      'calibration': {'cc': 6, 'cu': 1, 'ic': 2, 'iu': 1},
      'teams': [
        {'id': '', 'name': '', 'members': 2, 'activated': 1, 'active7d': 1, 'levels': {}},
        {
          'id': 'norte',
          'name': 'Norte',
          'members': 8,
          'activated': 7,
          'active7d': 4,
          'levels': {'expert': 1},
          'weakest': 'Intro',
        },
      ],
      'median': null,
      'previous': {'answers': 50},
      'gaps': [
        {
          'section': 's1',
          'name': 'Intro',
          'topic': 'DDHH',
          'topicId': 'T1',
          'score': 0.42,
          'beginners': 3,
          'questions': 12,
          'misconceptions': 2,
          'unanswered': 1,
          'people': 5,
          'levels': {},
          'helpfulShare': 0.5,
        },
      ],
      'iris': {
        'questions': 20,
        'people': 6,
        'citedShare': 0.8,
        'ratedShare': null,
        'helpfulShare': 0.9,
        'themes': [
          {'theme': 'privacidad', 'count': 4},
        ],
        'sections': [
          {'section': 's1', 'name': 'Intro', 'questions': 5, 'helpfulShare': 0.6},
        ],
        'labels': [
          {'label': 'confuso', 'count': 2},
        ],
      },
    };

    final ov = await api.overview({'from': '2026-09-01', 'to': '2026-09-02'});

    expect(ov.cohort.total, 10);
    expect(ov.series.length, 2);
    expect(ov.series[1].questions, 16);
    expect(ov.levels.total, 10);
    expect(ov.levels.asMap['expert'], 4);
    expect(ov.topics.single.weakest!.beginners, 3);
    expect(ov.calibration.calibrated, (6 + 2) / 10);
    expect(ov.teams.map((t) => t.id), containsAll(['', 'norte']));
    expect(ov.teams.firstWhere((t) => t.id == 'norte').weakest, 'Intro');
    expect(ov.median, isNull);
    expect(ov.previous['answers'], 50);
    expect(ov.gaps.single.topicId, 'T1');
    expect(ov.iris.themes['privacidad'], 4);
    expect(ov.iris.labels.single, ('confuso', 2));
    expect(ov.iris.ratedShare, isNull);
  });

  test('activity parses hours triples, funnel and inactive lastactivity', () async {
    http.canned['services/testu/analytics/activity.json'] = {
      'series': [
        {'day': '2026-09-01', 'people': 2, 'correct': 5},
      ],
      'funnel': {'cohort': 10, 'signedin': 8, 'answered': 6, 'active7d': 5, 'active30d': 7},
      'hours': [
        [0, 9, 3],
        [2, 14, 1],
      ],
      'inactive': [
        {'user': 'u1', 'name': 'U1', 'team': 'norte', 'lastactivity': '2026-08-01T10:00:00Z'},
        {'user': 'u2', 'name': 'U2', 'team': null, 'lastactivity': null},
      ],
      'iris': {
        'questions': 1,
        'people': 1,
        'citedShare': null,
        'ratedShare': null,
        'helpfulShare': null,
        'themes': [],
        'sections': [],
        'labels': [],
      },
    };

    final act = await api.activity({'from': '2026-08-01', 'to': '2026-09-01'});

    expect(act.series.single.correct, 5);
    expect(act.funnel['cohort'], 10);
    expect(act.hours.first, (0, 9, 3));
    expect(act.inactive[0].lastActivity, isNotNull);
    expect(act.inactive[1].lastActivity, isNull);
  });

  test('person parses raw lastlogin, extended mastery counters, usage and iris', () async {
    http.canned['services/testu/analytics/person.json'] = {
      'user': {
        'id': 'u1',
        'email': 'u1@x.com',
        'firstName': 'U',
        'lastName': 'One',
        'team': 'norte',
        'role': 'gA',
        'enabled': true,
        'lastlogin': '2026-09-06 22:55:49 -0300',
      },
      'rows': [
        {
          'user': 'u1',
          'name': 'U1',
          'entitytopic': 'T1',
          'topic': 'DDHH',
          'componentsection': 's1',
          'section': 'Intro',
          'questions': 10,
          'answered': 5,
          'mastered': 3,
          'attempts': 5,
          'correct': 4,
          'level': 'competent',
          'lastactivity': '2026-09-05T10:00:00',
          'certaincorrect': 2,
          'certainwrong': 1,
          'unsurecorrect': 1,
          'unsurewrong': 1,
        },
      ],
      'series': [
        {'day': '2026-09-01', 'answers': 4, 'correct': 3},
      ],
      'calibration': {'cc': 2, 'cu': 1, 'ic': 1, 'iu': 1},
      'topics': [
        {'id': 'T1', 'name': 'DDHH', 'level': 'competent', 'mastered': 3, 'answered': 5, 'weakest': 'Intro'},
      ],
      'usage': {'sessions': 4, 'minutes': 60, 'activeDays': 3},
      'iris': {
        'questions': 5,
        'sections': [
          {'section': 's1', 'name': 'Intro', 'questions': 2, 'helpfulShare': 0.5},
        ],
        'helpfulShare': 0.7,
      },
    };

    final pr = await api.person('u1', {'from': '2026-09-01', 'to': '2026-09-06'});

    expect(pr.user.lastlogin, '2026-09-06 22:55:49 -0300');
    expect(pr.rows.single.certainWrong, 1);
    expect(pr.rows.single.unsureCorrect, 1);
    expect(pr.sessions, 4);
    expect(pr.minutes, 60);
    expect(pr.activeDays, 3);
    expect(pr.irisQuestions, 5);
    expect(pr.irisSections.single.helpfulShare, 0.5);
    expect(pr.irisHelpfulShare, 0.7);
    expect(pr.topics.single.weakest, 'Intro');
    expect(http.requests.single.$2, containsPair('user', 'u1'));
  });

  test('ask parses answer, followups and JSON-encodes a map citation value', () async {
    http.canned['services/testu/analytics/ask.json'] = {
      'ok': true,
      'answer': 'La respuesta es...',
      'citations': [
        {'id': 'c1', 'label': 'Reporte', 'value': 42, 'view': 'report', 'filters': {'from': '2026-09-01'}},
        {'id': 'c2', 'label': 'Detalle', 'value': {'a': 1, 'b': 2}, 'view': 'gap', 'filters': {}},
      ],
      'followups': ['¿Y el equipo Norte?'],
      'model': 'gpt',
    };

    final reply = await api.ask(question: '¿Cuántos activos?', screen: 'overview');

    expect(reply.answer, 'La respuesta es...');
    expect(reply.citations[0].value, '42');
    expect(reply.citations[1].value, '{"a":1,"b":2}');
    expect(reply.followups.single, '¿Y el equipo Norte?');
    expect(http.posted.single.fields['question'], '¿Cuántos activos?');
    expect(http.posted.single.fields['history'], '[]');
  });

  test('ask throws AskUnavailable on {ok:false, error:llm}', () async {
    http.canned['services/testu/analytics/ask.json'] = {'ok': false, 'error': 'llm'};

    expect(
      () => api.ask(question: '¿Cuántos activos?', screen: 'overview'),
      throwsA(isA<AskUnavailable>()),
    );
  });
}
