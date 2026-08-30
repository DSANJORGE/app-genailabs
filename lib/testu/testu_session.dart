import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_pdf.dart';
import 'testu_shell.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Every "start a session" CTA in the app lands here.
void showTestuSession(BuildContext context) {
  Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TestuSessionScreen()));
}

// Once per app run: the first confidence tap explains that tapping submits.
// ponytail: in-memory instead of persisted — a demo restart re-teaching the
// rule is fine.
bool _confAcked = false;

List<String> get _conf => [
  L('Guessing', 'Adivinando'),
  L('Unsure', 'Inseguro'),
  L('Fairly sure', 'Bastante seguro'),
  L('Certain', 'Seguro'),
];
const _confColors = [
  Color(0xFFC25555),
  Color(0xFFD9A23F),
  Color(0xFF9DB55C),
  Color(0xFF4CA97A),
];
const _confSelectedBg = [
  Color(0xFF2A1516),
  Color(0xFF291F10),
  Color(0xFF1D2212),
  Color(0xFF12231B),
];

const _ital = TextStyle(fontStyle: FontStyle.italic, color: Color(0xFFA9A8A4));
const _bold = TextStyle(fontWeight: FontWeight.w700);

class _Q {
  const _Q({
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
    required this.good,
    required this.bad,
    required this.quote,
    required this.cite,
    required this.page,
    required this.hint,
    required this.skill,
    required this.comp,
    required this.ob,
  });

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
  final String good;
  final List<InlineSpan> bad;
  final String quote;
  final String cite;
  final int page;
  final String hint;
  final String skill;
  final String comp;
  final String ob;
}

// Question data verbatim from the approved prototype (FAA quotes and
// citations stay in English — they are verbatim legal citations).
List<_Q> get _questions => [
  _Q(
    framing: [
      TextSpan(text: L('Next up in ', 'Siguiente en ')),
      TextSpan(
          text: L('Aircraft arrival & chocking', 'Llegada y calzado'),
          style: _ital),
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
        'Correcto — y estabas segura. Ese conocimiento se está consolidando.'),
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
  _Q(
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
        'Correcto — y estabas segura. El dedo levantado indica qué motor; la mano cruzando la garganta es el corte.'),
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
  _Q(
    framing: [
      TextSpan(
          text: L(
              'Sully picked this because your last answer showed uncertainty in ',
              'Sully eligió esta porque tu última respuesta mostró dudas en ')),
      TextSpan(text: L('FOD reporting', 'notificación de FOD'), style: _ital),
      TextSpan(
          text: L('. Before you answer — I’ve cued the video to ',
              '. Antes de responder — he dejado el vídeo en ')),
      TextSpan(
          text: L('Arrival & stand check', 'Llegada y revisión del stand'),
          style: _ital),
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
        'Correcto — y estabas segura. Fíjate en que el manual trata el FOD como peligro tanto para la aeronave como para el personal; ese doble enfoque es lo que evalúan.'),
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

/// Learn Mode session — a chat with Sully. Confidence tap IS the submit;
/// the debrief follows the last question.
class TestuSessionScreen extends StatefulWidget {
  const TestuSessionScreen({super.key});

  @override
  State<TestuSessionScreen> createState() => _TestuSessionScreenState();
}

class _TestuSessionScreenState extends State<TestuSessionScreen> {
  final _scroll = ScrollController();
  final List<Widget> _chat = [];
  int _qi = 0;
  double _progress = 0.05;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 300), () {
      if (mounted) _nextStep();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _add(Widget w) {
    setState(() => _chat.add(w));
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: TestuTokens.curve,
      );
    });
  }

  void _nextStep() {
    final q = _questions[_qi];
    setState(() => _progress = 0.08 + (_qi / _questions.length) * 0.90);
    if (q.video) {
      _add(_SullyBubble(
        spans: _framingSpans(q),
        delay: 900,
        onGrew: _scrollDown,
        extra: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const _FakePlayer(),
            const SizedBox(height: 12),
            _ChoiceChips(
              chips: [
                (L('I watched it — continue', 'Lo he visto — continuar'),
                    true, _showQuestion)
              ],
            ),
          ],
        ),
      ));
    } else {
      _add(_SullyBubble(spans: _framingSpans(q), delay: 900, onGrew: _scrollDown));
      Timer(const Duration(milliseconds: 1450), () {
        if (mounted) _showQuestion();
      });
    }
  }

  List<InlineSpan> _framingSpans(_Q q) => [
        ...q.framing,
        if (q.whyLink)
          TextSpan(
            // ponytail: decorative link — the explanation sheet doesn't exist.
            text: L(' Why this question?', ' ¿Por qué esta pregunta?'),
            style: const TextStyle(
              color: Color(0xFF8B8F98),
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF3A3A40),
            ),
          ),
      ];

  void _showQuestion() {
    final q = _questions[_qi];
    _add(_QuestionCard(
      q: q,
      onGrew: _scrollDown,
      onHint: () => _add(_SullyBubble(
        delay: 800,
        onGrew: _scrollDown,
        spans: [
          TextSpan(
              text: L(
                  'I can give you a hint. This will mark the attempt as assisted, so it will count less toward mastery.\n\n',
                  'Puedo darte una pista. Esto marcará el intento como asistido, así que contará menos para tu dominio.\n\n')),
          TextSpan(text: q.hint, style: _ital),
        ],
      )),
      onSubmit: (chosen, conf) => _submit(q, chosen, conf),
    ));
  }

  void _submit(_Q q, int chosen, int conf) {
    final good = chosen == q.okIdx;
    good ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();

    final List<InlineSpan> spans;
    if (good) {
      spans = [
        TextSpan(
            text: '${L('Correct', 'Correcto')} · ${_conf[conf]}\n',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                letterSpacing: 0.25,
                color: Color(0xFF7DBB9C))),
        TextSpan(
            text: conf >= 2
                ? q.good
                : L('Correct. You marked it "${_conf[conf]}" — this knowledge may not be fully consolidated yet, so I’ll bring it back soon.',
                    'Correcto. Lo marcaste como «${_conf[conf]}» — puede que este conocimiento aún no esté consolidado, así que lo traeré de vuelta pronto.')),
      ];
    } else {
      spans = [
        TextSpan(
            text: conf == 3
                ? '${L('Not quite · you were certain', 'No exactamente · estabas segura')}\n'
                : '${L('Not quite', 'No exactamente')} · ${_conf[conf]}\n',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                letterSpacing: 0.25,
                color: Color(0xFFD08B8B))),
        ...q.bad,
        if (conf == 3)
          TextSpan(
              text: L(
                  '\n\nBecause you were certain, I’ve marked this as a priority to revisit — it’s the most valuable kind of finding.',
                  '\n\nComo estabas segura, lo he marcado como prioridad para repasar — es el tipo de hallazgo más valioso.')),
      ];
    }

    _add(_SullyBubble(
      spans: spans,
      delay: 950,
      onGrew: _scrollDown,
      extra: _VerdictExtras(q: q),
    ));

    Timer(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      _add(_ContinueWrap(
        last: _qi >= _questions.length - 1,
        onContinue: _advance,
        onStop: _confirmStop,
      ));
    });
  }

  void _advance() {
    _qi++;
    if (_qi >= _questions.length) {
      setState(() => _progress = 1.0);
      Timer(const Duration(milliseconds: 350), _toDebrief);
    } else {
      _nextStep();
    }
  }

  void _confirmStop() {
    final remaining = _questions.length - 1 - _qi;
    final qword = remaining == 1
        ? L('one more question', 'una pregunta más')
        : L('$remaining more questions', '$remaining preguntas más');
    _add(_SullyBubble(
      delay: 900,
      onGrew: _scrollDown,
      spans: [
        TextSpan(
            text: L(
                'Are you sure you want to stop here? You have only $qword to go in this block — finishing it is what moves ',
                '¿Seguro que quieres parar aquí? Te quedan solo $qword en este bloque — terminarlo es lo que saca ')),
        TextSpan(
            text: L('Aircraft arrival & chocking', 'Llegada y calzado'),
            style: _ital),
        TextSpan(
            text: L(
                ' out of "Review soon". Stopping now records a partial session and slows your mastery.',
                ' de «Repasar pronto». Parar ahora registra una sesión parcial y frena tu dominio.')),
      ],
      extra: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _ChoiceChips(chips: [
            (L('Keep going', 'Seguir'), true, _advance),
            (L('Stop anyway', 'Parar igualmente'), false, _stopAnyway),
          ]),
        ],
      ),
    ));
  }

  void _stopAnyway() {
    _add(_SullyBubble(
      delay: 800,
      spans: [
        TextSpan(
            text: L(
                'Understood — I’ve recorded today’s attempts. We’ll pick this up exactly where you left it.',
                'Entendido — he registrado los intentos de hoy. Lo retomaremos exactamente donde lo dejaste.')),
      ],
    ));
    Timer(const Duration(milliseconds: 1900), _toDebrief);
  }

  void _toDebrief() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const TestuDebriefScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: t.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 10, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          L('LEARN MODE · RAMP SAFETY',
                              'MODO APRENDER · SEGURIDAD EN RAMPA'),
                          style: TextStyle(
                            fontFamily: 'GeistMono',
                            fontWeight: FontWeight.w500,
                            fontSize: 10.5,
                            letterSpacing: 1.47, // +0.14em
                            color: t.mut,
                          ),
                        ),
                      ),
                      TestuPressable(
                        onTap: () => Navigator.of(context).pop(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          child: Text('✕',
                              style: TextStyle(fontSize: 16, color: t.faint)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(end: _progress),
                      duration: const Duration(milliseconds: 600),
                      curve: TestuTokens.curve,
                      builder: (_, v, child) => TestuHairline(v,
                          trackColor: const Color(0xFF1E1E23)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 130),
                  // Fresh list each build: the delegate skips rebuilding when
                  // handed the same (mutated-in-place) instance.
                  children: List.of(_chat),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16, 26, 16, bottomInset + 22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.45],
                        colors: [t.bg.withValues(alpha: 0), t.bg],
                      ),
                    ),
                    // ponytail: decorative — free-text answers need a backend.
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 11, horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF101013),
                        border: Border.all(color: t.line2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        L('Ask Sully anything…',
                            'Pregunta a Sully lo que quieras…'),
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 12.5,
                          color: t.faint,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Entrance: fade + 10px rise, like the prototype's `up` keyframes.
class _Rise extends StatelessWidget {
  const _Rise({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: child),
      ),
      child: child,
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Opacity(
                opacity: _blink((_c.value - i * 0.16) % 1.0),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration:
                      BoxDecoration(color: t.faint, shape: BoxShape.circle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 0% .25 → 35% 1 → 70% .25, like the prototype's blink keyframes.
  double _blink(double p) {
    if (p < 0.35) return 0.25 + 0.75 * (p / 0.35);
    if (p < 0.70) return 1.0 - 0.75 * ((p - 0.35) / 0.35);
    return 0.25;
  }
}

/// Sully chat bubble: typing dots for [delay] ms, then the message (and
/// [extra] below it).
class _SullyBubble extends StatefulWidget {
  const _SullyBubble({
    required this.spans,
    this.extra,
    this.delay = 850,
    this.onGrew,
  });

  final List<InlineSpan> spans;
  final Widget? extra;
  final int delay;
  final VoidCallback? onGrew;

  @override
  State<_SullyBubble> createState() => _SullyBubbleState();
}

class _SullyBubbleState extends State<_SullyBubble> {
  late bool _revealed = widget.delay == 0;

  @override
  void initState() {
    super.initState();
    if (!_revealed) {
      Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) {
          setState(() => _revealed = true);
          widget.onGrew?.call();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return _Rise(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipOval(
              child: Image.asset('assets/img/sully.png',
                  width: 26, height: 26, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SULLY',
                    style: TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 9,
                      letterSpacing: 1.44, // +0.16em
                      color: t.faint,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (!_revealed)
                    const _TypingDots()
                  else ...[
                    Text.rich(
                      TextSpan(children: widget.spans),
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13.5,
                        height: 1.62,
                        color: Color(0xFFD6D4D0),
                      ),
                    ),
                    if (widget.extra != null) widget.extra!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip row that vanishes once one chip is tapped.
class _ChoiceChips extends StatefulWidget {
  const _ChoiceChips({required this.chips});

  final List<(String, bool, VoidCallback)> chips;

  @override
  State<_ChoiceChips> createState() => _ChoiceChipsState();
}

class _ChoiceChipsState extends State<_ChoiceChips> {
  bool _gone = false;

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    final t = TestuTokens.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, primary, onTap) in widget.chips)
          TestuPressable(
            onTap: () {
              setState(() => _gone = true);
              onTap();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              decoration: BoxDecoration(
                color: primary ? t.primaryAction : null,
                border:
                    Border.all(color: primary ? t.primaryAction : t.line2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 11.5,
                  fontWeight: primary ? FontWeight.w700 : FontWeight.w400,
                  color:
                      primary ? t.onPrimaryAction : const Color(0xFFC2C1BD),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ponytail: static thumb standing in for the prototype's embedded player —
// becomes a real video once sessions have a media backend.
class _FakePlayer extends StatelessWidget {
  const _FakePlayer();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: t.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/img/ramp.jpg', fit: BoxFit.cover),
                  const ColoredBox(color: Color(0x520A0A0B)),
                  Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0x960A0A0B),
                        shape: BoxShape.circle,
                      ),
                      child: const Text('▶',
                          style: TextStyle(
                              fontSize: 15, color: Color(0xFFECEBE7))),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
              color: t.card2,
              child: Text(
                L('Turnaround groundhandling, Frankfurt — demo footage · CC BY-SA Lufthansa Cargo',
                    'Handling de turnaround, Fráncfort — metraje de demo · CC BY-SA Lufthansa Cargo'),
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 9.5,
                  color: t.faint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Question card + its confidence bar. Tapping a confidence level submits.
class _QuestionCard extends StatefulWidget {
  const _QuestionCard({
    required this.q,
    required this.onGrew,
    required this.onHint,
    required this.onSubmit,
  });

  final _Q q;
  final VoidCallback onGrew;
  final VoidCallback onHint;
  final void Function(int chosen, int conf) onSubmit;

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  int? _sel;
  int? _confSel;
  bool _locked = false;

  void _pickOption(int i) {
    if (_locked) return;
    final grew = _sel == null;
    setState(() => _sel = i);
    if (grew) widget.onGrew();
  }

  Future<void> _pickConf(int c) async {
    if (_locked || _sel == null) return;
    if (!_confAcked) {
      HapticFeedback.heavyImpact();
      await _showConfAck(context);
      return; // like the prototype: re-tap a level after acknowledging
    }
    setState(() => _confSel = c);
    Timer(const Duration(milliseconds: 220), () {
      if (!mounted || _locked) return;
      setState(() => _locked = true);
      widget.onSubmit(_sel!, c);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final q = widget.q;
    return _Rise(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: t.card,
              border: Border.all(color: t.line2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.kicker,
                  style: TextStyle(
                    fontFamily: 'GeistMono',
                    fontSize: 9,
                    letterSpacing: 1.26, // +0.14em
                    color: t.faint,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  q.text,
                  style: const TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    letterSpacing: -0.16,
                    height: 1.42,
                    color: Color(0xFFEFEDEA),
                  ),
                ),
                const SizedBox(height: 14),
                if (q.image != null) ...[
                  // Prototype parity: question media is tappable to zoom.
                  q.diagram
                      ? GestureDetector(
                          onTap: () => showTestuZoom(context,
                              asset: q.image!, label: q.kicker),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2F1EC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Image.asset(q.image!, height: 150),
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: t.line),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                GestureDetector(
                                  onTap: () => showTestuZoom(context,
                                      asset: q.image!,
                                      label: q.caption ?? q.kicker),
                                  child:
                                      Image.asset(q.image!, fit: BoxFit.cover),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 7, horizontal: 11),
                                  color: t.card2,
                                  child: Text(
                                    q.caption!,
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 10,
                                      color: t.faint,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  const SizedBox(height: 14),
                ],
                for (var i = 0; i < q.opts.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _Option(
                      text: q.opts[i],
                      selected: _sel == i,
                      correct: _locked && i == q.okIdx,
                      wrong: _locked && i == _sel && i != q.okIdx,
                      onTap: () => _pickOption(i),
                    ),
                  ),
                if (!_locked)
                  TestuPressable(
                    onTap: widget.onHint,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        L('Request a hint', 'Pedir una pista'),
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 11.5,
                          color: t.mut,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFF3A3A40),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_sel != null) ...[
            const SizedBox(height: 8),
            _Rise(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L('HOW CONFIDENT ARE YOU?', '¿CÓMO DE SEGURA ESTÁS?'),
                    style: TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 9.5,
                      letterSpacing: 1.33, // +0.14em
                      color: t.faint,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: t.line2),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          for (var c = 0; c < 4; c++)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  _pickConf(c);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _confSel == c
                                        ? _confSelectedBg[c]
                                        : null,
                                    border: Border(
                                      top: BorderSide(
                                          color: _confColors[c], width: 2),
                                      right: c < 3
                                          ? BorderSide(color: t.line2)
                                          : BorderSide.none,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 11, horizontal: 2),
                                  child: Text(
                                    _conf[c],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                      color: _confColors[c],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.text,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final String text;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final Color border;
    final Color? bg;
    if (correct) {
      border = const Color(0xFF2F6A4C);
      bg = const Color(0xFF10201A);
    } else if (wrong) {
      border = const Color(0xFF6E3535);
      bg = const Color(0xFF201113);
    } else if (selected) {
      border = const Color(0xFFB9B7B2);
      bg = const Color(0xFF1A1A1E);
    } else {
      border = t.line2;
      bg = null;
    }
    final radioBorder = correct
        ? t.green
        : selected
            ? const Color(0xFFE9E8E4)
            : const Color(0xFF47474E);
    return TestuPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: radioBorder, width: 1.5),
              ),
              child: selected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE9E8E4),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xFFD6D4D0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Citation, evidence line, message actions, and follow-up chips under a
/// verdict — everything that makes the answer explainable.
class _VerdictExtras extends StatelessWidget {
  const _VerdictExtras({required this.q});

  final _Q q;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(13, 2, 0, 2),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: t.orange, width: 2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '“${q.quote}”',
                style: const TextStyle(
                  fontFamily: 'Sora',
                  fontSize: 12.5,
                  height: 1.62,
                  color: Color(0xFFDCDAD6),
                ),
              ),
              const SizedBox(height: 7),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${q.cite} · p. ${q.page} · '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () =>
                          showTestuPdf(context, page: q.page, cite: q.cite),
                      child: Text(
                        L('Open source', 'Abrir fuente'),
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 10.5,
                          color: t.blue,
                          decoration: TextDecoration.underline,
                          decorationColor: const Color(0xFF3D5C7D),
                        ),
                      ),
                    ),
                  ),
                ]),
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 10.5,
                  color: t.mut,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 9),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF101013),
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: L('Evidence recorded · Skill: ',
                      'Evidencia registrada · Habilidad: ')),
              TextSpan(text: q.skill, style: _evBold(t)),
              TextSpan(text: L(' · Competency: ', ' · Competencia: ')),
              TextSpan(text: q.comp, style: _evBold(t)),
              TextSpan(text: L('\nBehavior: ', '\nConducta: ')),
              TextSpan(text: '“${q.ob}”', style: _evBold(t)),
            ]),
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 10,
              height: 1.55,
              color: t.faint,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final a in [
              L('Helpful', 'Útil'),
              L('Not helpful', 'No útil'),
              L('Flag question', 'Reportar pregunta')
            ]) ...[
              TestuPressable(
                onTap: _noop,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    a,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 10.5,
                      letterSpacing: 0.42,
                      color: t.faint,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final label in [
              L('Why are the others wrong?', '¿Por qué las otras están mal?'),
              L('Show me the full procedure', 'Muéstrame el procedimiento completo')
            ])
              TestuPressable(
                onTap: _noop,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.line2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11.5,
                      color: Color(0xFFC2C1BD),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  TextStyle _evBold(TestuTokens t) =>
      TextStyle(fontWeight: FontWeight.w600, color: t.mut);
}

/// Continue / Stop here — vanishes once a choice is made.
class _ContinueWrap extends StatefulWidget {
  const _ContinueWrap({
    required this.last,
    required this.onContinue,
    required this.onStop,
  });

  final bool last;
  final VoidCallback onContinue;
  final VoidCallback onStop;

  @override
  State<_ContinueWrap> createState() => _ContinueWrapState();
}

class _ContinueWrapState extends State<_ContinueWrap> {
  bool _gone = false;

  void _pick(VoidCallback next) {
    setState(() => _gone = true);
    next();
  }

  @override
  Widget build(BuildContext context) {
    if (_gone) return const SizedBox.shrink();
    return _Rise(
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 18),
        child: Row(
          children: [
            Expanded(
              child: TestuButton(L('Continue', 'Continuar'),
                  variant: TestuButtonVariant.primary,
                  onTap: () => _pick(widget.onContinue)),
            ),
            if (!widget.last) ...[
              const SizedBox(width: 9),
              Expanded(
                child: TestuButton(L('Stop here', 'Parar aquí'),
                    onTap: () => _pick(widget.onStop)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// First confidence tap: the tap-submits rule, from Sully, once.
Future<void> _showConfAck(BuildContext context) {
  final t = TestuTokens.of(context);
  return showDialog(
    context: context,
    barrierColor: const Color(0xA8000000),
    builder: (context) => Dialog(
      backgroundColor: t.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: t.line2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipOval(
                  child: Image.asset('assets/img/sully.png',
                      width: 26, height: 26, fit: BoxFit.cover),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SULLY',
                        style: TextStyle(
                          fontFamily: 'GeistMono',
                          fontSize: 9,
                          letterSpacing: 1.44,
                          color: t.faint,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text.rich(
                        TextSpan(children: [
                          TextSpan(
                              text: L(
                                  'Quick heads-up before your first confidence call: ',
                                  'Un aviso antes de tu primera llamada de confianza: ')),
                          TextSpan(
                              text: L(
                                  'the moment you tap a level, your answer is submitted',
                                  'en cuanto toques un nivel, tu respuesta queda enviada'),
                              style: _bold),
                          TextSpan(
                              text: L(
                                  ' — there’s no changing it afterwards. Your confidence is part of the answer, so decide it like you would on the ramp.',
                                  ' — no se puede cambiar después. Tu confianza es parte de la respuesta, así que decídela como lo harías en la rampa.')),
                        ]),
                        style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 13.5,
                          height: 1.62,
                          color: Color(0xFFD6D4D0),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TestuButton(
              L('Understood — don’t show this again',
                  'Entendido — no volver a mostrar'),
              variant: TestuButtonVariant.primary,
              onTap: () {
                _confAcked = true;
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

/// Debrief — "end with meaning, not a score".
class TestuDebriefScreen extends StatelessWidget {
  const TestuDebriefScreen({super.key});

  void _leave(BuildContext context, int tab) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    TestuShell.tabRequest.value = tab;
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
              18, 24, 18, MediaQuery.paddingOf(context).bottom + 40),
          children: [
            TestuEyebrow(
                L('SESSION COMPLETE · LEARN MODE',
                    'SESIÓN COMPLETADA · MODO APRENDER'),
                color: t.orange),
            const SizedBox(height: 10),
            Text(
              L('Here’s what today’s session means, Ana.',
                  'Esto es lo que significa la sesión de hoy, Ana.'),
              style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w700,
                fontSize: 22,
                letterSpacing: -0.22,
                height: 1.25,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 20),
            _SullyBubble(
              delay: 0,
              spans: [
                TextSpan(
                    text: L(
                        'Solid work. Your arrival & chocking knowledge is consolidating — you were right ',
                        'Buen trabajo. Tu conocimiento de llegada y calzado se está consolidando — acertaste ')),
                TextSpan(text: L('and', 'y'), style: _ital),
                TextSpan(
                    text: L(
                        ' certain on 5 of 6. One misconception surfaced, and that’s the most valuable find of the day.',
                        ' con seguridad en 5 de 6. Apareció un concepto erróneo, y ese es el hallazgo más valioso del día.')),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                _Stat(L('CORRECT', 'CORRECTAS'),
                    child: _statMono('8 / 10', t.ink)),
                const SizedBox(width: 9),
                _Stat(L('CALIBRATION', 'CALIBRACIÓN'),
                    child: _statMono('82%', t.ink)),
                const SizedBox(width: 9),
                _Stat(L('MASTERY', 'DOMINIO'),
                    child: const Text(
                      'Competent · Strong ↑',
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Color(0xFF7DBB9C),
                      ),
                    )),
              ],
            ),
            const SizedBox(height: 18),
            TestuCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _DebriefRow(
                    color: const Color(0xFF4CA97A),
                    title: L('Reinforced · Aircraft arrival & chocking',
                        'Reforzado · Llegada y calzado'),
                    body: L(
                        'Certain and correct across the sequence — consolidated.',
                        'Segura y correcta en toda la secuencia — consolidado.'),
                  ),
                  _DebriefRow(
                    color: const Color(0xFFC25555),
                    title: L('Misconception · Chock timing',
                        'Concepto erróneo · Momento de calzar'),
                    body: L(
                        'Incorrect while certain. Sully scheduled this for tomorrow’s Daily Challenge.',
                        'Incorrecta estando segura. Sully lo ha programado para el Reto Diario de mañana.'),
                  ),
                  _DebriefRow(
                    color: const Color(0xFFE8703A),
                    title: L('Fragile · FOD reporting chain',
                        'Frágil · Cadena de notificación FOD'),
                    body: L(
                        'Correct, but you marked it "Unsure". This knowledge may not be fully consolidated yet.',
                        'Correcta, pero la marcaste como «Insegura». Puede que este conocimiento aún no esté consolidado.'),
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TestuCard(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L('MASTERY · RAMP SAFETY', 'DOMINIO · SEGURIDAD EN RAMPA'),
                    style: TextStyle(
                      fontFamily: 'GeistMono',
                      fontWeight: FontWeight.w500,
                      fontSize: 9,
                      letterSpacing: 1.26,
                      color: t.faint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (_, box) => CustomPaint(
                      size: Size(box.maxWidth, box.maxWidth * 92 / 320),
                      painter: const _CurvePainter(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TestuButton(L('SEE WHAT CHANGED', 'VER QUÉ HA CAMBIADO'),
                variant: TestuButtonVariant.primary,
                onTap: () => _leave(context, 3)),
            const SizedBox(height: 10),
            TestuButton(L('Done for today', 'Terminar por hoy'),
                onTap: () => _leave(context, 0)),
          ],
        ),
      ),
    );
  }

  static Widget _statMono(String v, Color color) => Text(
        v,
        style: TextStyle(
          fontFamily: 'GeistMono',
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: color,
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, {required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Expanded(
      child: TestuCard(
        padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'GeistMono',
                fontSize: 8.5,
                letterSpacing: 1.02, // +0.12em
                color: t.faint,
              ),
            ),
            const SizedBox(height: 6),
            child,
          ],
        ),
      ),
    );
  }
}

class _DebriefRow extends StatelessWidget {
  const _DebriefRow({
    required this.color,
    required this.title,
    required this.body,
    this.last = false,
  });

  final Color color;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF17171A)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Geist',
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                    color: Color(0xFFE9E8E4),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 11.5,
                    height: 1.5,
                    color: t.mut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The prototype's mastery-curve SVG, ported: labels, dashed required line,
/// green trajectory, orange "you are here" dot.
class _CurvePainter extends CustomPainter {
  const _CurvePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 320;

    void label(String text, double x, double y, double fs) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: fs * s,
            color: const Color(0xFF5C6068),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // SVG text y is the baseline.
      tp.paint(canvas, Offset(x * s, y * s - tp.height));
    }

    label(L('Expert', 'Experto'), 2, 12, 9);
    label(L('Competent', 'Competente'), 2, 50, 9);
    label(L('Beginner', 'Principiante'), 2, 88, 9);
    label(L('required · Expert', 'requerido · Experto'), 230, 16, 8.5);

    final dash = Paint()
      ..color = const Color(0xFF26262C)
      ..strokeWidth = 1;
    var x = 58.0 * s;
    while (x < 320 * s) {
      canvas.drawLine(Offset(x, 22 * s), Offset(x + 3 * s, 22 * s), dash);
      x += 7 * s;
    }

    const pts = [(62.0, 84.0), (108.0, 72.0), (154.0, 60.0), (200.0, 50.0),
        (246.0, 42.0), (288.0, 34.0)];
    final path = Path()..moveTo(pts.first.$1 * s, pts.first.$2 * s);
    for (final (px, py) in pts.skip(1)) {
      path.lineTo(px * s, py * s);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * s
        ..color = const Color(0xFF4CA97A),
    );
    canvas.drawCircle(Offset(288 * s, 34 * s), 4.5 * s,
        Paint()..color = const Color(0xFFE8703A));
  }

  @override
  bool shouldRepaint(_CurvePainter old) => false;
}

// ponytail: feedback actions and follow-up chips are decorative until the
// tutor backend exists.
void _noop() {}
