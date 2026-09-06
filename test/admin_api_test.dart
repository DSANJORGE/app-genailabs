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
}
