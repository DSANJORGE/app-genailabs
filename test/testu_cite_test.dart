import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_live.dart';

void main() {
  test('splitCite lifts the server citation into title + page', () {
    const doc = 'Plan Nacional de Acción sobre Empresas y Derechos Humanos '
        '2021-2025 (Perú)';
    final c = splitCite('El Plan es una herramienta estratégica [$doc, p. 13]. '
        'En cuanto a tu respuesta E, revisa el principio.');
    expect(c.title, doc);
    expect(c.page, 13);
    expect(c.text, 'El Plan es una herramienta estratégica. '
        'En cuanto a tu respuesta E, revisa el principio.');
  });

  test('splitCite leaves an uncited reply alone', () {
    final c = splitCite('Sin fuentes disponibles [ver política].');
    expect(c.title, isNull);
    expect(c.page, 1);
    expect(c.text, 'Sin fuentes disponibles [ver política].');
  });
}
