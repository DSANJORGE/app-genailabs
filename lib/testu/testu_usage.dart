import 'dart:convert';

import 'package:eme_app_package/eme_http.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The version this build reports in every usage event. Kept next to the
/// queue so `main_testu.dart` and the pubspec are the only other places it
/// appears.
const kTestuAppVersion = '1.1.1+6';

/// The app's single usage recorder. Lazily built (top-level finals are), so
/// it costs nothing until the first event and never runs before Dio is up.
final testuUsage = TestuUsage(
  // A browser reports the emulated platform (iOS under Safari); the console
  // wants to tell web sessions apart.
  platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
  appVersion: kTestuAppVersion,
);

/// Foreground-time and tutor-rating events for the console's usage analytics.
/// Queue in shared_preferences, flushed in batches; silent on failure.
/// The server takes the user from the session, so the queue belongs to
/// whoever is signed in: [signOut] ships it and empties it before the
/// credentials go, and nothing is recorded until an [open].
/// ponytail: one JSON list in prefs, dropped past 500 events; a real store if it ever matters.
class TestuUsage {
  TestuUsage({EmeHttp? http, required this.platform, required this.appVersion})
      : _http = http ?? DioEmeHttp();
  final EmeHttp _http;
  final String platform, appVersion;
  static const _key = 'testu_usage_queue';
  String? _session;
  Stopwatch? _fg;

  /// Every public call runs in turn: enqueue and flush are a read-modify-write
  /// on one prefs key, and interleaving them loses events. A flush that
  /// overlaps a retry is harmless — the server dedupes on the event key.
  Future<void> _chain = Future.value();
  Future<void> _run(Future<void> Function() body) =>
      _chain = _chain.then((_) => body()).catchError((Object e) {
            debugPrint('TestU usage failed ($e)');
          });

  /// A launch (or a fresh sign-in). Starts the session first, then ships
  /// whatever the last run left behind — so the new `open` rides along with
  /// the next `pause` instead of costing a request of its own.
  Future<void> open() => _run(() async {
        _start();
        await _flush();
        await _enqueue({'type': 'open'});
      });

  Future<void> resume() => _run(() async {
        // Nothing to resume before an [open] — the sign-in screen going in
        // and out of the background is not usage.
        if (_session == null) return;
        _start();
        await _enqueue({'type': 'resume'});
      });

  Future<void> pause() => _run(() async {
        final s = _fg;
        if (s == null) return; // never opened, or already paused
        _fg = null;
        await _enqueue({'type': 'pause', 'seconds': s.elapsed.inSeconds});
        await _flush();
      });

  Future<void> rate({
    required String channel,
    required String sectionId,
    String? questionId,
    required bool helpful,
  }) =>
      _run(() => _enqueue({
            'type': 'iris_rate',
            'channel': channel,
            'componentsection': sectionId,
            'entityquestion': questionId ?? '',
            'rating': helpful ? 'helpful' : 'nothelpful',
          }));

  /// Called from [TestuAuth.signOut] while the cookie is still good: ship
  /// this learner's events, then drop whatever is left. The queue is
  /// device-global, so anything surviving here would be posted on the next
  /// account's session and counted as theirs.
  Future<void> signOut() => _run(() async {
        await _flush();
        await _save([]);
        _session = null;
        _fg = null;
      });

  Future<void> flush() => _run(_flush);

  void _start() {
    _session =
        '${DateTime.now().microsecondsSinceEpoch}-${identityHashCode(Object())}';
    _fg = Stopwatch()..start();
  }

  Future<List<Map<String, dynamic>>> _queue() async {
    final p = await SharedPreferences.getInstance();
    return [
      for (final e in (jsonDecode(p.getString(_key) ?? '[]') as List))
        Map<String, dynamic>.from(e as Map)
    ];
  }

  Future<void> _save(List<Map<String, dynamic>> q) async =>
      (await SharedPreferences.getInstance()).setString(
          _key, jsonEncode(q.length > 500 ? q.sublist(q.length - 500) : q));

  Future<void> _enqueue(Map<String, dynamic> e) async {
    final q = await _queue();
    q.add({
      ...e,
      'sessionid': _session ?? '',
      'at': DateTime.now().toUtc().toIso8601String(),
      'platform': platform,
      'appversion': appVersion,
    });
    await _save(q);
  }

  Future<int> pending() async => (await _queue()).length;

  Future<void> _flush() async {
    final q = await _queue();
    if (q.isEmpty) return;
    try {
      final r = await _http.postForm('services/testu/usage/track.json',
          [MapEntry('events', jsonEncode(q.take(200).toList()))]);
      if (r['ok'] == true) await _save(q.skip(200).toList());
    } catch (e) {
      debugPrint('TestU usage flush failed ($e)');
    }
  }
}
