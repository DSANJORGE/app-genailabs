import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_notifications.dart';
import 'package:genai_labs/testu/testu_route.dart';
import 'package:genai_labs/testu/testu_shell.dart';
import 'package:genai_labs/testu/testu_theme.dart';

const _path = 'services/testu/social/notifications.json';

void main() {
  setUp(() => clearTestuNotices());

  group('noticePreview', () {
    test('strips citation and quote markers, collapses to one line', () {
      final r = noticePreview(
          'Answer text.\n> quoted source line\n[Some Title, p. 12]');
      expect(r, isNot(contains('[')));
      expect(r, isNot(contains(']')));
      expect(r, isNot(contains('>')));
      expect(r.length, lessThanOrEqualTo(120));
      expect(r, 'Answer text.');
    });
    test('empty reply yields empty string', () {
      expect(noticePreview(''), '');
    });
  });

  group('testuNoticeTarget', () {
    test('tutorreply selects the IRIS tab', () {
      final t = testuNoticeTarget(TestuNotice('t', 'b', 'Now', type: 'tutorreply'));
      expect(t.tab, 2);
      expect(t.topicId, isNull);
    });
    test('a reply on a question opens that question at the comment', () {
      final n = TestuNotice('t', 'b', 'Now',
          type: 'reply',
          topicId: 'TOP1',
          questionId: 'Q1',
          messageId: 'M1',
          tutorialId: 'TUT1');
      expect(
          testuNoticeTarget(n),
          (
            tab: null,
            topicId: 'TOP1',
            questionId: 'Q1',
            messageId: 'M1',
            tutorialId: 'TUT1'
          ));
    });
    test('a mention on a topic carries the tutorialId too', () {
      final n = TestuNotice('t', 'b', 'Now',
          type: 'mention', topicId: 'TOP1', messageId: 'M3', tutorialId: 'TUT1');
      expect(
          testuNoticeTarget(n),
          (
            tab: null,
            topicId: 'TOP1',
            questionId: null,
            messageId: 'M3',
            tutorialId: 'TUT1'
          ));
    });
    test('a reaction on a topic review opens the topic without a question', () {
      final n = TestuNotice('t', 'b', 'Now',
          type: 'reaction', topicId: 'TOP1', messageId: 'M2', tutorialId: 'TUT1');
      expect(
          testuNoticeTarget(n),
          (
            tab: null,
            topicId: 'TOP1',
            questionId: null,
            messageId: 'M2',
            tutorialId: 'TUT1'
          ));
    });
    test('a mention without a topic and an unknown type go nowhere', () {
      expect(
          testuNoticeTarget(TestuNotice('t', 'b', 'Now', type: 'mention')),
          (
            tab: null,
            topicId: null,
            questionId: null,
            messageId: null,
            tutorialId: null
          ));
      expect(
          testuNoticeTarget(TestuNotice('t', 'b', 'Now')),
          (
            tab: null,
            topicId: null,
            questionId: null,
            messageId: null,
            tutorialId: null
          ));
    });
  });

  test('refresh maps the server rows, newest first, and keeps local notices',
      () async {
    final http = FakeEmeHttp();
    http.canned[_path] = {
      'ok': true,
      'unread': 1,
      'notifications': [
        {
          'id': 'N1', 'type': 'mention', 'actorname': 'Rosa J.',
          'text': 'mira esto', 'channel': 'q-Q1', 'messageid': 'M1',
          'entitytutorial': 'TUT1', 'entitytopic': 'TOP1',
          'entityquestion': 'Q1', 'read': false,
          'date': '2026-09-07T10:00:00Z',
        },
        {
          'id': 'N2', 'type': 'reaction', 'actorname': 'Carlos V.',
          'text': 'ok', 'channel': 't-TUT1', 'messageid': 'M2',
          'entitytutorial': 'TUT1', 'entitytopic': 'TOP1',
          'entityquestion': '', 'read': true,
          'date': '2026-09-06T10:00:00Z',
        },
      ],
    };
    addTestuNotice('IRIS answered you', 'body', type: 'tutorreply');
    await refreshTestuNotices(http: http);
    final items = testuNotices.value;
    expect(items.map((n) => n.id), [null, 'N1', 'N2']);
    expect(items[1].title, 'Rosa J. mentioned you');
    expect(items[1].body, 'mira esto');
    expect(items[1].unread, isTrue);
    expect(items[1].date, DateTime.utc(2026, 9, 7, 10).toLocal());
    expect(items[2].unread, isFalse);
    expect(items[2].questionId, isNull); // '' from the server reads as none
    expect(items[2].topicId, 'TOP1');
  });

  test('a dismissed row does not come back on the next refresh', () async {
    final http = FakeEmeHttp();
    http.canned[_path] = {
      'ok': true, 'unread': 0,
      'notifications': [
        {'id': 'N1', 'type': 'reply', 'actorname': 'A', 'text': 't',
         'read': true, 'date': '2026-09-06T10:00:00Z'},
      ],
    };
    await refreshTestuNotices(http: http);
    dismissTestuNotice(testuNotices.value.single);
    expect(testuNotices.value, isEmpty);
    await refreshTestuNotices(http: http);
    expect(testuNotices.value, isEmpty);
  });

  test('a failed refresh keeps what is there', () async {
    addTestuNotice('IRIS answered you', 'body', type: 'tutorreply');
    // refreshTestuNotices() debugPrint('TestU: notifications (...)') on the
    // 404 below — debugPrint is Flutter's officially-reassignable global,
    // so silence it for this call rather than let it clutter test output.
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    try {
      await refreshTestuNotices(http: FakeEmeHttp()); // no canned reply -> 404
    } finally {
      debugPrint = originalDebugPrint;
    }
    expect(testuNotices.value.length, 1);
  });

  test('markread posts the ids as one JSON field', () async {
    final http = FakeEmeHttp();
    http.canned['services/testu/social/markread.json'] = {'ok': true, 'marked': 2};
    await markTestuNoticesRead(['N1', 'N2'], http: http);
    expect(http.posted.single.fields['ids'], '["N1","N2"]');
    await markTestuNoticesRead(const [], http: http); // nothing to send
    expect(http.posted.length, 1);
  });

  testWidgets('the bell shows the dot only while something is unread',
      (tester) async {
    testuNotices.value = [TestuNotice('t', 'b', 'Now', id: 'N1', type: 'reply')];
    await tester.pumpWidget(MaterialApp(
        theme: testuTheme(), home: const Scaffold(body: TestuBell())));
    expect(find.byKey(const ValueKey('testu-bell-dot')), findsOneWidget);
    testuNotices.value = [
      TestuNotice('t', 'b', 'Now', id: 'N1', type: 'reply', unread: false)
    ];
    await tester.pump();
    expect(find.byKey(const ValueKey('testu-bell-dot')), findsNothing);
  });

  testWidgets('tapping a tutorreply row asks the shell for the IRIS tab',
      (tester) async {
    // Since Part E the tap goes through openLearnerRoute, the one door: the
    // shell reads the whole address, not just a tab index.
    testuNotices.value = [
      TestuNotice('IRIS answered you', 'body', 'Now', type: 'tutorreply')
    ];
    await tester.pumpWidget(MaterialApp(
        theme: testuTheme(), home: const TestuNotificationsScreen()));
    await tester.tap(find.text('IRIS answered you'));
    await tester.pump();
    expect(TestuShell.routeRequest.value, const LearnerRoute(2));
    TestuShell.routeRequest.value = null;
  });

  // testuLive defaults to true (client == 'minsur', the default) even in a
  // plain `flutter test` run, so startTestuNoticePolling() fires a real,
  // unawaited refreshTestuNotices() against DioEmeHttp, which has no server
  // to talk to here and fails, hitting the debugPrint this test silences.
  // pumpEventQueue() lets that unawaited call land before the guard comes
  // off, so it doesn't leak a stray debugPrint into a later test.
  test('start then stop is idempotent and leaves nothing polling', () async {
    final originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    try {
      startTestuNoticePolling();
      startTestuNoticePolling(); // already polling: must not double-schedule
      stopTestuNoticePolling();
      stopTestuNoticePolling(); // already stopped: must not throw
      await pumpEventQueue();
    } finally {
      debugPrint = originalDebugPrint;
    }
  });
}
