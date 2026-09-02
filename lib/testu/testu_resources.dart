import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'testu_i18n.dart';
import 'testu_icons.dart';
import 'testu_pdf.dart';
import 'testu_sully.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

// ---------------------------------------------------------------------------
// Resource sheets (spec: prototype v6 openRes) — each resource opens a chat
// with Sully: his intro, canned Q&A chips, and for the manual/notice a chip
// that jumps into the source viewer. The video resource embeds the player.
// ---------------------------------------------------------------------------

typedef _Chip = ({String t, String? a, bool primary, bool open, int page});

class _Res {
  const _Res({
    required this.ic,
    required this.title,
    required this.meta,
    required this.sully,
    required this.live,
    required this.chips,
    this.video = false,
  });

  final String ic;
  final String title;
  final String meta;
  final String sully;

  /// Sully's answer to free-text input — proves the full-context concept
  /// (source + position + last question). ponytail: one canned reply per
  /// source until the topic-expert backend answers real free text.
  final String live;

  final List<_Chip> chips;
  final bool video;
}

_Res _resource(String key) => switch (key) {
      'gom' => _Res(
          ic: 'PDF',
          title: L('Ground Operations Manual', 'Manual de Operaciones en Tierra'),
          meta: L('Pages: 122 of 305 · viewed 27 times · Required',
              'Páginas: 122 de 305 · visto 27 veces · Obligatorio'),
          sully: L(
              "This is the Ground Operations Manual. You've read 122 of 305 "
                  'pages — you left off in section 4.5, Aircraft Arrival. What '
                  'would you like to know?',
              'Este es el Manual de Operaciones en Tierra. Has leído 122 de '
                  '305 páginas — lo dejaste en la sección 4.5, Llegada de la '
                  'aeronave. ¿Qué te gustaría saber?'),
          live: L(
              'Short answer from where you are in section 4.5: guidance ends '
                  'when the aircraft stops; chocks wait for engines off and '
                  'anti-collision lights off; then GPU and hold-point release. '
                  'Ask me another angle and I\'ll pull the exact page.',
              'Respuesta corta desde donde estás en la sección 4.5: el guiado '
                  'termina cuando la aeronave se detiene; los calzos esperan a '
                  'motores y luces anticolisión apagados; después GPU y '
                  'liberación del punto de espera. Pregúntame otro ángulo y '
                  'te traigo la página exacta.'),
          chips: [
            // ponytail: the demo doc is an 11-page stand-in for the 305-page
            // manual — p. 6 plays the role of "where I left off" so the
            // viewer demonstrably opens scrolled to the spot, not at p. 1.
            (t: L('Open where I left off', 'Abrir donde lo dejé'),
             a: null, primary: true, open: true, page: 6),
            (t: L('Summarize section 4.5', 'Resume la sección 4.5'),
             a: L(
                 'Section 4.5 covers arrival on stand: guidance ends when the '
                     'aircraft stops; chocks go on only after engines are shut '
                     'down and anti-collision lights are off; then GPU '
                     'connection and hold-point release. The chock-timing rule '
                     'is the one your last session flagged.',
                 'La sección 4.5 cubre la llegada al stand: el guiado termina '
                     'cuando la aeronave se detiene; los calzos se colocan solo '
                     'con motores apagados y luces anticolisión apagadas; '
                     'después, conexión del GPU y liberación del punto de '
                     'espera. La regla del momento de calzar es la que marcó '
                     'tu última sesión.'),
             primary: false, open: false, page: 0),
            (t: L('Where did I leave off?', '¿Dónde lo dejé?'),
             a: L(
                 'Page 122 — mid-section 4.5, right before the chocking '
                     'sequence table. About 10 minutes of reading to finish '
                     'the section.',
                 'Página 122 — a mitad de la sección 4.5, justo antes de la '
                     'tabla de secuencia de calzado. Unos 10 minutos de '
                     'lectura para terminar la sección.'),
             primary: false, open: false, page: 0),
          ],
        ),
      'vid' => _Res(
          ic: 'VID',
          title: L('Turnaround walkthrough', 'Recorrido del turnaround'),
          meta: L('Chapter 1 of 5 watched · viewed twice · Optional',
              'Capítulo 1 de 5 visto · visto dos veces · Opcional'),
          video: true,
          sully: L(
              "The turnaround walkthrough, in five chapters. You've watched "
                  'Arrival & stand check twice — I\'ve cued the player to '
                  'where you stopped. Jump to any chapter with the timestamps, '
                  'or let me test what stuck.',
              'El recorrido del turnaround, en cinco capítulos. Has visto '
                  'Llegada y revisión del stand dos veces — he dejado el vídeo '
                  'donde lo paraste. Salta a cualquier capítulo, o deja que '
                  'compruebe qué se te quedó.'),
          live: L(
              "You're cued at Hold preparation (0:32) — the key beat in this "
                  'chapter is opening the holds only after the stand check is '
                  'complete. I also remember the chock-timing question you '
                  'just answered; tell me if you want the chapter that shows '
                  'it.',
              'Estás en Preparación de bodega (0:32) — la clave de este '
                  'capítulo es abrir las bodegas solo tras completar la '
                  'revisión del stand. También tengo presente la pregunta de '
                  'calzos que acabas de responder; dime si quieres el '
                  'capítulo donde se ve.'),
          chips: [
            (t: L('Quiz me on what I watched', 'Pregúntame sobre lo que vi'),
             a: L(
                 "Good instinct — watching counts less than recalling. I'll "
                     "add three questions from the arrival chapter to "
                     "tomorrow's Daily Challenge.",
                 'Buen instinto — ver cuenta menos que recordar. Añadiré tres '
                     'preguntas del capítulo de llegada al Reto Diario de '
                     'mañana.'),
             primary: true, open: false, page: 0),
            (t: L('What chapters are left?', '¿Qué capítulos me faltan?'),
             a: L(
                 "You've completed Arrival & stand check. Remaining: Hold "
                     'preparation, Loading at the aircraft, and Secured & '
                     'ready.',
                 'Has completado Llegada y revisión del stand. Quedan: '
                     'Preparación de bodega, Carga en la aeronave y Asegurado '
                     'y listo.'),
             primary: false, open: false, page: 0),
          ],
        ),
      _ => _Res(
          ic: 'DOC',
          title: L('Station notice 2026-14: chocking update',
              'Aviso de estación 2026-14: cambio de calzado'),
          meta: L('Pages: 0 of 2 · unread · effective Aug 1 · Required',
              'Páginas: 0 de 2 · sin leer · vigente desde el 1 ago · Obligatorio'),
          sully: L(
              "This notice changed the chocking sequence on Aug 1 — it's "
                  "required reading, and it's exactly where your misconception "
                  'came from. Two pages, about 3 minutes. Shall I walk you '
                  'through the change instead?',
              'Este aviso cambió la secuencia de calzado el 1 de agosto — es '
                  'lectura obligatoria, y es exactamente de donde viene tu '
                  'concepto erróneo. Dos páginas, unos 3 minutos. ¿Prefieres '
                  'que te explique el cambio?'),
          live: L(
              'The heart of the notice, since Aug 1: main gear first, fore '
                  'and aft, nose gear last. The trigger for chocking did not '
                  'change — engines off and anti-collision lights out.',
              'Lo esencial del aviso, desde el 1 de agosto: tren principal '
                  'primero, delante y detrás, tren de morro al final. El '
                  'disparador del calzado no cambia — motores apagados y '
                  'luces anticolisión apagadas.'),
          chips: [
            (t: L('Walk me through the change', 'Explícame el cambio'),
             a: L(
                 'Before Aug 1: chocks on nose gear first. Now: main gear '
                     'first, fore and aft, nose gear last — aligned with the '
                     'FAA guidance. The trigger is unchanged: engines off and '
                     'anti-collision lights out.',
                 'Antes del 1 de agosto: calzos primero en el tren de morro. '
                     'Ahora: tren principal primero, delante y detrás, tren de '
                     'morro al final — alineado con la guía de la FAA. El '
                     'disparador no cambia: motores apagados y luces '
                     'anticolisión apagadas.'),
             primary: true, open: false, page: 0),
            (t: L('Why did it change?', '¿Por qué cambió?'),
             a: L(
                 'Two near-miss reports last winter — both involved nose-gear '
                     'approach while the aircraft was still settling. '
                     'Main-gear-first keeps you clear of the fuselage line '
                     'longer.',
                 'Dos informes de casi-incidente el invierno pasado — ambos '
                     'con aproximación al tren de morro con la aeronave aún '
                     'asentándose. Empezar por el tren principal te mantiene '
                     'más tiempo fuera de la línea del fuselaje.'),
             primary: false, open: false, page: 0),
          ],
        ),
    };

void showTestuResource(BuildContext context, String key) {
  HapticFeedback.selectionClick();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xA8000000),
    builder: (_) => _ResSheet(res: _resource(key)),
  );
}

class _ResSheet extends StatefulWidget {
  const _ResSheet({required this.res});

  final _Res res;

  @override
  State<_ResSheet> createState() => _ResSheetState();
}

class _ResSheetState extends State<_ResSheet> {
  final List<Widget> _chat = [];
  final Set<int> _used = {};
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _chat.add(SullyMessage.text(widget.res.sully, delay: 850, bottomPadding: 12));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: TestuTokens.curve);
      }
    });
  }

  void _tapChip(int i) {
    final c = widget.res.chips[i];
    if (c.open) {
      showTestuPdf(context, page: c.page, cite: widget.res.title);
      return;
    }
    setState(() {
      _used.add(i);
      _chat.add(TestuYouMsg(text: c.t));
      _chat.add(SullyMessage.text(c.a!,
          delay: 850, sourceLine: widget.res.title, bottomPadding: 12));
    });
    _autoScroll();
  }

  void _send(String text) {
    setState(() {
      _chat.add(TestuYouMsg(text: text));
      _chat.add(SullyMessage.text(widget.res.live,
          delay: 850, sourceLine: widget.res.title, bottomPadding: 12));
    });
    _autoScroll();
  }

  /// The scrolling middle of the sheet: chat, canned chips, Close.
  Widget _chatList(EdgeInsets padding) {
    final res = widget.res;
    return ListView(
      controller: _scroll,
      shrinkWrap: true,
      padding: padding,
      children: [
        ...List.of(_chat),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < res.chips.length; i++)
              if (!_used.contains(i))
                _ChipBtn(
                  label: res.chips[i].t,
                  primary: res.chips[i].primary,
                  onTap: () => _tapChip(i),
                ),
          ],
        ),
        const SizedBox(height: 16),
        TestuButton(L('Close', 'Cerrar'),
            onTap: () => Navigator.of(context).pop()),
        const SizedBox(height: 4),
      ],
    );
  }

  // House composer, live — free text lands in the chat and Sully answers
  // with the source context in view (continuous-tutor rule). ponytail:
  // canned per-source reply until the topic-expert backend answers real
  // free text.
  Widget _composer(EdgeInsets padding) => Padding(
        padding: padding,
        child: TestuComposer(
          hint: L('Ask Sully about this source…',
              'Pregunta a Sully sobre esta fuente…'),
          onSend: _send,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final res = widget.res;
    final size = MediaQuery.sizeOf(context);
    // Landscape can't stack player + chapters + chat + composer — the
    // continuous-tutor rule survives as a split instead: source pinned
    // left, chat and composer right.
    final split = res.video && size.width > size.height;
    return Container(
      constraints:
          BoxConstraints(maxHeight: size.height * (split ? 0.94 : 0.88)),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: t.line2)),
      ),
      padding: EdgeInsets.only(
          bottom: 26 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 14, bottom: 16),
            decoration: BoxDecoration(
              color: t.line2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.card2,
                  border: Border.all(color: t.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(res.ic,
                    style: TextStyle(
                        fontFamily: 'GeistMono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: t.mut)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(res.title,
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.15,
                          color: t.ink,
                        )),
                    const SizedBox(height: 2),
                    Text(res.meta,
                        style: kMeta),
                  ],
                ),
              ),
            ]),
          ),
          // Source pinned above, ask bar pinned below, chat scrolls between:
          // the user talks to Sully about the source without ever scrolling
          // either out of view (app-wide continuous-tutor rule).
          if (split)
            Flexible(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Player pinned; only its chapter list scrolls.
                    const Expanded(
                      flex: 5,
                      child: _MiniPlayer(pinned: true),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(child: _chatList(EdgeInsets.zero)),
                            _composer(const EdgeInsets.only(top: 12)),
                          ]),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            if (res.video)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: _MiniPlayer(),
              ),
            Flexible(
                child: _chatList(const EdgeInsets.fromLTRB(18, 14, 18, 0))),
            _composer(const EdgeInsets.fromLTRB(18, 12, 18, 0)),
          ],
        ],
      ),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  const _ChipBtn(
      {required this.label, required this.primary, required this.onTap});

  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: primary ? t.primaryAction : null,
          border: Border.all(color: primary ? t.primaryAction : t.line2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 11.5,
              fontWeight: primary ? FontWeight.w700 : FontWeight.w400,
              color: primary ? t.onPrimaryAction : const Color(0xFFC2C1BD),
            )),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Minimal chaptered-video stand-in: real playback, tap to play/pause,
// progress hairline, seeking chapter rows, expand-to-fullscreen.
// ---------------------------------------------------------------------------

class _MiniPlayer extends StatefulWidget {
  const _MiniPlayer({this.pinned = false});

  /// Landscape pane: the card is height-bounded — video, progress and
  /// footer stay put while the chapter list scrolls on its own. Unpinned
  /// (portrait) the card sits in the sheet's normal flow.
  final bool pinned;

  @override
  State<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<_MiniPlayer> {
  late final VideoPlayerController _ctrl;
  bool _ready = false;

  /// Full chapter list unfolded. Collapsed by default: only the playing
  /// chapter + the next one show, so the chat below keeps room
  /// (continuous-tutor rule — the composer must never hide behind the
  /// timestamps). Sully can always point to the right chapter instead.
  bool _chaptersOpen = false;

  /// Index of the chapter the playhead is in (pre-ready: the cue point).
  int get _currentCh {
    final pos = _ready ? _ctrl.value.position : _chapters[2].at;
    var idx = 0;
    for (final (i, c) in _chapters.indexed) {
      if (pos >= c.at) idx = i;
    }
    return idx;
  }

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.asset('assets/video/turnaround.mp4')
      ..initialize().then((_) async {
        // Sully's copy promises the player is cued to where Ana stopped —
        // Arrival & stand check watched → start of Hold preparation (0:32).
        await _ctrl.seekTo(_chapters[2].at);
        if (mounted) setState(() => _ready = true);
      });
    _ctrl.addListener(_onTick);
  }

  /// The approved v6 chapter list, verbatim — timestamps are real seek
  /// targets, matching Sully's "jump to any chapter with the timestamps".
  List<({Duration at, String name})> get _chapters => [
        (at: Duration.zero, name: L('Intro', 'Introducción')),
        (at: const Duration(seconds: 15),
         name: L('Arrival & stand check', 'Llegada y revisión del stand')),
        (at: const Duration(seconds: 32),
         name: L('Hold preparation', 'Preparación de bodega')),
        (at: const Duration(seconds: 64),
         name: L('Loading at the aircraft', 'Carga en la aeronave')),
        (at: const Duration(seconds: 104),
         name: L('Secured & ready', 'Asegurado y listo')),
      ];

  void _jump(Duration at) {
    if (!_ready) return;
    HapticFeedback.selectionClick();
    _ctrl.seekTo(at);
    _ctrl.play();
    // Fold the list back — the collapsed pair follows the new position.
    setState(() => _chaptersOpen = false);
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _progress() => Row(children: [
        Expanded(
          child: TestuHairline(
            _ready && _ctrl.value.duration.inMilliseconds > 0
                ? _ctrl.value.position.inMilliseconds /
                    _ctrl.value.duration.inMilliseconds
                : 0,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          _ready
              ? '${_fmt(_ctrl.value.position)} / ${_fmt(_ctrl.value.duration)}'
              : '–:–',
          style: const TextStyle(
              fontFamily: 'GeistMono',
              fontSize: 9.5,
              color: Color(0xFFD6D6DA)),
        ),
      ]);

  /// Full-screen playback — same lightbox grammar as showTestuZoom (PDF
  /// pages), so video and PDF share one "expand" behavior. The sheet's
  /// controller keeps playing; ✕ lands back where you were.
  void _fullscreen() {
    if (!_ready) return;
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: const Color(0xF20A0A0B),
        pageBuilder: (context, animation, secondaryAnimation) {
          final t = TestuTokens.of(context);
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) => Column(children: [
                  Row(children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(_chapters[_currentCh].name, style: kLabel),
                      ),
                    ),
                    TestuPressable(
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text('✕',
                            style: TextStyle(fontSize: 16, color: t.mut)),
                      ),
                    ),
                  ]),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        // play()/pause() return Futures — never inside
                        // setState (framework assertion).
                        _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
                      },
                      child: Stack(alignment: Alignment.center, children: [
                        Center(
                          child: AspectRatio(
                              aspectRatio: _ctrl.value.aspectRatio,
                              child: VideoPlayer(_ctrl)),
                        ),
                        if (!_ctrl.value.isPlaying)
                          Container(
                            width: 52,
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xCC0A0A0B),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: const Color(0x2EFFFFFF)),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text('▶',
                                  style: TextStyle(
                                      fontSize: 17,
                                      color: Color(0xFFF4F2EE))),
                            ),
                          ),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                    child: _progress(),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Chapter row — the approved v6 design: full-width tappable rows, mono
  /// timestamp column (blue = a link into the source; orange = playing now),
  /// hairline between rows.
  Widget _chapterRow(TestuTokens t, int i, ({Duration at, String name}) c) {
    final pos = _ready ? _ctrl.value.position : Duration.zero;
    final next = i + 1 < _chapters.length
        ? _chapters[i + 1].at
        : const Duration(days: 1);
    final current = _ready && pos >= c.at && pos < next;
    return TestuPressable(
      onTap: () => _jump(c.at),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.line)),
        ),
        child: Row(children: [
          SizedBox(
            width: 36,
            child: Text(_fmt(c.at),
                style: TextStyle(
                    fontFamily: 'GeistMono',
                    fontSize: 9.5,
                    color: current ? t.orange : t.blue)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(c.name,
                style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 11.5,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                    color: current
                        ? const Color(0xFFE9E8E4)
                        : const Color(0xFFC2C1BD))),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0F),
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              if (!_ready) return;
              HapticFeedback.selectionClick();
              // play()/pause() return Futures — kept outside setState
              // (an async setState callback is a framework assertion).
              _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
              setState(() {});
            },
            // Full-width 16:9 in portrait (height is width-driven there, far
            // under the cap); in landscape capped to 30% of screen height
            // (letterboxed) so the pinned card — video + progress + chapter
            // pair + toggle + footer — fits the pane without scrolling.
            child: LayoutBuilder(builder: (context, bc) {
              final ratio = _ready ? _ctrl.value.aspectRatio : 16 / 9;
              final h = (bc.maxWidth / ratio)
                  .clamp(0.0, MediaQuery.sizeOf(context).height * 0.30);
              return SizedBox(
                width: bc.maxWidth,
                height: h,
                child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  const ColoredBox(color: Colors.black),
                  if (_ready)
                    Center(
                      child: AspectRatio(
                          aspectRatio: ratio, child: VideoPlayer(_ctrl)),
                    ),
                  if (!_ready || !_ctrl.value.isPlaying)
                    Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xCC0A0A0B),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x2EFFFFFF)),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Text('▶',
                              style: TextStyle(
                                  fontSize: 17, color: Color(0xFFF4F2EE))),
                        ),
                      ),
                    ),
                  // Always-available fullscreen (portrait and landscape) —
                  // the PDF's tap-to-zoom counterpart for video.
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: TestuPressable(
                      onTap: _fullscreen,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xCC0A0A0B),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0x2EFFFFFF)),
                        ),
                        child: const TestuIcon(TestuGlyph.expand,
                            size: 13, color: Color(0xFFF4F2EE)),
                      ),
                    ),
                  ),
                ],
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            child: _progress(),
          ),
          if (widget.pinned)
            // Pinned card: the list gets whatever height is left and scrolls
            // inside it — dragging the timestamps never moves the video.
            Flexible(
              child: SingleChildScrollView(
                child: Column(children: [
                  for (final (i, c) in _chapters.indexed)
                    if (_chaptersOpen || i == _currentCh || i == _currentCh + 1)
                      _chapterRow(t, i, c),
                ]),
              ),
            )
          else if (!_chaptersOpen) ...[
            _chapterRow(t, _currentCh, _chapters[_currentCh]),
            if (_currentCh + 1 < _chapters.length)
              _chapterRow(t, _currentCh + 1, _chapters[_currentCh + 1]),
          ] else
            // Scrolls when the list outgrows the cap (real libraries have
            // more than five chapters).
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 190),
              child: SingleChildScrollView(
                child: Column(children: [
                  for (final (i, c) in _chapters.indexed) _chapterRow(t, i, c),
                ]),
              ),
            ),
          TestuPressable(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _chaptersOpen = !_chaptersOpen);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.line)),
              ),
              child: Row(children: [
                Expanded(
                  child: Text(
                    L('All chapters · ${_chapters.length}',
                        'Todos los capítulos · ${_chapters.length}'),
                    style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 10,
                        letterSpacing: 0.3,
                        color: t.mut),
                  ),
                ),
                Text(_chaptersOpen ? '−' : '+',
                    style: TextStyle(fontSize: 12, color: t.faint)),
              ]),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 11),
            decoration: BoxDecoration(
              color: t.card2,
              border: Border(top: BorderSide(color: t.line)),
            ),
            child: Text(
              L('Turnaround groundhandling, Frankfurt — demo footage · CC BY-SA Lufthansa Cargo',
                  'Handling de turnaround, Fráncfort — metraje de demo · CC BY-SA Lufthansa Cargo'),
              style: kCaption,
            ),
          ),
        ],
      ),
    );
  }
}
