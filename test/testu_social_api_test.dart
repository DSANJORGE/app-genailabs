import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_live.dart';
import 'package:genai_labs/testu/testu_question_source.dart';
import 'package:genai_labs/testu/testu_social_api.dart';

const _thread = 'services/testu/social/thread.json';
const _comment = 'services/testu/social/comment.json';
const _react = 'services/testu/social/react.json';
const _people = 'services/testu/social/mentionables.json';
const _flag = 'services/testu/social/flag.json';

Map<String, dynamic> _threadJson() => {
      'ok': true,
      'channel': 'q-Q1',
      'comments': [
        {
          'id': 'c1',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'role': 'users',
          'date': '2026-09-07T10:00:00-05:00',
          'text': 'Me confundió a quiénes aplican.',
          'reacts': {'like': 3, 'support': 1, 'bogus': 9},
          'mine': 'like',
          'replies': [
            {
              'id': 'c2',
              'userId': 'jorge',
              'name': 'Jorge Paredes',
              'role': 'training',
              'date': '2026-09-07T10:05:00-05:00',
              'text': 'Aplican a todas las personas.',
              'reacts': {},
              'mine': null,
              'replies': [],
            },
          ],
        },
      ],
    };

void main() {
  late FakeEmeHttp http;
  late TestuSocialApi api;
  setUp(() {
    http = FakeEmeHttp();
    api = TestuSocialApi(http: http);
  });

  test('thread parses comments, replies, reactions and my reaction', () async {
    http.canned[_thread] = _threadJson();
    final rows = await api.thread('q-Q1');
    expect(http.requests.single.$1, _thread);
    expect(http.requests.single.$2, containsPair('channel', 'q-Q1'));
    final c = rows.single;
    expect(c.id, 'c1');
    expect(c.userId, 'lucia');
    expect(c.who, 'Lucía Mendoza');
    expect(c.role, isNull, reason: 'a learner wears no badge');
    expect(c.avatar, isNull, reason: 'live rows draw initials');
    expect(c.date, DateTime.parse('2026-09-07T10:00:00-05:00'));
    // Unknown reaction names from the server are dropped, never crash the parse.
    expect(c.reacts, {TestuReaction.like: 3, TestuReaction.support: 1});
    expect(c.myReact, TestuReaction.like);
    expect(c.replies.single.role, 'INSTRUCTOR');
    expect(c.replies.single.myReact, isNull);
  });

  test('comment posts channel, message, replytoid and mentions as ids', () async {
    http.canned[_comment] = {'ok': true, 'id': 'c9'};
    final id = await api.comment(
        channel: 'q-Q1', text: 'Hola @Jorge Paredes', replyToId: 'c1', mentions: ['jorge']);
    expect(id, 'c9');
    final f = http.posted.single.fields;
    expect(http.posted.single.path, _comment);
    expect(f['channel'], 'q-Q1');
    expect(f['message'], 'Hola @Jorge Paredes');
    expect(f['replytoid'], 'c1');
    expect(f['mentions'], '["jorge"]');
  });

  test('a top-level comment sends no replytoid and an empty mentions list', () async {
    http.canned[_comment] = {'ok': true, 'id': 'c9'};
    await api.comment(channel: 't-TUT1', text: 'Buena actualización');
    final f = http.posted.single.fields;
    expect(f.containsKey('replytoid'), isFalse);
    expect(f['mentions'], '[]');
  });

  test('react sends the reaction name and parses the server reacts, dropping unknown names', () async {
    http.canned[_react] = {
      'ok': true,
      'mine': 'idea',
      'reacts': {'idea': 1, 'bogus': 9},
    };
    final res = await api.react('c1', TestuReaction.idea);
    await api.react('c1', null);
    expect(http.posted[0].fields, {'messageid': 'c1', 'name': 'idea'});
    expect(http.posted[1].fields, {'messageid': 'c1', 'name': ''});
    expect(res.mine, TestuReaction.idea);
    expect(res.reacts, {TestuReaction.idea: 1});
  });

  test('mentionables parses people', () async {
    http.canned[_people] = {
      'ok': true,
      'people': [
        {'id': 'jorge', 'name': 'Jorge Paredes', 'role': 'training'},
        {'id': 'rosa', 'name': 'Rosa Jiménez', 'role': 'users'},
      ],
    };
    final p = await api.mentionables();
    expect(p.map((m) => m.id), ['jorge', 'rosa']);
    expect(p.first.role, 'training');
  });

  test('recent parses comments and open flags', () async {
    http.canned[_thread] = {
      'ok': true,
      'recent': [
        {
          'id': 'c1',
          'channel': 'q-Q1',
          'moduleid': 'entityquestion',
          'entityid': 'Q1',
          'label': '¿Qué son los Derechos Humanos?',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'role': 'users',
          'date': '2026-09-07T10:00:00-05:00',
          'text': 'Me confundió.',
          'replytoid': null,
        },
      ],
      'flags': [
        {
          'id': 'f1',
          'entityquestion': 'Q1',
          'entitytutorial': 'TUT1',
          'label': '¿Qué son los Derechos Humanos?',
          'reason': 'unclear',
          'note': 'curl smoke',
          'userId': 'lucia',
          'name': 'Lucía Mendoza',
          'date': '2026-09-07T09:00:00-05:00',
        },
      ],
    };
    final r = await api.recent();
    expect(http.requests.single.$2, isEmpty, reason: 'no channel means the recent listing');
    expect(r.comments.single.channel, 'q-Q1');
    expect(r.comments.single.label, '¿Qué son los Derechos Humanos?');
    expect(r.flags.single.reason, 'unclear');
    expect(r.flags.single.questionId, 'Q1');
  });

  test('flag posts question, tutorial, reason and note', () async {
    http.canned[_flag] = {'ok': true, 'id': 'f1'};
    await api.flag(questionId: 'Q1', tutorialId: 'TUT1', reason: 'wrong', note: 'p. 3 dice otra cosa');
    expect(http.posted.single.fields,
        {'entityquestion': 'Q1', 'entitytutorial': 'TUT1', 'reason': 'wrong', 'note': 'p. 3 dice otra cosa'});
  });

  test('a 2xx body with ok:false throws with the server message', () async {
    http.canned[_flag] = {'ok': false, 'error': 'bad reason'};
    await expectLater(
        api.flag(questionId: 'Q1', reason: 'x'), throwsA(predicate((e) => '$e'.contains('bad reason'))));
  });

  test('reason ids and labels line up', () {
    expect(testuFlagReasons, ['wrong', 'unclear', 'outdated', 'other']);
    expect(flagReasonLabel('unclear'), 'Confusing or badly worded');
    expect(roleBadge('users'), isNull);
    expect(roleBadge('manager'), 'MANAGER');
  });

  test('EmeQuestionSource.reportFlag posts flag.json for a backend question', () async {
    final http = FakeEmeHttp();
    http.canned[_flag] = {'ok': true, 'id': 'f1'};
    final src = EmeQuestionSource(http: http);
    await src.reportFlag(
        q: const TestuQ(questionId: 'Q1', framing: [], kicker: '', text: '', opts: [], okIdx: 0),
        reason: 'outdated',
        note: null);
    expect(http.posted.single.path, _flag);
    expect(http.posted.single.fields['entityquestion'], 'Q1');
    expect(http.posted.single.fields['reason'], 'outdated');
    // A demo question (no id) never reaches the server.
    await src.reportFlag(
        q: const TestuQ(framing: [], kicker: '', text: '', opts: [], okIdx: 0), reason: 'other');
    expect(http.posted.length, 1);
  });
}
