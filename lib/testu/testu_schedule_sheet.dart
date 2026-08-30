import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Schedule-evaluation bottom sheet (spec: overlays table — Sully roster
/// message, 2-week mini calendar, slot chips, canned Q&A, white CONFIRM
/// disabled until a slot is picked, check-draw success).
///
/// `onScheduled` fires the moment CONFIRM is tapped (before the success view),
/// so Today can hand the white CTA off behind the sheet — matching the
/// prototype's markScheduled timing.
Future<void> showTestuScheduleSheet(
  BuildContext context, {
  required ValueChanged<String> onScheduled,
}) {
  final t = TestuTokens.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: t.card,
    barrierColor: const Color(0xA8000000),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: t.line2),
    ),
    builder: (_) => _ScheduleSheetBody(onScheduled: onScheduled),
  );
}

typedef _Slot = ({int day, String label});

// Fictional demo roster — Sep 1–14, Monday start (prototype v6 data).
List<_Slot> get _slots => [
  (day: 4, label: L('Thu Sep 4 · 09:30', 'Jue 4 sep · 09:30')),
  (day: 5, label: L('Fri Sep 5 · 14:00', 'Vie 5 sep · 14:00')),
  (day: 9, label: L('Tue Sep 9 · 08:15', 'Mar 9 sep · 08:15')),
];

class _ScheduleSheetBody extends StatefulWidget {
  const _ScheduleSheetBody({required this.onScheduled});

  final ValueChanged<String> onScheduled;

  @override
  State<_ScheduleSheetBody> createState() => _ScheduleSheetBodyState();
}

class _ScheduleSheetBodyState extends State<_ScheduleSheetBody> {
  int? _picked;
  String? _extraMsg;
  bool _confirmed = false;

  _Slot? get _slot =>
      _picked == null ? null : _slots.firstWhere((s) => s.day == _picked);

  void _confirm() {
    final slot = _slot!;
    HapticFeedback.heavyImpact();
    widget.onScheduled(slot.label);
    setState(() => _confirmed = true);
    // Success pattern after the check draws in.
    Future.delayed(const Duration(milliseconds: 400), () {
      HapticFeedback.lightImpact();
      Future.delayed(
          const Duration(milliseconds: 60), HapticFeedback.lightImpact);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: t.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (_confirmed)
              _SuccessView(label: _slot!.label)
            else
              ..._pickerChildren(t),
          ],
        ),
      ),
    );
  }

  List<Widget> _pickerChildren(TestuTokens t) => [
        TestuEyebrow(
            L('CERTIFICATION · RENEWAL EVALUATION',
                'CERTIFICACIÓN · EVALUACIÓN DE RENOVACIÓN'),
            color: t.amber),
        const SizedBox(height: 6),
        _SheetTitle(L('Schedule with Sully', 'Programa con Sully')),
        const SizedBox(height: 14),
        _SullyMsg(L(
            'I checked your roster and calendar, Ana. The evaluation takes '
                'about 25 minutes and needs a quiet slot. Here’s where you’re '
                'clear before the deadline:',
            'He revisado tu turno y tu calendario, Ana. La evaluación dura '
                'unos 25 minutos y necesita un hueco tranquilo. Aquí es donde '
                'estás libre antes de la fecha límite:')),
        const SizedBox(height: 14),
        _Calendar(picked: _picked, onPick: _pick),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _slots)
              _SlotChip(s.label,
                  picked: _picked == s.day, onTap: () => _pick(s.day)),
          ],
        ),
        if (_extraMsg != null) ...[
          const SizedBox(height: 14),
          _SullyMsg(_extraMsg!),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QaChip(L('Anything on Monday?', '¿Algo el lunes?'),
                onTap: () => _ask(L(
                    'Monday is tight — you’re rostered 06:00–14:00 and the '
                        'afternoon has the station safety briefing. Tuesday '
                        '08:15 is the nearest quiet opening.',
                    'El lunes va justo — tienes turno de 06:00 a 14:00 y por '
                        'la tarde está el briefing de seguridad. El martes a '
                        'las 08:15 es el hueco tranquilo más cercano.'))),
            _QaChip(L('Can it be split in two?', '¿Se puede partir en dos?'),
                onTap: () => _ask(L(
                    'The renewal evaluation has to run in one sitting — '
                        'that’s a certification rule, not mine. 25 minutes, '
                        'no interruptions from me beyond the procedure itself.',
                    'La evaluación de renovación debe hacerse de una sentada — '
                        'es una regla de la certificación, no mía. 25 minutos, '
                        'sin interrupciones más allá del propio procedimiento.'))),
          ],
        ),
        const SizedBox(height: 16),
        Opacity(
          opacity: _picked == null ? 0.35 : 1,
          child: TestuButton(
            _picked == null
                ? L('PICK A SLOT TO CONFIRM', 'ELIGE UN HUECO PARA CONFIRMAR')
                : '${L('CONFIRM', 'CONFIRMAR')} · ${_slot!.label.toUpperCase()}',
            variant: TestuButtonVariant.primary,
            onTap: _picked == null ? null : _confirm,
          ),
        ),
        const SizedBox(height: 9),
        TestuButton(L('Not now', 'Ahora no'),
            onTap: () => Navigator.pop(context)),
        const SizedBox(height: 14),
        // ponytail: decorative ask bar — becomes a real input when the
        // schedule flow talks to the backend.
        Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF101013),
            border: Border.all(color: t.line2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            L('Ask Sully for a different time…',
                'Pide a Sully otra hora…'),
            style: TextStyle(
                fontFamily: 'Geist', fontSize: 12.5, color: t.faint),
          ),
        ),
      ];

  void _pick(int day) {
    HapticFeedback.selectionClick();
    setState(() => _picked = day);
  }

  void _ask(String answer) {
    HapticFeedback.selectionClick();
    setState(() => _extraMsg = answer);
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Sora',
        fontWeight: FontWeight.w700,
        fontSize: 17,
        letterSpacing: -0.17,
        color: TestuTokens.of(context).ink,
      ),
    );
  }
}

/// Sully chat row — 26px avatar, mono name, 13.5px body.
class _SullyMsg extends StatelessWidget {
  const _SullyMsg(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Row(
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
              Text(
                text,
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
    );
  }
}

/// 2-week mini calendar: 7 columns, orange dot marks an available day.
class _Calendar extends StatelessWidget {
  const _Calendar({required this.picked, required this.onPick});

  final int? picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    Widget cell(Widget child) =>
        Expanded(child: Padding(padding: const EdgeInsets.all(2.5), child: child));
    return Column(
      children: [
        Row(
          children: [
            for (final d in testuLang.value == 'es'
                ? const ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                : const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              cell(Text(
                d,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'GeistMono',
                  fontSize: 8.5,
                  color: t.faint,
                ),
              )),
          ],
        ),
        for (var row = 0; row < 2; row++)
          Row(
            children: [
              for (var d = row * 7 + 1; d <= row * 7 + 7; d++)
                cell(_DayCell(
                  day: d,
                  available: _slots.any((s) => s.day == d),
                  picked: picked == d,
                  onTap: () => onPick(d),
                )),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.available,
    required this.picked,
    required this.onTap,
  });

  final int day;
  final bool available;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final box = Container(
      height: 36,
      decoration: BoxDecoration(
        color: picked ? t.primaryAction : null,
        border: Border.all(
          color: picked
              ? t.primaryAction
              : available
                  ? t.line2
                  : Colors.transparent,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(
            '$day',
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12,
              fontWeight: picked ? FontWeight.w700 : FontWeight.w400,
              color: picked
                  ? t.onPrimaryAction
                  : available
                      ? const Color(0xFFE6E4E0)
                      : const Color(0xFF7E828A),
            ),
          ),
          if (available)
            Positioned(
              bottom: 4,
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: picked ? t.onPrimaryAction : t.orange,
                ),
              ),
            ),
        ],
      ),
    );
    return available ? TestuPressable(onTap: onTap, child: box) : box;
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip(this.label, {required this.picked, required this.onTap});

  final String label;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 13),
        decoration: BoxDecoration(
          color: picked ? t.primaryAction : null,
          border: Border.all(color: picked ? t.primaryAction : t.line2),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 11.5,
            fontWeight: picked ? FontWeight.w700 : FontWeight.w400,
            color: picked ? t.onPrimaryAction : const Color(0xFFD6D4D0),
          ),
        ),
      ),
    );
  }
}

class _QaChip extends StatelessWidget {
  const _QaChip(this.label, {required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TestuPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          border: Border.all(color: TestuTokens.of(context).line2),
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
    );
  }
}

/// "Locked in" success: pulse ring + check that draws itself in.
class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return SizedBox(
      width: double.infinity,
      child: Column(
        children: [
          const SizedBox(height: 18),
          SizedBox(
            width: 76,
            height: 76,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1900),
              builder: (_, v, child) => CustomPaint(
                painter: _CheckPainter(progress: v, green: t.green),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SheetTitle(L('Locked in. Quiet high-five, Ana.',
              'Apuntado. Choca esos cinco en silencio, Ana.')),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text.rich(
              TextSpan(
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12.5,
                  height: 1.65,
                  color: t.mut,
                ),
                children: [
                  TextSpan(
                    text: label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: Color(0xFFE6E4E0)),
                  ),
                  TextSpan(
                      text: L(
                          ' is on your calendar — 25 minutes, Evaluation '
                              'Mode. I’ll send you a reminder the evening '
                              'before, and we’ll sharpen ',
                          ' está en tu calendario — 25 minutos, Modo '
                              'Evaluación. Te enviaré un recordatorio la '
                              'tarde anterior, y repasaremos ')),
                  TextSpan(
                      text: L('chock timing', 'el momento de calzar'),
                      style: const TextStyle(fontStyle: FontStyle.italic)),
                  TextSpan(
                      text: L(' once more before you sit it.',
                          ' una vez más antes de que la hagas.')),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          TestuButton(L('Done', 'Hecho'),
              variant: TestuButtonVariant.primary,
              onTap: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}

/// One paint, three phases of `progress` (0–1 over 1.9s, mirroring the
/// prototype timings): check draws .25–.5s, pulse ring expands .3–1.9s.
class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.progress, required this.green});

  final double progress;
  final Color green;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = progress * 1900;
    final center = size.center(Offset.zero);
    const ring = Color(0xFF2F6A4C);

    final pulse = ((ms - 300) / 1600).clamp(0.0, 1.0);
    if (pulse > 0 && pulse < 1) {
      canvas.drawCircle(
        center,
        36 * (1 + 0.65 * pulse),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ring.withValues(alpha: 0.9 * (1 - pulse)),
      );
    }

    canvas.drawCircle(
      center,
      36,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ring,
    );

    final draw = Curves.easeOut.transform(((ms - 250) / 500).clamp(0.0, 1.0));
    if (draw > 0) {
      final path = Path()
        ..moveTo(24, 39)
        ..lineTo(34, 49)
        ..lineTo(53, 29);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * draw),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = green,
      );
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}
