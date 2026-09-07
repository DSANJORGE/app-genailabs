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
    final sent = http.posted.single; // FakeEmeHttp records postForm calls
    final events = sent.fields['events']!;
    expect(events, contains('"type":"open"'));
    expect(events, contains('"type":"pause"'));
    expect(events, contains('"seconds":'));
    expect(await u.pending(), 0);
  });
  test('a failed flush keeps the queue', () async {
    final http = FakeEmeHttp(); // no canned reply -> throws
    final u = TestuUsage(http: http, platform: 'test', appVersion: '1.1.1+6');
    await u.rate(channel: 'c', sectionId: 's', questionId: 'q', helpful: true);
    await u.flush();
    expect(await u.pending(), 1);
  });
}
