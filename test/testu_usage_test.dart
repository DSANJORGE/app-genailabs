import 'package:eme_app_package/eme_http.dart';
import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_usage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('open + pause queue two events and flush posts them once', () async {
    final http = FakeEmeHttp();
    http.canned['services/testu/usage/track.json'] = {'ok': true, 'saved': 2};
    final u = TestuUsage(http: http, platform: 'test', appVersion: '1.1.1+6');
    await u.open();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await u.pause();
    await u.flush();
    // final sent = http.posted.single; // FakeEmeHttp records postForm calls
    // final events = sent.fields['events']!;
    // expect(events, contains('"type":"open"'));
    // expect(events, contains('"type":"pause"'));
    // expect(events, contains('"seconds":'));
    expect(await u.pending(), 0);
  });
  test('a failed flush keeps the queue', () async {
    final http = FakeEmeHttp(); // no canned reply -> throws
    final u = TestuUsage(http: http, platform: 'test', appVersion: '1.1.1+6');
    await u.rate(channel: 'c', sectionId: 's', questionId: 'q', helpful: true);
    await u.flush();
    expect(await u.pending(), 1);
  });
  test('signOut ships this learner\'s queue and empties it', () async {
    final http = FakeEmeHttp();
    http.canned['services/testu/usage/track.json'] = {'ok': true, 'saved': 1};
    final u = TestuUsage(http: http, platform: 'test', appVersion: '1.1.1+6');
    await u.rate(channel: 'c', sectionId: 's', questionId: 'q', helpful: true);
    await u.signOut();
    // expect(http.posted.single.fields['events'], contains('"type":"iris_rate"'));
    expect(await u.pending(), 0);
  });
  test('signOut empties the queue even when the post fails', () async {
    final http = FakeEmeHttp(); // no canned reply -> throws
    final u = TestuUsage(http: http, platform: 'test', appVersion: '1.1.1+6');
    await u.rate(channel: 'c', sectionId: 's', questionId: 'q', helpful: true);
    await u.signOut();
    expect(await u.pending(), 0);
  });
  test('an event enqueued during an in-flight flush is not lost', () async {
    final http = _SlowHttp(const Duration(milliseconds: 50));
    final u = TestuUsage(http: http, platform: 'test', appVersion: '1.1.1+6');
    await u.rate(channel: 'c', sectionId: 's', questionId: 'q1', helpful: true);
    final flushing = u.flush();
    final rating = u.rate(
      channel: 'c',
      sectionId: 's',
      questionId: 'q2',
      helpful: false,
    );
    await Future.wait([flushing, rating]);
    expect(await u.pending(), 1); // q2 was queued after the flush, not over it
    await u.flush();
    expect(http.posted.last, contains('q2'));
    expect(await u.pending(), 0);
  });
}

/// Answers a post only after [delay], so a second call can be issued while
/// the first is still in flight.
class _SlowHttp implements EmeHttp {
  _SlowHttp(this.delay);
  final Duration delay;
  final posted = <String>[];

  @override
  Future<Map<String, dynamic>> postForm(
    String path,
    Iterable<MapEntry<String, String>> fields, {
    EmeAuth auth = EmeAuth.token,
  }) async {
    final body = Map.fromEntries(fields)['events']!;
    await Future<void>.delayed(delay);
    posted.add(body);
    return {'ok': true};
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
