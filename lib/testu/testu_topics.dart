import 'dart:ui';

import 'package:eme_app_package/models/topic.dart';
import 'package:flutter/material.dart';

import 'testu_i18n.dart';
import 'testu_live.dart';
import 'testu_resources.dart';
import 'testu_session.dart';
import 'testu_social.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';
import 'testu_client.dart';

// ---------------------------------------------------------------------------
// Topics tab — role topic list (spec: prototype v6 scr-topics).
// ---------------------------------------------------------------------------

typedef _Topic = ({
  String img,
  String title,
  String sub,
  String pill,
  Color pillColor,
  Color pillBorder,
  bool opens,
  String? id, // live topic id; null for demo rows
});

class TestuTopicsScreen extends StatelessWidget {
  const TestuTopicsScreen({super.key});

  static List<_Topic> get _topics => [
    (img: 'ramp.jpg',
     title: L('Ramp Safety & Aircraft Turnaround',
         'Seguridad en Rampa y Turnaround'),
     sub: L('Learn Mode · 21 of 36 questions',
         'Modo Aprender · 21 de 36 preguntas'),
     pill: L('Competent · Review soon', 'Competente · Repasar pronto'),
     pillColor: const Color(0xFFCDB96A),
     pillBorder: const Color(0xFF8A7A3A), opens: true, id: null),
    (img: 'chocks.jpg', title: L('FOD Prevention', 'Prevención de FOD'),
     sub: L('Improve Mode available', 'Modo Mejorar disponible'),
     pill: L('Expert · Stable', 'Experto · Estable'),
     pillColor: const Color(0xFF7DBB9C),
     pillBorder: const Color(0xFF2F6A4C), opens: false, id: null),
    (img: 'radio.jpg',
     title: L('Radio Communication & Phraseology',
         'Comunicación por Radio y Fraseología'),
     sub: L('${client.tutor} recommends 10 min today',
         '${client.tutor} recomienda 10 min hoy'),
     pill: L('Competent · At risk', 'Competente · En riesgo'),
     pillColor: const Color(0xFFD9A23F),
     pillBorder: const Color(0xFF7A5C1E), opens: false, id: null),
    (img: 'marshal.jpg',
     title: L('Ground Guidance & Marshalling',
         'Guiado en Tierra y Señalización'),
     sub: L('${client.tutor} suggests Learn Mode this week',
         '${client.tutor} sugiere Modo Aprender esta semana'),
     pill: L('Beginner · Needs practice', 'Principiante · Necesita práctica'),
     pillColor: const Color(0xFFD08B8B),
     pillBorder: const Color(0xFF6E3535), opens: false, id: null),
    (img: 'cargo.jpg',
     title: L('Dangerous Goods Awareness',
         'Conciencia de Mercancías Peligrosas'),
     sub: L('Recertification due Nov 2026',
         'Recertificación antes de nov 2026'),
     pill: L('Competent · Stable', 'Competente · Estable'),
     pillColor: const Color(0xFF7DBB9C),
     pillBorder: const Color(0xFF2F6A4C), opens: false, id: null),
    (img: 'winter.jpg',
     title: L('Aircraft De-icing Procedures',
         'Procedimientos de Deshielo'),
     sub: L('Seasonal · opens Oct 1', 'Estacional · abre el 1 oct'),
     pill: L('Not started', 'Sin empezar'),
     pillColor: const Color(0xFF8B8F98),
     pillBorder: const Color(0xFF2C2C33), opens: false, id: null),
    (img: 'fire.jpg',
     title: L('Emergency Response & Fire Safety',
         'Respuesta a Emergencias y Contra Incendios'),
     sub: L('Annual refresher · due Jan 2027',
         'Repaso anual · antes de ene 2027'),
     pill: L('Competent · Strong', 'Competente · Sólido'),
     pillColor: const Color(0xFF7DBB9C),
     pillBorder: const Color(0xFF2F6A4C), opens: false, id: null),
  ];

  @override
  Widget build(BuildContext context) =>
      testuLive ? const _LiveTopics() : _topicsBody(context, _topics);
}

/// Live variant: one fetch, hardcoded rows as the error/empty state.
class _LiveTopics extends StatefulWidget {
  const _LiveTopics();

  @override
  State<_LiveTopics> createState() => _LiveTopicsState();
}

class _LiveTopicsState extends State<_LiveTopics> {
  // Built once — inline in build() would refetch on every rebuild.
  final Future<List<Topic>> _future = loadLiveTopics();

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Topic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return _topicsBody(context, const []);
          }
          final live = snap.data ?? const <Topic>[];
          if (snap.hasError || live.isEmpty) {
            debugPrint('TestU: live topics unavailable (${snap.error})');
            return _topicsBody(context, TestuTopicsScreen._topics);
          }
          return _topicsBody(context, [
            for (var i = 0; i < live.length; i++) _mapTopic(live[i], i),
          ]);
        },
      );
}

/// `Topic` → the row record `_TopicRow` already renders. The server's
/// thumbnail when it has one, else a bundled picture.
const _imgs = ['ramp.jpg', 'chocks.jpg', 'radio.jpg', 'marshal.jpg',
    'cargo.jpg', 'winter.jpg', 'fire.jpg'];

/// `img` is a bundled file name for prototype rows and an absolute URL for
/// live ones.
ImageProvider _topicImage(String img) =>
    testuImage(img.startsWith('http') ? img : 'assets/img/$img');

/// The Today hero's slice of a live topic: cover URL plus the fields it
/// needs to open the topic's Home. Public so [testu_shell] can render the
/// same backend cover the Topics list shows.
typedef LiveTopicHead = ({
  String img,
  String? id,
  String title,
  String pill,
  Color pillColor,
  Color pillBorder,
});

/// The primary live topic — the first that opens (has tutorials). Null when
/// live topics are unavailable/empty, so the Today hero keeps its bundled
/// placeholder. Its own fetch: the Topics list keeps a per-visit fetch so
/// progress there stays fresh after a session.
Future<LiveTopicHead?> primaryLiveTopic() async {
  final live = await loadLiveTopics();
  for (var i = 0; i < live.length; i++) {
    final r = _mapTopic(live[i], i);
    if (r.opens) {
      return (
        img: r.img,
        id: r.id,
        title: r.title,
        pill: r.pill,
        pillColor: r.pillColor,
        pillBorder: r.pillBorder,
      );
    }
  }
  return null;
}

_Topic _mapTopic(Topic t, int i) {
  final (pill, color, border) = switch (t.progress.getEfficiency()) {
    Efficiency.beginner => (
        L('Beginner', 'Principiante'),
        const Color(0xFFD08B8B),
        const Color(0xFF6E3535)
      ),
    Efficiency.competent => (
        L('Competent', 'Competente'),
        const Color(0xFFCDB96A),
        const Color(0xFF8A7A3A)
      ),
    Efficiency.expert => (
        L('Expert', 'Experto'),
        const Color(0xFF7DBB9C),
        const Color(0xFF2F6A4C)
      ),
  };
  return (
    // The server hands out the 200x200 rendition; the hero wants the large
    // one, which the same generated path serves.
    img: t.thumbnail.isEmpty
        ? _imgs[i % _imgs.length]
        : liveAssetUrl(
            t.thumbnail.replaceFirst('image200x200', 'image3000x3000')),
    title: t.title,
    sub: L(
        '${t.totalTutorials} tutorials · ${t.completedSections} of ${t.totalSections} sections',
        '${t.totalTutorials} tutoriales · ${t.completedSections} de ${t.totalSections} secciones'),
    pill: pill,
    pillColor: color,
    pillBorder: border,
    // A topic with no tutorials has no questions; opening it would drop the
    // session into the offline demo under this topic's name.
    opens: t.totalTutorials > 0,
    id: t.id,
  );
}

Widget _topicsBody(BuildContext context, List<_Topic> topics) {
    final t = TestuTokens.of(context);
    // Pinned header; only the topic list scrolls (user-requested cutoff at
    // the header's bottom edge).
    return SafeArea(
      bottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L('Your topics', 'Tus temas'),
                    style: const TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w700,
                      fontSize: 21,
                      letterSpacing: -0.21,
                      color: Color(0xFFECEBE7),
                    )),
                const SizedBox(height: 4),
                Text(
                  L('Ramp Agent, Safety Lead · 6 required for your role · 1 seasonal',
                      'Agente de Rampa, Líder de Seguridad · 6 obligatorios para tu rol · 1 estacional'),
                  style: TextStyle(
                      fontFamily: 'Geist', fontSize: 11.5, color: t.mut),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 10, bottom: 110),
              children: [
                for (final topic in topics)
                  _TopicRow(
                    topic: topic,
                    // ponytail: in the demo only Ramp Safety has a Topic
                    // Home; the rest just give press feedback, like the
                    // prototype. A live row opens one when its topic has
                    // tutorials.
                    onTap: topic.opens
                        ? () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TestuTopicHomeScreen(
                                  topicId: topic.id,
                                  title: topic.title,
                                  img: topic.img,
                                  pill: topic.pill,
                                  pillColor: topic.pillColor,
                                  pillBorder: topic.pillBorder,
                                )))
                        : _nothing,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
}

void _nothing() {}

class _TopicRow extends StatelessWidget {
  const _TopicRow({required this.topic, required this.onTap});

  final _Topic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuPressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: t.card2,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Image(
                    image: _topicImage(topic.img), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.title,
                      style: const TextStyle(
                        fontFamily: 'Geist',
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: Color(0xFFECEBE7),
                      )),
                  const SizedBox(height: 4),
                  Text(topic.sub,
                      style: kMeta),
                  const SizedBox(height: 5),
                  TestuPill(topic.pill,
                      color: topic.pillColor, borderColor: topic.pillBorder),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('›', style: TextStyle(fontSize: 14, color: t.faint)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topic Home (spec: prototype v6 scr-topic, Ramp Safety). Pushed full-screen
// over the shell; no bottom nav, back chevron over the hero. The hero wears
// the row that opened it; the panes below are still the prototype's Ramp
// Safety content until the backend has subtopics and resources.
// ---------------------------------------------------------------------------

class TestuTopicHomeScreen extends StatefulWidget {
  const TestuTopicHomeScreen({
    super.key,
    this.topicId,
    this.title,
    this.img = 'ramp.jpg',
    this.pill,
    this.pillColor = const Color(0xFFCDB96A),
    this.pillBorder = const Color(0xFF8A7A3A),
  });

  /// Live topic the session CTAs draw questions from; null → first topic.
  final String? topicId;
  final String? title; // null → the prototype's Ramp Safety title
  final String img;
  final String? pill; // null → the prototype's pill
  final Color pillColor;
  final Color pillBorder;

  @override
  State<TestuTopicHomeScreen> createState() => _TestuTopicHomeScreenState();
}

class _TestuTopicHomeScreenState extends State<TestuTopicHomeScreen> {
  int _tab = 0;
  final Set<int> _openCmp = {};
  final Set<int> _openSub = {};
  late final List<TestuComment> _reviews = _mockReviews();

  List<String> get _tabsL => [
        L('Overview', 'Resumen'),
        L('Subtopics', 'Subtemas'),
        L('Resources', 'Recursos'),
        L('Review', 'Reseñas'),
      ];

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      // Hero + tabs stay pinned; only the active pane scrolls under the
      // tab bar's hairline (the "cutoff line").
      body: Column(children: [
        const _TopicHero(),
        // Tabs — instant pane swap, like the prototype.
        Container(
            // Full width so the tab row hugs the left edge — shrink-wrapped
            // it floats centered on wide (landscape) screens.
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.line))),
            // Scrolls instead of overflowing on narrow devices / long labels.
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
              children: [
                for (var i = 0; i < _tabsL.length; i++)
                  TestuPressable(
                    onTap: () => setState(() => _tab = i),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            width: 2,
                            color: i == _tab ? t.orange : Colors.transparent,
                          ),
                        ),
                      ),
                      child: Text(
                        _tabsL[i],
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          letterSpacing: 0.24,
                          color: i == _tab ? const Color(0xFFE9E8E4) : t.faint,
                        ),
                      ),
                    ),
                  ),
              ],
              ),
            ),
          ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.only(
                bottom: 28 + MediaQuery.paddingOf(context).bottom),
            children: switch (_tab) {
              0 => _overview(t),
              1 => _subtopics(t),
              2 => _resources(t),
              _ => _review(t),
            },
          ),
        ),
      ]),
    );
  }

  // ---- Overview ----

  List<Widget> _overview(TestuTokens t) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          // Readable measure in landscape — full-width 13px prose runs
          // 120+ characters per line.
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(
            L('Safe aircraft turnaround on stand: preparation, FOD inspection, '
                    'arrival, GSE positioning and departure. Required for your '
                    "role because ramp incidents are the airline's largest "
                    'ground-safety exposure.',
                'Turnaround seguro de la aeronave en el stand: preparación, '
                    'inspección FOD, llegada, posicionamiento de GSE y salida. '
                    'Obligatorio para tu rol porque los incidentes en rampa '
                    'son la mayor exposición de seguridad en tierra de la '
                    'aerolínea.'),
            style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 13,
                height: 1.65,
                color: Color(0xFFB9B8B4)),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Column(
            children: [
              // IntrinsicHeight + stretch = both cards in a row share the
              // taller card's height (2×2 grid symmetry).
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        child: _Fact(L('CURRENT MASTERY', 'DOMINIO ACTUAL'),
                            L('Competent · Strong', 'Competente · Sólido'),
                            sub: L('Review soon', 'Repasar pronto'),
                            valueColor: t.gold)),
                    const SizedBox(width: 9),
                    Expanded(
                        child: _Fact(L('REQUIRED LEVEL', 'NIVEL REQUERIDO'),
                            L('Expert', 'Experto'),
                            sub: L('Required for your Safety Lead assignment',
                                'Requerido para tu puesto de Líder de Seguridad'),
                            subUnderline: true)),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                        child: _Fact(L('PROGRESS', 'PROGRESO'),
                            L('21 of 36', '21 de 36'),
                            sub: L('15 questions left in Learn Mode',
                                '15 preguntas restantes en Modo Aprender'))),
                    const SizedBox(width: 9),
                    Expanded(
                        child: _Fact(
                            L('RETENTION STABILITY', 'ESTABILIDAD DE RETENCIÓN'),
                            L('Stable', 'Estable'),
                            sub: L('Nothing forgotten so far',
                                'Nada olvidado por ahora'),
                            valueColor: t.greenText)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: _CompetenciesCard(
            open: _openCmp,
            onToggle: (i) => setState(() =>
                _openCmp.contains(i) ? _openCmp.remove(i) : _openCmp.add(i)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Row(children: [
            TestuPill(L('Certificate · Valid', 'Certificado · Válido'),
                color: const Color(0xFF7DBB9C),
                borderColor: const Color(0xFF2F6A4C)),
            const SizedBox(width: 10),
            // Flexible: Spanish copy is wider than the row at 390pt.
            Flexible(
                child: Text(
                    L('Renewal evaluation due in 12 days',
                        'Evaluación de renovación en 12 días'),
                    style: TextStyle(
                        fontFamily: 'Geist', fontSize: 12, color: t.mut))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
          child: TestuButton(
              L('CONTINUE WITH YOUR TUTOR', 'CONTINUAR CON TU TUTOR'),
              variant: TestuButtonVariant.primary,
              onTap: () =>
                  showTestuSession(context, topicId: widget.topicId)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          child: TestuButton(L('Review progress', 'Ver progreso'),
              onTap: _nothing),
        ),
      ];

  // ---- Subtopics ----

  static List<_SubGroup> get _groups {
    final learn = L('Learn', 'Aprender');
    final improve = L('Improve', 'Mejorar');
    final expertStable = L('Expert · Stable', 'Experto · Estable');
    final notStarted = L('Not started', 'Sin empezar');
    return [
      (dot: _Dot.green,
       title: L('Stand preparation', 'Preparación del stand'),
       sub: '$expertStable · ${L('8 of 8 questions', '8 de 8 preguntas')}',
       mode: improve, primary: false, critical: false,
       kids: [
         (dot: _Dot.green,
          title: L('Cone & barrier placement',
              'Colocación de conos y barreras'),
          sub: '$expertStable · 3 ${L('of', 'de')} 3', mode: improve,
          critical: false),
         (dot: _Dot.green,
          title: L('Stand surface & markings check',
              'Revisión de superficie y marcas'),
          sub: '$expertStable · 3 ${L('of', 'de')} 3', mode: improve,
          critical: false),
         (dot: _Dot.green,
          title: L('Equipment staging', 'Preparación de equipos'),
          sub: L('Competent · Stable · 2 of 2',
              'Competente · Estable · 2 de 2'),
          mode: improve, critical: false),
       ]),
      (dot: _Dot.green, title: L('FOD inspection', 'Inspección FOD'),
       sub: '$expertStable · ${L('7 of 7 questions', '7 de 7 preguntas')}',
       mode: improve, primary: false, critical: false,
       kids: [
         (dot: _Dot.green,
          title: L('FOD walk pattern', 'Patrón de inspección FOD'),
          sub: '$expertStable · 4 ${L('of', 'de')} 4', mode: improve,
          critical: false),
         (dot: _Dot.orange,
          title: L('Reporting chain', 'Cadena de notificación'),
          sub: L('Competent · Fragile · 3 of 3',
              'Competente · Frágil · 3 de 3'),
          mode: learn, critical: false),
       ]),
      (dot: _Dot.orange,
       title: L('Aircraft arrival & chocking', 'Llegada y calzado'),
       sub: L('Competent · Review soon · 5 of 8 questions',
           'Competente · Repasar pronto · 5 de 8 preguntas'),
       mode: learn, primary: false, critical: false,
       kids: [
         (dot: _Dot.orange,
          title: L('Approach & anti-collision lights',
              'Aproximación y luces anticolisión'),
          sub: L('Competent · Review soon · 3 of 4',
              'Competente · Repasar pronto · 3 de 4'),
          mode: learn, critical: false),
         (dot: _Dot.red,
          title: L('Chock timing & sequence',
              'Momento y secuencia de calzado'),
          sub: L('Beginner · Misconception flagged · 2 of 4 · requires Expert',
              'Principiante · Concepto erróneo · 2 de 4 · requiere Experto'),
          mode: learn, critical: true),
       ]),
      (dot: _Dot.red,
       title: L('GSE positioning', 'Posicionamiento de GSE'),
       sub: L('Beginner · Needs practice · 1 of 7 questions',
           'Principiante · Necesita práctica · 1 de 7 preguntas'),
       mode: learn, primary: true, critical: false,
       kids: [
         (dot: _Dot.red,
          title: L('Belt loader approach', 'Aproximación de cinta cargadora'),
          sub: L('Beginner · Needs practice · 1 of 3',
              'Principiante · Necesita práctica · 1 de 3'),
          mode: learn, critical: false),
         (dot: _Dot.idle,
          title: L('GPU connection clearances', 'Distancias de conexión GPU'),
          sub: '$notStarted · 0 ${L('of', 'de')} 2', mode: learn,
          critical: false),
         (dot: _Dot.idle,
          title: L('Safety cones around GSE',
              'Conos de seguridad alrededor del GSE'),
          sub: '$notStarted · 0 ${L('of', 'de')} 2', mode: learn,
          critical: false),
       ]),
      (dot: _Dot.idle,
       title: L('Pushback & departure', 'Pushback y salida'),
       sub: '$notStarted · ${L('0 of 6 questions', '0 de 6 preguntas')}',
       mode: learn, primary: false, critical: false,
       kids: [
         (dot: _Dot.idle,
          title: L('Towbar & bypass pin', 'Barra de remolque y bypass pin'),
          sub: '$notStarted · 0 ${L('of', 'de')} 3', mode: learn,
          critical: false),
         (dot: _Dot.idle,
          title: L('Departure signals', 'Señales de salida'),
          sub: '$notStarted · 0 ${L('of', 'de')} 3', mode: learn,
          critical: false),
       ]),
    ];
  }

  List<Widget> _subtopics(TestuTokens t) => [
        for (var i = 0; i < _groups.length; i++)
          _SubGroupWidget(
            group: _groups[i],
            open: _openSub.contains(i),
            onToggle: () => setState(() =>
                _openSub.contains(i) ? _openSub.remove(i) : _openSub.add(i)),
          ),
      ];

  // ---- Resources ----

  List<Widget> _resources(TestuTokens t) => [
        _ResRow(icon: 'PDF',
            title: CL('Human Rights Policy', 'Política de Derechos Humanos',
                'Ground Operations Manual', 'Manual de Operaciones en Tierra'),
            sub: L('Pages: 122 of 305 · viewed 27 times',
                'Páginas: 122 de 305 · visto 27 veces'),
            required: true,
            onTap: () => showTestuResource(context, 'gom')),
        _ResRow(icon: 'VID',
            title: CL('Due diligence walkthrough', 'Recorrido de debida diligencia',
                'Turnaround walkthrough', 'Recorrido del turnaround'),
            sub: L('Chapter 1 of 5 watched · viewed twice',
                'Capítulo 1 de 5 visto · visto dos veces'),
            required: false,
            onTap: () => showTestuResource(context, 'vid')),
        _ResRow(icon: 'DOC',
            title: CL('Compliance notice 2026-14: grievance channel update',
                'Aviso de cumplimiento 2026-14: cambio en el canal de reclamos',
                'Station notice 2026-14: chocking update',
                'Aviso de estación 2026-14: cambio de calzado'),
            sub: L('Pages: 0 of 2 · unread · effective Aug 1',
                'Páginas: 0 de 2 · sin leer · vigente desde el 1 ago'),
            required: true,
            onTap: () => showTestuResource(context, 'notice')),
      ];

  // ---- Review ----

  /// The topic's review tab IS the house thread (full-alignment rule:
  /// vote, reply, report work here exactly like the question conversation).
  List<Widget> _review(TestuTokens t) => [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: TestuThread(
            comments: _reviews,
            composerHint: L('Add a review or comment…',
                'Añade una reseña o comentario…'),
            reportEyebrow: L('REVIEWS · REPORT', 'RESEÑAS · REPORTAR'),
            reportTitle: L('Report this review', 'Reportar esta reseña'),
          ),
        ),
      ];
}

List<TestuComment> _mockReviews() {
  final karsten = TestuComment(
      'Karsten B.',
      L('COORDINATOR', 'COORDINADOR'),
      'assets/img/p_karsten.jpg',
      L('Suggest adding a night-operations variant for GSE positioning.',
          'Sugiero añadir una variante nocturna para el posicionamiento de GSE.'),
      reacts: {TestuReaction.like: 1, TestuReaction.idea: 1});
  karsten.replies.add(TestuComment(
      client.tutor,
      L('AI TUTOR', 'TUTOR IA'),
      client.tutorAvatar,
      L('Logged — I passed the night-operations suggestion to the content team.',
          'Anotado — he pasado la sugerencia de operaciones nocturnas al equipo de contenido.')));
  return [
    TestuComment(
        'Miranda J.',
        L('SHIFT LEAD', 'JEFA DE TURNO'),
        'assets/img/p_miranda.jpg',
        L('The arrival & chocking questions match the new station notice — good update since July.',
            'Las preguntas de llegada y calzado coinciden con el nuevo aviso de estación — buena actualización desde julio.'),
        reacts: {TestuReaction.like: 4, TestuReaction.applause: 1}),
    karsten,
  ];
}

class _TopicHero extends StatelessWidget {
  const _TopicHero();

  @override
  Widget build(BuildContext context) {
    // Hero copy comes from the Topic Home that owns it.
    final home =
        context.findAncestorWidgetOfExactType<TestuTopicHomeScreen>()!;
    final t = TestuTokens.of(context);
    final topPad = MediaQuery.paddingOf(context).top;
    return SizedBox(
      // 300 in portrait (approved v6); in landscape the pinned hero would
      // swallow the screen and leave the tab panes nothing to scroll in,
      // so it shrinks to a share of the height instead.
      height: (MediaQuery.sizeOf(context).height * 0.38).clamp(0.0, 300.0),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(image: _topicImage(home.img),
              fit: BoxFit.cover,
              alignment: const Alignment(0, 0.24)), // center 62%
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.34, 0.94],
                colors: [
                  Color(0x3D0A0A0B),
                  Color(0x100A0A0B),
                  Color(0xFB0A0A0B),
                ],
              ),
            ),
          ),
          Positioned(
            top: topPad + 8,
            // Right side: the pill/title/meta stack owns the hero's left,
            // and in landscape the arrow was crowding it.
            right: 16 + MediaQuery.paddingOf(context).right,
            child: TestuPressable(
              onTap: () => Navigator.of(context).pop(),
              child: ClipOval(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 34,
                    height: 34,
                    color: const Color(0x960A0A0B),
                    alignment: Alignment.center,
                    child: const Text('‹',
                        style: TextStyle(
                            fontSize: 14, color: Color(0xFFECEBE7))),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TestuPill(
                    home.pill ??
                        L('Competent · Review soon',
                            'Competente · Repasar pronto'),
                    color: home.pillColor,
                    borderColor: home.pillBorder),
                const SizedBox(height: 12),
                Text(
                    home.title ??
                        L('Ramp Safety & Aircraft Turnaround',
                            'Seguridad en Rampa y Turnaround'),
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w700,
                      fontSize: 21,
                      letterSpacing: -0.21,
                      height: 1.2,
                      color: t.ink,
                    )),
                const SizedBox(height: 8),
                Row(children: [
                  ClipOval(
                    child: Image.asset(client.tutorAvatar,
                        width: 22, height: 22, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 8),
                  Text(
                      L('With ${client.tutor} · 36 questions · 5 subtopics',
                          'Con ${client.tutor} · 36 preguntas · 5 subtemas'),
                      style: const TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 12,
                          color: Color(0xFFB5B4B0))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value,
      {required this.sub, this.valueColor, this.subUnderline = false});

  final String label;
  final String value;
  final String sub;
  final Color? valueColor;
  final bool subUnderline;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuCard(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 9,
                  letterSpacing: 1.08,
                  color: t.faint)),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                  fontFamily: 'Geist',
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: valueColor ?? const Color(0xFFE6E4E0))),
          const SizedBox(height: 3),
          Text(sub,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 10.5,
                color: t.mut,
                decoration:
                    subUnderline ? TextDecoration.underline : null,
                decorationColor: const Color(0xFF3A3A40),
              )),
        ],
      ),
    );
  }
}

// ---- Competencies (role architecture: expandable groups + behaviors) ----

enum _Evidence { ok, mid, no }

typedef _Behavior = ({_Evidence st, String text, String sub});

class _CompetenciesCard extends StatelessWidget {
  const _CompetenciesCard({required this.open, required this.onToggle});

  final Set<int> open;
  final ValueChanged<int> onToggle;

  static List<
      ({String title, String sub, String pill, bool strong,
        List<_Behavior> kids})> get _cmp => [
    (title: L('Safe aircraft handling', 'Manejo seguro de la aeronave'),
     sub: L('Evidence strong · 3 of 4 behaviors evidenced',
         'Evidencia sólida · 3 de 4 conductas evidenciadas'),
     pill: L('Strong', 'Sólido'), strong: true,
     kids: [
       (st: _Evidence.ok,
        text: L('Positions chocks only after engines are shut down and '
                'anti-collision lights are off',
            'Coloca los calzos solo con motores apagados y luces '
                'anticolisión apagadas'),
        sub: L('Evidenced · 12 attempts, certain & correct',
            'Evidenciado · 12 intentos, seguro y correcto')),
       (st: _Evidence.ok,
        text: L('Performs a FOD walk before every aircraft arrival',
            'Realiza una inspección FOD antes de cada llegada'),
        sub: L('Evidenced · 9 attempts', 'Evidenciado · 9 intentos')),
       (st: _Evidence.ok,
        text: L('Follows main-gear-first chocking sequence per station '
                'notice 2026-14',
            'Sigue la secuencia de calzado tren-principal-primero según el '
                'aviso 2026-14'),
        sub: L('Evidenced · 5 attempts', 'Evidenciado · 5 intentos')),
       (st: _Evidence.mid,
        text: L('Reports FOD findings through the correct chain',
            'Notifica los hallazgos FOD por la cadena correcta'),
        sub: L('Evidence building · marked "Unsure" last session',
            'Evidencia en desarrollo · marcado "${G('Inseguro', 'Insegura')}" en la última sesión')),
     ]),
    (title: L('Situational awareness on stand',
        'Conciencia situacional en el stand'),
     sub: L('Evidence building · 1 of 3 behaviors evidenced',
         'Evidencia en desarrollo · 1 de 3 conductas evidenciadas'),
     pill: L('Building', 'En desarrollo'), strong: false,
     kids: [
       (st: _Evidence.ok,
        text: L('Monitors anti-collision lights before approaching the aircraft',
            'Vigila las luces anticolisión antes de aproximarse a la aeronave'),
        sub: L('Evidenced · 7 attempts', 'Evidenciado · 7 intentos')),
       (st: _Evidence.mid,
        text: L('Reads standard marshalling signals correctly from any position',
            'Lee correctamente las señales estándar desde cualquier posición'),
        sub: L('Evidence building · 1 misconception flagged',
            'Evidencia en desarrollo · 1 concepto erróneo detectado')),
       (st: _Evidence.no,
        text: L('Keeps clear of the fuselage line until the aircraft settles',
            'Se mantiene fuera de la línea del fuselaje hasta que la aeronave '
                'se asienta'),
        sub: L('No evidence yet · covered in GSE positioning',
            'Sin evidencia aún · se cubre en posicionamiento de GSE')),
     ]),
  ];

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: TestuEyebrow(CL(
                'COMPETENCIES THIS TOPIC TRAINS · OPERATIONS, SAFETY LEAD',
                'COMPETENCIAS QUE ENTRENA ESTE TEMA · OPERACIONES',
                'COMPETENCIES THIS TOPIC TRAINS · RAMP AGENT, SAFETY LEAD',
                'COMPETENCIAS QUE ENTRENA ESTE TEMA · AGENTE DE RAMPA')),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              L('Every question here also records evidence against the '
                      'behaviors ${client.name} expects from your role.',
                  'Cada pregunta también registra evidencia sobre las '
                      'conductas que ${client.name} espera de tu rol.'),
              style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 10.5,
                  height: 1.5,
                  color: t.mut),
            ),
          ),
          for (var i = 0; i < _cmp.length; i++) ...[
            Container(
              decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: Color(0xFF17171A)))),
              child: TestuPressable(
                onTap: () => onToggle(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_cmp[i].title,
                              style: const TextStyle(
                                  fontFamily: 'Geist',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                  color: Color(0xFFECEBE7))),
                          const SizedBox(height: 2),
                          Text(_cmp[i].sub,
                              style: kMeta),
                        ],
                      ),
                    ),
                    const SizedBox(width: 11),
                    _cmp[i].strong
                        ? TestuPill(_cmp[i].pill,
                            color: const Color(0xFF7DBB9C),
                            borderColor: const Color(0xFF2F6A4C))
                        : TestuPill(_cmp[i].pill,
                            color: t.amber,
                            borderColor: const Color(0xFF7A5C1E)),
                    const SizedBox(width: 11),
                    AnimatedRotation(
                      turns: open.contains(i) ? 0.25 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: Text('›',
                          style:
                              TextStyle(fontSize: 13, color: t.faint)),
                    ),
                  ]),
                ),
              ),
            ),
            if (open.contains(i))
              Container(
                width: double.infinity,
                color: const Color(0xFF0D0D0F),
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(43, 8, 16, 4),
                      child: Text(L('OBSERVABLE BEHAVIORS', 'COMPORTAMIENTOS OBSERVABLES'),
                          style: TextStyle(
                              fontFamily: 'GeistMono',
                              fontSize: 8.5,
                              letterSpacing: 1.53,
                              color: t.faint)),
                    ),
                    for (final b in _cmp[i].kids) _BehaviorRow(b),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BehaviorRow extends StatelessWidget {
  const _BehaviorRow(this.b);

  final _Behavior b;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final (String mark, Color fg, Color bg, Color border) = switch (b.st) {
      _Evidence.ok => ('✓', const Color(0xFF7DBB9C), const Color(0xFF12231B),
          const Color(0xFF2F6A4C)),
      _Evidence.mid =>
        ('·', t.amber, const Color(0xFF291F10), const Color(0xFF7A5C1E)),
      _Evidence.no => ('–', t.faint, Colors.transparent, t.line2),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 7, 16, 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 15,
            height: 15,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            alignment: Alignment.center,
            child: Text(mark,
                style: TextStyle(fontSize: 9, height: 1, color: fg)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.text,
                    style: const TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 11.5,
                        height: 1.5,
                        color: Color(0xFFC2C1BD))),
                const SizedBox(height: 1),
                Text(b.sub,
                    style: kCaption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Subtopics ----

enum _Dot { green, orange, red, idle }

typedef _SubKid = ({_Dot dot, String title, String sub, String mode,
    bool critical});
typedef _SubGroup = ({_Dot dot, String title, String sub, String mode,
    bool primary, bool critical, List<_SubKid> kids});

Color _dotColor(_Dot d, TestuTokens t) => switch (d) {
      _Dot.green => t.green,
      _Dot.orange => t.orange,
      _Dot.red => t.red,
      _Dot.idle => const Color(0xFF3A3A40),
    };

class _SubGroupWidget extends StatelessWidget {
  const _SubGroupWidget(
      {required this.group, required this.open, required this.onToggle});

  final _SubGroup group;
  final bool open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF17171A)))),
          child: TestuPressable(
            onTap: onToggle,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
              child: Row(children: [
                _dot(8, _dotColor(group.dot, t)),
                const SizedBox(width: 13),
                Expanded(
                    child: _subText(group.title, group.sub, 13,
                        critical: group.critical)),
                const SizedBox(width: 10),
                _ModeButton(group.mode, primary: group.primary),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: open ? 0.25 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: Text('›',
                      style: TextStyle(fontSize: 13, color: t.faint)),
                ),
              ]),
            ),
          ),
        ),
        if (open)
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0D0D0F),
              border: Border(bottom: BorderSide(color: Color(0xFF17171A))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(41, 9, 18, 2),
                  child: Text(L('SKILLS', 'HABILIDADES'),
                      style: TextStyle(
                          fontFamily: 'GeistMono',
                          fontSize: 8.5,
                          letterSpacing: 1.53,
                          color: t.faint)),
                ),
                for (final k in group.kids)
                  Container(
                    decoration: BoxDecoration(
                      border: k == group.kids.last
                          ? null
                          : const Border(
                              bottom:
                                  BorderSide(color: Color(0xFF131316))),
                    ),
                    padding:
                        const EdgeInsets.fromLTRB(41, 11, 18, 11),
                    child: Row(children: [
                      _dot(6, _dotColor(k.dot, t)),
                      const SizedBox(width: 13),
                      Expanded(
                          child: _subText(k.title, k.sub, 12,
                              critical: k.critical)),
                      const SizedBox(width: 10),
                      _ModeButton(k.mode, small: true),
                    ]),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dot(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _subText(String title, String sub, double size,
      {required bool critical}) {
    return Builder(builder: (context) {
      final t = TestuTokens.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: title,
                  style: TextStyle(
                      fontFamily: 'Geist',
                      fontWeight: FontWeight.w600,
                      fontSize: size,
                      color: const Color(0xFFECEBE7))),
              if (critical)
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(
                        vertical: 2, horizontal: 6),
                    decoration: BoxDecoration(
                      border:
                          Border.all(color: const Color(0xFF7A5C1E)),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(L('CRITICAL SKILL', 'HABILIDAD CRÍTICA'),
                        style: TextStyle(
                            fontFamily: 'GeistMono',
                            fontSize: 7.5,
                            letterSpacing: 0.75,
                            color: t.amber)),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 3),
          Text(sub,
              style: kLabel),
        ],
      );
    });
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton(this.label, {this.primary = false, this.small = false});

  final String label;
  final bool primary;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuPressable(
      // The subtopic tree is prototype content, so the topic id is read off
      // the Topic Home above instead of being threaded through it.
      onTap: () => showTestuSession(context,
          topicId: context
              .findAncestorWidgetOfExactType<TestuTopicHomeScreen>()
              ?.topicId),
      child: Container(
        padding: small
            ? const EdgeInsets.symmetric(vertical: 6, horizontal: 9)
            : const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
        decoration: BoxDecoration(
          color: primary ? t.primaryAction : null,
          border:
              Border.all(color: primary ? t.primaryAction : t.line2),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: 'Geist',
              fontWeight: FontWeight.w700,
              fontSize: small ? 9.5 : 10.5,
              letterSpacing: 0.42,
              color:
                  primary ? t.onPrimaryAction : const Color(0xFFD8D7D3),
            )),
      ),
    );
  }
}

// ---- Resources ----

class _ResRow extends StatelessWidget {
  const _ResRow(
      {required this.icon,
      required this.title,
      required this.sub,
      required this.required,
      required this.onTap});

  final String icon;
  final String title;
  final String sub;
  final bool required;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF17171A)))),
      child: TestuPressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 18),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: t.card2,
                border: Border.all(color: t.line),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(icon,
                  style: TextStyle(
                      fontFamily: 'GeistMono',
                      fontWeight: FontWeight.w500,
                      fontSize: 9.5,
                      letterSpacing: 0.38,
                      color: t.mut)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontFamily: 'Geist',
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: Color(0xFFECEBE7))),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: kMeta),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
              decoration: BoxDecoration(
                border: Border.all(
                    color: required
                        ? const Color(0xFF7A5C1E)
                        : t.line2),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(required ? L('REQUIRED', 'OBLIGATORIO') : L('OPTIONAL', 'OPCIONAL'),
                  style: TextStyle(
                      fontFamily: 'GeistMono',
                      fontWeight: FontWeight.w500,
                      fontSize: 8.5,
                      letterSpacing: 0.85,
                      color: required ? t.amber : t.mut)),
            ),
          ]),
        ),
      ),
    );
  }
}

