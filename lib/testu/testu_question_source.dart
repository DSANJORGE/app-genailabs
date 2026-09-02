import 'package:flutter/painting.dart';

import 'testu_i18n.dart';

/// Where session questions come from. The session screen only sees this
/// seam, so a live EnterMedia-backed source can slot in later without
/// touching the widgets or the engine.

/// Italic accent inside framing copy; shared with the live adapter.
const testuItal =
    TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFA9A8A4));
const _bold = TextStyle(fontWeight: FontWeight.w700);

/// One session question, render-ready. Fields a backend can't supply are
/// nullable; render sites fall back to generic copy or omit the block.
class TestuQ {
  const TestuQ({
    this.questionId,
    this.sectionId,
    this.componentId,
    required this.framing,
    this.whyLink = false,
    this.video = false,
    required this.kicker,
    this.image,
    this.caption,
    this.diagram = false,
    required this.text,
    required this.opts,
    required this.okIdx,
    this.good,
    this.bad,
    this.quote,
    this.cite,
    this.page,
    this.hint,
    this.skill,
    this.comp,
    this.ob,
  });

  // Write path for the future live adapter; null for local data.
  final String? questionId;
  final String? sectionId;
  final String? componentId;

  final List<InlineSpan> framing;
  final bool whyLink;
  final bool video;
  final String kicker;
  final String? image;
  final String? caption;
  final bool diagram;
  final String text;
  final List<String> opts;
  final int okIdx;

  /// Verdict copy for a confident correct answer; null → generic fallback.
  final String? good;

  /// Verdict copy for a wrong answer; null → generic fallback.
  final List<InlineSpan>? bad;

  final String? quote;
  final String? cite;
  final int? page;
  final String? hint;
  final String? skill;
  final String? comp;
  final String? ob;
}

abstract class TestuQuestionSource {
  Future<List<TestuQ>> load();

  /// Title of the topic the loaded questions belong to; the session header
  /// and the debrief show it. The prototype's fixed topic by default.
  String get topic => L('Ramp Safety', 'Seguridad en rampa');

  /// Fire-and-forget: report a submitted attempt. No-op by default; the
  /// future live adapter overrides this to write back to the backend.
  void reportAttempt({
    required int qi,
    String? questionId,
    required int chosen,
    required int confidence,
    required bool correct,
  }) {}

  /// Fire-and-forget: the user flagged a question for the content team.
  /// ponytail: no-op until the content-review endpoint exists — the live
  /// adapter will override this with the real POST.
  void reportFlag({
    required TestuQ q,
    required String reason,
    String? note,
  }) {}
}

/// The approved prototype's hardcoded questions. [load] completes
/// immediately; call it again after a language switch — the copy resolves
/// `L()` at load time.
class LocalQuestionSource extends TestuQuestionSource {
  @override
  Future<List<TestuQ>> load() async => _questions;
}

// Question data verbatim from the approved prototype (FAA quotes and
// citations stay in English — they are verbatim legal citations).
List<TestuQ> get _questions => [
  TestuQ(
    framing: [
      TextSpan(text: L('Next up in ', 'Siguiente en ')),
      TextSpan(
          text: L('Aircraft arrival & chocking', 'Llegada y calzado'),
          style: testuItal),
      TextSpan(
          text: L(
              '. This one matters because approaching too early is one of the most common ramp near-misses.',
              '. Esta importa porque aproximarse demasiado pronto es uno de los casi-incidentes más comunes en rampa.')),
    ],
    kicker: L('QUESTION 22 OF 36 · AIRCRAFT ARRIVAL',
        'PREGUNTA 22 DE 36 · LLEGADA DE LA AERONAVE'),
    image: 'assets/img/chocks.jpg',
    caption: L('Main gear on chocks after arrival on stand',
        'Tren principal calzado tras la llegada al stand'),
    text: L(
        'When must wheel chocks be positioned after aircraft arrival on stand?',
        '¿Cuándo deben colocarse los calzos tras la llegada de la aeronave al stand?'),
    opts: [
      L('As soon as the aircraft comes to a complete stop, before engine shutdown',
          'En cuanto la aeronave se detiene por completo, antes de apagar motores'),
      L('Immediately after engines are shut down and anti-collision lights are off',
          'Inmediatamente después de apagar motores y con las luces anticolisión apagadas'),
      L('Only after the ground power unit has been connected',
          'Solo después de conectar la unidad de energía de tierra (GPU)'),
      L('When the flight crew confirms parking brake release',
          'Cuando la tripulación confirma la liberación del freno de estacionamiento'),
    ],
    okIdx: 1,
    good: L('Correct — and you were certain. That knowledge is consolidating.',
        'Correcto — y estabas ${G('seguro', 'segura')}. Ese conocimiento se está consolidando.'),
    bad: [
      TextSpan(
          text: L(
              'Not quite. The anti-collision lights are the signal — engines off alone is not enough. Approaching a stopped aircraft with engines running is the hazard this rule exists for.',
              'No exactamente. Las luces anticolisión son la señal — motores apagados no basta por sí solo. Aproximarse a una aeronave detenida con motores en marcha es el peligro por el que existe esta regla.')),
    ],
    quote:
        'When an aircraft is parked, the main gear wheels should be chocked fore and aft.',
    cite: 'FAA AC 00-34A · §5 Parked Aircraft',
    page: 1,
    hint: L(
        'Try eliminating options that describe a moment while engines could still be running.',
        'Prueba a eliminar las opciones que describen un momento en el que los motores aún podrían estar en marcha.'),
    skill: L('Chock timing & sequence', 'Momento y secuencia de calzado'),
    comp: L('Safe aircraft handling', 'Manejo seguro de la aeronave'),
    ob: L('Positions chocks only after engines are shut down and anti-collision lights are off',
        'Coloca los calzos solo con motores apagados y luces anticolisión apagadas'),
  ),
  TestuQ(
    framing: [
      TextSpan(
          text: L(
              'Ground guidance next. You will see one of the standard operating signals — read it the way a flight crew would from the cockpit.',
              'Ahora guiado en tierra. Verás una de las señales operativas estándar — léela como lo haría la tripulación desde la cabina.')),
    ],
    kicker: L('QUESTION 23 OF 36 · GROUND GUIDANCE SIGNALS',
        'PREGUNTA 23 DE 36 · SEÑALES DE GUIADO'),
    image: 'assets/img/signal.png',
    diagram: true,
    text: L('What is the marshaller signalling to the flight crew here?',
        '¿Qué está señalizando aquí el señalero a la tripulación?'),
    opts: [
      L('Slow down', 'Reducir velocidad'),
      L('Cut engines', 'Cortar motores'),
      L('Start engines', 'Arrancar motores'),
      L('Insert chocks', 'Colocar calzos'),
    ],
    okIdx: 1,
    good: L(
        'Correct — and you were certain. The raised finger indicates which engine; the hand across the throat is the cut.',
        'Correcto — y estabas ${G('seguro', 'segura')}. El dedo levantado indica qué motor; la mano cruzando la garganta es el corte.'),
    bad: [
      TextSpan(text: L('Not quite. This is the ', 'No exactamente. Esta es la señal de ')),
      TextSpan(text: L('cut engines', 'cortar motores'), style: _bold),
      TextSpan(
          text: L(
              ' signal — the raised finger indicates which engine, the hand across the throat is the cut. Misreading it keeps engines running with ground crew approaching.',
              ' — el dedo levantado indica qué motor, la mano cruzando la garganta es el corte. Malinterpretarla deja motores en marcha con personal de tierra aproximándose.')),
    ],
    quote:
        'Use the standard hand signals illustrated in Figures 1 and 2, as applicable, of Appendix 1 of this circular.',
    cite: 'FAA AC 00-34A · Appendix 1, Figure 1',
    page: 9,
    hint: L('Look at where the free hand is — throat level means something specific.',
        'Fíjate en dónde está la mano libre — a la altura de la garganta significa algo concreto.'),
    skill: L('Signal reading', 'Lectura de señales'),
    comp: L('Situational awareness on stand', 'Conciencia situacional en el stand'),
    ob: L('Reads standard marshalling signals correctly from any position',
        'Lee correctamente las señales estándar desde cualquier posición'),
  ),
  TestuQ(
    framing: [
      TextSpan(
          text: L(
              'Sully picked this because your last answer showed uncertainty in ',
              'Sully eligió esta porque tu última respuesta mostró dudas en ')),
      TextSpan(text: L('FOD reporting', 'notificación de FOD'), style: testuItal),
      TextSpan(
          text: L('. Before you answer — I’ve cued the video to ',
              '. Antes de responder — he dejado el vídeo en ')),
      TextSpan(
          text: L('Arrival & stand check', 'Llegada y revisión del stand'),
          style: testuItal),
      TextSpan(
          text: L(
              '. Watch it and count how often the crew scans the stand surface.',
              '. Míralo y cuenta cuántas veces el equipo examina la superficie del stand.')),
    ],
    whyLink: true,
    video: true,
    kicker: L('QUESTION 24 OF 36 · FOD INSPECTION',
        'PREGUNTA 24 DE 36 · INSPECCIÓN FOD'),
    text: L(
        'What is the primary purpose of the FOD walk performed before aircraft arrival on stand?',
        '¿Cuál es el propósito principal de la inspección FOD que se realiza antes de la llegada de la aeronave?'),
    opts: [
      L('To confirm the stand markings are visible for the marshaller',
          'Confirmar que las marcas del stand son visibles para el señalero'),
      L('To verify that ground support equipment is parked in designated areas',
          'Verificar que los equipos de tierra están aparcados en las zonas designadas'),
      L('To detect and remove foreign objects that could damage the aircraft or injure personnel',
          'Detectar y retirar objetos extraños que podrían dañar la aeronave o herir al personal'),
      L('To check surface conditions ahead of the pushback procedure',
          'Comprobar el estado de la superficie antes del pushback'),
    ],
    okIdx: 2,
    good: L(
        'Correct — and you were certain. Note the manual frames FOD as both an aircraft and a personnel hazard; that dual framing is what evaluations test.',
        'Correcto — y estabas ${G('seguro', 'segura')}. Fíjate en que el manual trata el FOD como peligro tanto para la aeronave como para el personal; ese doble enfoque es lo que evalúan.'),
    bad: [
      TextSpan(
          text: L(
              'Not quite. That is a real ramp duty, but not the purpose of the FOD walk — it exists to remove objects that could damage the aircraft or injure personnel.',
              'No exactamente. Esa es una tarea real de rampa, pero no el propósito de la inspección FOD — existe para retirar objetos que podrían dañar la aeronave o herir al personal.')),
    ],
    quote:
        'Ground personnel should develop a habit of making a visual check of the aircraft as soon as it is parked and secured.',
    cite: 'FAA AC 00-34A · §5(b)',
    page: 2,
    hint: L(
        'Read for the intent of the walk, not for tasks that merely happen on the same stand.',
        'Céntrate en la intención de la inspección, no en tareas que simplemente ocurren en el mismo stand.'),
    skill: L('FOD walk pattern', 'Patrón de inspección FOD'),
    comp: L('Safe aircraft handling', 'Manejo seguro de la aeronave'),
    ob: L('Performs a FOD walk before every aircraft arrival',
        'Realiza una inspección FOD antes de cada llegada'),
  ),
];
