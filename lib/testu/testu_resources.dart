import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'testu_i18n.dart';
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
    required this.chips,
    this.video = false,
  });

  final String ic;
  final String title;
  final String meta;
  final String sully;
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
          chips: [
            (t: L('Open where I left off', 'Abrir donde lo dejé'),
             a: null, primary: true, open: true, page: 1),
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

  void _tapChip(int i) {
    final c = widget.res.chips[i];
    if (c.open) {
      showTestuPdf(context, page: c.page, cite: widget.res.title);
      return;
    }
    setState(() {
      _used.add(i);
      _chat.add(_YouMsg(text: c.t));
      _chat.add(SullyMessage.text(c.a!,
          delay: 850, sourceLine: widget.res.title, bottomPadding: 12));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: TestuTokens.curve);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final res = widget.res;
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88),
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
                        style: TextStyle(
                            fontFamily: 'Geist',
                            fontSize: 10.5,
                            color: t.mut)),
                  ],
                ),
              ),
            ]),
          ),
          Flexible(
            child: ListView(
              controller: _scroll,
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              children: [
                if (res.video) ...[
                  const _MiniPlayer(),
                  const SizedBox(height: 14),
                ],
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
                const SizedBox(height: 14),
                // ponytail: decorative — free-text needs the tutor backend.
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 11, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF101013),
                    border: Border.all(color: t.line2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    L('Ask Sully about this source…',
                        'Pregunta a Sully sobre esta fuente…'),
                    style: TextStyle(
                        fontFamily: 'Geist', fontSize: 12.5, color: t.faint),
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

class _YouMsg extends StatelessWidget {
  const _YouMsg({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1D22),
            border: Border.all(color: t.line2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text,
              style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12.5,
                  color: Color(0xFFD6D4D0))),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Minimal chaptered-video stand-in: real playback, tap to play/pause,
// progress hairline. ponytail: chapters/fullscreen skipped — add when the
// resource library is real.
// ---------------------------------------------------------------------------

class _MiniPlayer extends StatefulWidget {
  const _MiniPlayer();

  @override
  State<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<_MiniPlayer> {
  late final VideoPlayerController _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.asset('assets/video/turnaround.mp4')
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      });
    _ctrl.addListener(_onTick);
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
        children: [
          GestureDetector(
            onTap: () {
              if (!_ready) return;
              HapticFeedback.selectionClick();
              setState(() =>
                  _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play());
            },
            child: AspectRatio(
              aspectRatio: _ready ? _ctrl.value.aspectRatio : 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  if (_ready)
                    VideoPlayer(_ctrl)
                  else
                    const ColoredBox(color: Colors.black),
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
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
            child: Row(children: [
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
            ]),
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
              style: TextStyle(
                  fontFamily: 'Geist', fontSize: 9.5, color: t.faint),
            ),
          ),
        ],
      ),
    );
  }
}
