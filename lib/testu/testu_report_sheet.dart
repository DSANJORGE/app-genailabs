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
  return showTestuSheet<void>(
    context,
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
            20, 0, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TestuGrabber(),
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
        Text(widget.title, style: kSheetTitle),
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
              TestuChip(
                r,
                selected: _picked == i,
                onTap: () => setState(() => _picked = i),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          minLines: 2,
          maxLines: 4,
          style: TextStyle(fontFamily: 'Geist', fontSize: 12.5, color: t.ink),
          decoration: testuFieldDecoration(t,
              hint: L('Anything else the team should know? (optional)',
                  '¿Algo más que el equipo deba saber? (opcional)'),
              fill: t.field,
              fontSize: 12.5),
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
            Text(L('Sent. Thank you.', 'Enviado. Gracias.'),
                style: kSheetTitle),
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
