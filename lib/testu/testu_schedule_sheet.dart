import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_sully.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';
import 'testu_client.dart';

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
  return showTestuSheet<void>(
    context,
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
  String? _youMsg;
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
        padding: EdgeInsets.fromLTRB(
            18, 0, 18, 26 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TestuGrabber(),
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
        _SheetTitle(L('Schedule with ${client.tutor}', 'Programa con ${client.tutor}')),
        const SizedBox(height: 14),
        SullyMessage.text(L(
            'I checked your roster and calendar, ${client.persona}. The evaluation takes '
                'about 25 minutes and needs a quiet slot. Here’s where you’re '
                'clear before the deadline:',
            'He revisado tu turno y tu calendario, ${client.persona}. La evaluación dura '
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
        if (_youMsg != null) ...[
          const SizedBox(height: 14),
          TestuYouMsg(text: _youMsg!),
        ],
        if (_extraMsg != null) ...[
          if (_youMsg == null) const SizedBox(height: 14),
          SullyMessage.text(_extraMsg!),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TestuChip(L('Anything on Monday?', '¿Algo el lunes?'),
                onTap: () => _ask(L(
                    'Monday is tight — you’re rostered 06:00–14:00 and the '
                        'afternoon has the station safety briefing. Tuesday '
                        '08:15 is the nearest quiet opening.',
                    'El lunes va justo — tienes turno de 06:00 a 14:00 y por '
                        'la tarde está el briefing de seguridad. El martes a '
                        'las 08:15 es el hueco tranquilo más cercano.'))),
            TestuChip(L('Can it be split in two?', '¿Se puede partir en dos?'),
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
        TestuButton(
          _picked == null
              ? L('PICK A SLOT TO CONFIRM', 'ELIGE UN HUECO PARA CONFIRMAR')
              : '${L('CONFIRM', 'CONFIRMAR')} · ${_slot!.label.toUpperCase()}',
          variant: TestuButtonVariant.primary,
          onTap: _picked == null ? null : _confirm,
        ),
        const SizedBox(height: 9),
        TestuButton(L('Not now', 'Ahora no'),
            onTap: () => Navigator.pop(context)),
        const SizedBox(height: 14),
        // House composer, live like every other ask bar (continuous-tutor
        // rule). ponytail: one canned answer until the schedule flow talks
        // to the backend's roster.
        TestuComposer(
          hint: L('Ask ${client.tutor} for a different time…',
              'Pide a ${client.tutor} otra hora…'),
          onSend: (text) => _ask(
              L('Those three are the only quiet slots I can see before the deadline. Pick one, or free some time on your calendar and I’ll look again.',
                  'Esos tres son los únicos huecos tranquilos que veo antes de la fecha límite. Elige uno, o libera tiempo en tu calendario y vuelvo a mirar.'),
              from: text),
        ),
      ];

  void _pick(int day) {
    HapticFeedback.selectionClick();
    setState(() => _picked = day);
  }

  void _ask(String answer, {String? from}) {
    HapticFeedback.selectionClick();
    setState(() {
      _youMsg = from;
      _extraMsg = answer;
    });
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: kSheetTitle);
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
                      ? t.ink
                      : t.faint,
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
            color: picked ? t.onPrimaryAction : t.inkSoft,
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
          const TestuCheckPulse(),
          const SizedBox(height: 18),
          _SheetTitle(L('Locked in. Quiet high-five, ${client.persona}.',
              'Apuntado. Choca esos cinco en silencio, ${client.persona}.')),
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
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: t.ink),
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
                      text: CL('due diligence', 'la debida diligencia',
                          'chock timing', 'el momento de calzar'),
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

