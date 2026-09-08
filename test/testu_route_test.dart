import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_route.dart';

/// The learner web address grammar (spec: minsur-pilot-readiness E2). Pure
/// Dart: no widget tree.
void main() {
  const routes = <String, LearnerRoute>{
    '/hoy': LearnerRoute(0),
    '/temas': LearnerRoute(1),
    '/temas/t1': LearnerRoute(1, topicId: 't1'),
    '/iris': LearnerRoute(2),
    '/dashboard': LearnerRoute(3),
    '/temas/t1?q=q9': LearnerRoute(1, topicId: 't1', questionId: 'q9'),
    '/temas/t1?q=q9&c=m3': LearnerRoute(1,
        topicId: 't1', questionId: 'q9', messageId: 'm3'),
  };

  test('every route survives toUri and fromUri', () {
    for (final e in routes.entries) {
      expect(e.value.toUri().toString(), e.key);
      expect(LearnerRoute.fromUri(Uri.parse(e.key)), e.value, reason: e.key);
      expect(LearnerRoute.fromUri(e.value.toUri()), e.value, reason: e.key);
    }
  });

  test('reads the hash the browser shows under the learn base href', () {
    expect(
        LearnerRoute.fromUri(Uri.parse(
            'https://minsur.genailabs.tech/site/mediadb/learn/#/temas/t1?q=q9&c=m3')),
        const LearnerRoute(1,
            topicId: 't1', questionId: 'q9', messageId: 'm3'));
    expect(
        LearnerRoute.fromUri(
            Uri.parse('http://localhost:7358/#/dashboard')),
        const LearnerRoute(3));
  });

  test('an address that names no tab is no route', () {
    expect(LearnerRoute.fromUri(Uri.parse('https://x/site/mediadb/learn/')),
        isNull);
    expect(LearnerRoute.fromUri(Uri.parse('https://x/site/mediadb/learn/#/')),
        isNull);
    expect(LearnerRoute.fromUri(Uri.parse('/perfil')), isNull);
    expect(LearnerRoute.fromUri(Uri.parse('file:///Users/x/app/')), isNull);
  });

  test('a topic id only rides on /temas', () {
    expect(LearnerRoute.fromUri(Uri.parse('/iris/t1')), const LearnerRoute(2));
  });
}
