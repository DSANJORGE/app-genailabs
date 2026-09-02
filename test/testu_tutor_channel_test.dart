import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_live.dart';

const _historyPath = 'services/module/entitytutorial/tutorhistory.json';
const _sessionPath = 'services/module/entitytutorial/tutorsession.json';

const _channel = {
  'id': 'CH1',
  'channeltype': 'agenttutorchat',
  'name': 'Definición',
  'dataid': 'TUT1',
  'user': 'testautologinuser',
};

// What minsur answers for a tutorial with a live session (2026-09-02).
const _historyWithoutChannel = {
  'response': {'status': 'ok', 'userid': 'testautologinuser'},
  'messages': [],
  'answers': [],
};

void main() {
  late FakeEmeHttp http;

  setUp(() => http = FakeEmeHttp());

  test('uses the active channel from tutor history when present', () async {
    http.canned[_historyPath] = {
      ..._historyWithoutChannel,
      'activechannel': _channel,
    };

    final c = await findTutorChannel('TUT1', http: http);

    expect(c?.id, 'CH1');
    expect(http.requests.map((r) => r.$1), [_historyPath]);
  });

  test('falls back to tutorsession.json when history has no channel',
      () async {
    http.canned[_historyPath] = _historyWithoutChannel;
    http.canned[_sessionPath] = {'channel': _channel};

    final c = await findTutorChannel('TUT1', http: http);

    expect(c?.id, 'CH1');
    expect(http.requests.map((r) => r.$1), [_historyPath, _sessionPath]);
    expect(http.requests[1].$2, {'dataid': 'TUT1'});
  });

  test('null when neither endpoint has a channel', () async {
    http.canned[_historyPath] = _historyWithoutChannel;
    http.canned[_sessionPath] = {
      'response': {'status': 'ok'},
    };

    expect(await findTutorChannel('TUT1', http: http), isNull);
  });
}
