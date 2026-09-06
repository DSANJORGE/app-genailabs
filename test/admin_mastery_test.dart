import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_api.dart';
import 'package:genai_labs/admin/admin_mastery.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/testu/testu_theme.dart';

void main() {
  group('levelOf', () {
    test('0 answered is not started (null)', () {
      expect(levelOf(0, 0), isNull);
    });
    test('4/5 (80%) is competent', () {
      expect(levelOf(4, 5), 'competent');
    });
    test('9/10 (90%) is expert', () {
      expect(levelOf(9, 10), 'expert');
    });
    test('1/5 (20%) is beginner', () {
      expect(levelOf(1, 5), 'beginner');
    });
  });

  testWidgets('Por persona aggregates a user\'s sections within one topic', (tester) async {
    final http = FakeEmeHttp();
    http.canned['services/testu/analytics/report.json'] = {
      'rows': [
        {
          'user': 'diego',
          'name': 'Diego',
          'entitytopic': 't1',
          'topic': 'Derechos Humanos',
          'section': 'Intro',
          'questions': 5,
          'answered': 4,
          'mastered': 1,
          'lastactivity': '2026-09-01T00:00:00Z',
        },
        {
          'user': 'diego',
          'name': 'Diego',
          'entitytopic': 't1',
          'topic': 'Derechos Humanos',
          'section': 'Avanzado',
          'questions': 3,
          'answered': 1,
          'mastered': 0,
        },
      ],
      'summary': {'activeusers7d': 1, 'answers7d': 5, 'levels': {}},
      'topics': [
        {'id': 't1', 'name': 'Derechos Humanos'},
      ],
    };
    http.canned['services/testu/personas/teams.json'] = {'teams': []};
    final api = AdminApi(http: http);
    final me = AdminMe('orgadmin', 'admin@minsur.test', 'Admin', 'orgadmin', {'analytics_view'}, const []);

    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: Scaffold(body: AdminMastery(api: api, me: me)),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Diego'), findsOneWidget);
    // Aggregated across both sections: mastered 1+0=1, answered 4+1=5.
    expect(find.text('1/5'), findsOneWidget);
  });
}
