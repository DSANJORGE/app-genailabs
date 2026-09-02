import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_live.dart';

const _topicsPath = 'services/module/entitytopic/topics.json';
const _tutorialsPath = 'services/module/entitytutorial/tutorials.json';
const _detailPath = 'services/module/entitytutorial/tutorial.json';

const _progress = {
  'beginnerprogress': 0.1,
  'competentprogress': 0.2,
  'expertprogress': 0.3,
};

Map<String, dynamic> get _topics => {
  'topics': [
    {
      'id': 'TOPIC1',
      'title': 'Derechos Humanos',
      'description': 'd',
      'progress': _progress,
    },
    {'id': 'TOPIC2', 'title': 'Otro', 'progress': _progress},
  ],
};

Map<String, dynamic> get _tutorials => {
  'tutorials': [
    {
      'id': 'TUT1',
      'title': 'Definición',
      'entitytopicid': 'TOPIC1',
      'progress': _progress,
    },
    {
      'id': 'TUT2',
      'title': 'Otra',
      'entitytopicid': 'TOPIC1',
      'progress': _progress,
    },
  ],
};

const _q1 = {
  'id': '1',
  'question': '¿Qué son los Derechos Humanos?',
  'options': {
    'option_a': 'Principios inherentes a toda persona',
    'option_b': 'Privilegios que la empresa otorga',
  },
  'correctoption': 'option_a',
  'rationale': 'Corresponden a toda persona por existir.',
  'cognitivelevel': 'beginner',
};

// No rationale: the render site must fall back to its generic miss copy.
const _q2 = {
  'id': '2',
  'question': '¿Qué característica los define?',
  'options': {
    'option_a': 'Son negociables',
    'option_b': 'Son universales e inalienables',
  },
  'correctoption': 'b',
  'cognitivelevel': 'competent',
};

/// Trimmed from the shape the real server returns: the question object is
/// echoed onto the paragraph row around each real `mcq` row.
Map<String, dynamic> get _detail => {
  'tutorial': {'id': 'TUT1', 'title': 'Definición'},
  'sections': [
    {
      'id': 'SEC1',
      'title': '1. Fundamentos',
      'contents': [
        {'id': 'c1', 'contenttype': 'paragraph', 'question': _q1},
        {'id': 'c2', 'contenttype': 'mcq', 'question': _q1},
      ],
    },
    {
      'id': 'SEC2',
      'title': '2. Empresas',
      'contents': [
        {'id': 'c3', 'contenttype': 'mcq', 'question': _q2},
      ],
    },
  ],
};

void main() {
  late FakeEmeHttp http;
  late EmeQuestionSource source;

  setUp(() {
    http = FakeEmeHttp()
      ..canned[_topicsPath] = _topics
      ..canned[_tutorialsPath] = _tutorials
      ..canned[_detailPath] = _detail;
    source = EmeQuestionSource(http: http);
  });

  test('walks topics -> tutorials -> detail with the right params', () async {
    await source.load();

    // Compared field by field: a record holding a Map compares by identity.
    expect(http.requests.map((r) => r.$1),
        [_topicsPath, _tutorialsPath, _detailPath]);
    expect(http.requests.map((r) => r.$2), [
      <String, String>{},
      {'entitytopic': 'TOPIC1'},
      {'entitytutorial': 'TUT1'},
    ]);
  });

  test('maps the answer key and option order', () async {
    final qs = await source.load();

    expect(qs[0].okIdx, 0); // 'option_a'
    expect(qs[0].opts, [
      'Principios inherentes a toda persona',
      'Privilegios que la empresa otorga',
    ]);
    expect(qs[1].okIdx, 1); // bare 'b'
    expect(qs[0].text, '¿Qué son los Derechos Humanos?');
  });

  test('echoed question rows do not duplicate questions', () async {
    final qs = await source.load();

    expect(qs, hasLength(2));
    expect(qs.map((q) => q.text), [
      '¿Qué son los Derechos Humanos?',
      '¿Qué característica los define?',
    ]);
  });

  test('exposes the loaded topic title', () async {
    await source.load();

    expect(source.topic, 'Derechos Humanos');
  });

  test('a topicId picks that topic instead of the first', () async {
    source = EmeQuestionSource(topicId: 'TOPIC2', http: http);

    await source.load();

    expect(source.topic, 'Otro');
    expect(http.requests[1].$2, {'entitytopic': 'TOPIC2'});
  });

  test('carries questionId, sectionId and componentId', () async {
    final qs = await source.load();

    expect(qs.map((q) => q.questionId), ['1', '2']);
    expect(qs.map((q) => q.sectionId), ['SEC1', 'SEC2']);
    expect(qs.map((q) => q.componentId), ['c2', 'c3']);
  });

  test('rationale becomes the miss copy; absent rationale leaves it null',
      () async {
    final qs = await source.load();

    expect(
      (qs[0].bad!.single as TextSpan).text,
      'Corresponden a toda persona por existir.',
    );
    expect(qs[1].bad, isNull);
  });

  test('kicker numbers the question and names the topic', () async {
    final qs = await source.load();

    expect(qs[0].kicker, 'QUESTION 1 OF 2 · DERECHOS HUMANOS');
    expect(qs[1].kicker, 'QUESTION 2 OF 2 · DERECHOS HUMANOS');
  });

  test('rich fields the backend cannot supply stay null', () async {
    final q = (await source.load()).first;

    expect(q.good, isNull);
    expect(q.quote, isNull);
    expect(q.cite, isNull);
    expect(q.page, isNull);
    expect(q.hint, isNull);
    expect(q.image, isNull);
    expect(q.caption, isNull);
    expect(q.skill, isNull);
    expect(q.comp, isNull);
    expect(q.ob, isNull);
    expect(q.video, isFalse);
    expect(q.framing, isNotEmpty);
  });
}
