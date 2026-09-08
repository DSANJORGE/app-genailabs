import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_live.dart';
import 'package:genai_labs/testu/testu_sully.dart';

const _doc = 'Plan Nacional de Acción sobre Empresas y Derechos Humanos '
    '2021-2025 (Perú)';

void main() {
  test('>> lines become follow-ups and leave the text', () {
    final c = splitCite('El Plan fija metas [$_doc, p. 13].\n'
        '>> ¿Quieres ver las metas?\n'
        '>> ¿Te explico el marco?');
    expect(c.text, 'El Plan fija metas.');
    expect(c.followups, ['¿Quieres ver las metas?', '¿Te explico el marco?']);
    expect(c.title, _doc);
    expect(c.page, 13);
    expect(c.notFound, isFalse);
  });

  test('follow-ups are stripped from an uncited reply too', () {
    final c = splitCite(
        'La opción A es correcta por lo que dice la rationale.\n\n>> ¿Repasamos B?');
    expect(c.text, 'La opción A es correcta por lo que dice la rationale.');
    expect(c.followups, ['¿Repasamos B?']);
    expect(c.title, isNull);
    expect(c.notFound, isFalse);
  });

  test('a >> line is never taken for a > quote', () {
    final c = splitCite('Texto [$_doc, p. 2].\n> cita literal\n>> ¿Seguimos?');
    expect(c.quote, 'cita literal');
    expect(c.followups, ['¿Seguimos?']);
    expect(c.text, 'Texto.');
  });

  test('the not-found sentence is recognised, with its one follow-up', () {
    final c = splitCite('$sullyNotFound\n>> ¿Quieres que repasemos lo que sí cubre el tema?');
    expect(c.notFound, isTrue);
    expect(c.title, isNull);
    expect(c.text, sullyNotFound);
    expect(c.followups, ['¿Quieres que repasemos lo que sí cubre el tema?']);
  });

  test('no >> lines: followups empty, text untouched', () {
    final c = splitCite('Sin fuentes disponibles [ver política].');
    expect(c.followups, isEmpty);
    expect(c.text, 'Sin fuentes disponibles [ver política].');
    expect(c.notFound, isFalse);
  });

  test('tutorTurns maps the history page to (fromUser, text) rows', () {
    final turns = tutorTurns({
      'ok': true,
      'turns': [
        {'id': 'a', 'from': 'user', 'text': '¿Qué es la debida diligencia?'},
        {'id': 'b', 'from': 'tutor', 'text': '<p>Es el proceso… [$_doc, p. 20]</p>'},
        {'id': 'c', 'from': 'tutor', 'text': 'Error on AI Agent'},
        {'id': 'd', 'from': 'user', 'text': '   '},
        {'id': 'e', 'from': 'user'},
        {'id': 'f', 'from': 'system', 'text': 'ignored'},
      ],
    });
    expect(turns, [
      (true, '¿Qué es la debida diligencia?'),
      (false, 'Es el proceso… [$_doc, p. 20]'),
      (false, sullyUnavailable()),
    ]);
    expect(tutorTurns({'ok': true}), isEmpty);
  });
}
