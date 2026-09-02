import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// THE report surface — question reports, comment reports, any future
/// "send this to a human team" flow. One visual grammar for all of them:
/// the app's bottom-sheet language (same chrome as the schedule sheet),
/// reason chips + optional note, and the shared green check-pulse success.
/// No Material AlertDialog anywhere in this app.
Future<void> showTestuReportSheet(
  BuildContext context, {
  required String eyebrow,
  required String title,
  required String subtitle,
  required List<String> reasons,
  required void Function(String reason, String? note) onSend,
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
    // maxWidth restores Material's landscape sheet cap (passing constraints
    // replaces the default) — matches the schedule/resource/PDF sheets.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      maxWidth: 640,
    ),
    builder: (_) => _ReportSheetBody(
      eyebrow: eyebrow,
      title: title,
      subtitle: subtitle,
      reasons: reasons,
      onSend: onSend,
    ),
  );
}

class _ReportSheetBody extends StatefulWidget {
  const _ReportSheetBody({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.reasons,
    required this.onSend,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<String> reasons;
  final void Function(String reason, String? note) onSend;

  @override
  State<_ReportSheetBody> createState() => _ReportSheetBodyState();
}

class _ReportSheetBodyState extends State<_ReportSheetBody> {
  int? _picked;
  bool _sent = false;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _send() {
    HapticFeedback.mediumImpact();
    widget.onSend(widget.reasons[_picked!],
        _note.text.trim().isEmpty ? null : _note.text.trim());
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20, 10, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_sent)
              _sentView(t)
            else
              ..._formChildren(t),
          ],
        ),
      ),
    );
  }

  List<Widget> _formChildren(TestuTokens t) => [
        TestuEyebrow(widget.eyebrow, color: t.amber),
        const SizedBox(height: 6),
        Text(
          widget.title,
          style: TextStyle(
            fontFamily: 'Sora',
            fontWeight: FontWeight.w700,
            fontSize: 17,
            letterSpacing: -0.17,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.subtitle,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 12.5,
            height: 1.6,
            color: t.mut,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, r) in widget.reasons.indexed)
              TestuPressable(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _picked = i);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 13),
                  decoration: BoxDecoration(
                    color: _picked == i ? const Color(0xFF232327) : null,
                    border: Border.all(
                        color:
                            _picked == i ? const Color(0xFF4A4A52) : t.line2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    r,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11.5,
                      fontWeight:
                          _picked == i ? FontWeight.w600 : FontWeight.w400,
                      color: _picked == i ? t.ink : t.mut,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 4,
          style: TextStyle(fontFamily: 'Geist', fontSize: 12.5, color: t.ink),
          decoration: InputDecoration(
            hintText: L('Anything else the team should know? (optional)',
                '¿Algo más que el equipo deba saber? (opcional)'),
            hintStyle: TextStyle(
                fontFamily: 'Geist', fontSize: 12, color: t.faint),
            filled: true,
            fillColor: const Color(0xFF101013),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.line2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.line2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF4A4A52)),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 18),
        TestuButton(
          _picked == null
              ? L('PICK A REASON TO SEND', 'ELIGE UN MOTIVO PARA ENVIAR')
              : L('SEND TO CONTENT TEAM', 'ENVIAR AL EQUIPO DE CONTENIDO'),
          variant: TestuButtonVariant.primary,
          onTap: _picked == null ? null : _send,
        ),
      ];

  Widget _sentView(TestuTokens t) => SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            const SizedBox(height: 18),
            const TestuCheckPulse(),
            const SizedBox(height: 18),
            Text(
              L('Sent. Thank you.', 'Enviado. Gracias.'),
              style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 290),
              child: Text(
                L('The content team will review it. You’ll hear back in Notifications.',
                    'El equipo de contenido lo revisará. Te avisaremos en Notificaciones.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12.5,
                  height: 1.65,
                  color: t.mut,
                ),
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
