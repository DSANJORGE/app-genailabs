import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import '../testu/testu_social.dart';
import '../testu/testu_social_api.dart';
import '../testu/testu_theme.dart';
import 'admin_api.dart';
import 'admin_models.dart';
import 'admin_reading.dart' show date;
import 'admin_theme.dart';
import 'admin_ui.dart';

/// Conversaciones: the newest comments across the viewer's scope, the open
/// question reports, and the one place an instructor or manager replies.
/// The thread itself is the app's own TestuThread on the console's http:
/// reply, react and report work exactly as they do on the phone.
class AdminThreads extends StatefulWidget {
  const AdminThreads({super.key, required this.api, required this.me});
  final AdminApi api;
  final AdminMe me;

  @override
  State<AdminThreads> createState() => _AdminThreadsState();
}

class _AdminThreadsState extends State<AdminThreads> {
  SocialRecent? _data;
  Object? _error;
  RecentComment? _open;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await widget.api.social.recent();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) => crossfade(_body(context));

  Widget _body(BuildContext context) {
    if (_error != null) {
      return ConsolePanelError(
        text: L('Could not load conversations.', 'No se pudieron cargar las conversaciones.'),
        onRetry: _load,
      );
    }
    final d = _data;
    if (d == null) return const Skeleton(lines: 6, height: 22);
    if (d.comments.isEmpty && d.flags.isEmpty) {
      return EmptyState(
        eyebrow: L('Conversations', 'Conversaciones'),
        text: L('Nobody has commented or reported a question yet.',
            'Nadie ha comentado ni reportado una pregunta todavía.'),
      );
    }
    final t = TestuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (d.flags.isNotEmpty) ...[
          Text(L('QUESTION REPORTS · ${d.flags.length}', 'REPORTES DE PREGUNTAS · ${d.flags.length}'),
              style: AdminTokens.eyebrow),
          const SizedBox(height: 8),
          _flags(d.flags, t),
          const SizedBox(height: 6),
          // ponytail: read-only list; resolving is a later console task (spec C2).
          Text(L('Open reports from learners in your scope.', 'Reportes abiertos de colaboradores en tu ámbito.'),
              style: AdminTokens.footnote),
          const SizedBox(height: 24),
        ],
        Text(L('RECENT COMMENTS', 'COMENTARIOS RECIENTES'), style: AdminTokens.eyebrow),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _recent(d.comments, t)),
            if (_open != null) ...[
              const SizedBox(width: 24),
              SizedBox(width: 440, child: _thread(_open!, t)),
            ],
          ],
        ),
        if (_open == null) ...[
          const SizedBox(height: 10),
          Text(L('Click a comment to open its conversation.', 'Haz clic en un comentario para abrir la conversación.'),
              style: AdminTokens.footnote),
        ],
      ],
    );
  }

  Widget _flags(List<QuestionFlagRow> rows, TestuTokens t) => AdminTable<QuestionFlagRow>(
        rows: rows,
        columns: [
          AdminColumn(L('Date', 'Fecha'), (f) => Text(date(f.date), style: AdminTokens.mono(11.5)),
              sortKey: (f) => f.date?.millisecondsSinceEpoch ?? 0, width: 100),
          AdminColumn(L('Question', 'Pregunta'),
              (f) => Text(f.label, maxLines: 2, overflow: TextOverflow.ellipsis),
              sortKey: (f) => f.label, flex: 3),
          AdminColumn(L('Reason', 'Motivo'), (f) => Text(flagReasonLabel(f.reason)),
              sortKey: (f) => f.reason, width: 180),
          AdminColumn(L('Note', 'Nota'),
              (f) => Text(f.note, style: TextStyle(color: t.mut), maxLines: 2, overflow: TextOverflow.ellipsis),
              flex: 3),
          AdminColumn(L('By', 'De'), (f) => Text(f.who, maxLines: 1, overflow: TextOverflow.ellipsis),
              sortKey: (f) => f.who, flex: 2),
        ],
      );

  Widget _recent(List<RecentComment> rows, TestuTokens t) => AdminTable<RecentComment>(
        rows: rows,
        onTap: (r) => setState(() => _open = r),
        emptyText: L('No comments yet.', 'Todavía no hay comentarios.'),
        columns: [
          AdminColumn(L('Date', 'Fecha'), (r) => Text(date(r.date), style: AdminTokens.mono(11.5)),
              sortKey: (r) => r.date?.millisecondsSinceEpoch ?? 0, width: 100),
          AdminColumn(
            L('Who', 'Quién'),
            (r) => Text(
                roleBadge(r.role) == null ? r.who : '${r.who} · ${roleBadge(r.role)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            sortKey: (r) => r.who,
            flex: 2,
          ),
          AdminColumn(L('Where', 'Dónde'),
              (r) => Text(r.label, style: TextStyle(color: t.mut), maxLines: 1, overflow: TextOverflow.ellipsis),
              sortKey: (r) => r.label, flex: 3),
          AdminColumn(L('Comment', 'Comentario'),
              (r) => Text(r.text, maxLines: 2, overflow: TextOverflow.ellipsis), flex: 4),
        ],
      );

  Widget _thread(RecentComment r, TestuTokens t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(r.label,
                  style: AdminTokens.table.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            ConsoleAct(L('Close', 'Cerrar'), onTap: () => setState(() => _open = null)),
          ]),
          const SizedBox(height: 12),
          TestuThread(
            key: ValueKey('console-${r.channel}'),
            channel: r.channel,
            api: widget.api.social,
            composerHint: L('Reply as ${roleLabel(widget.me.role)}…',
                'Responde como ${roleLabel(widget.me.role)}…'),
            reportEyebrow: L('CONVERSATION · REPORT', 'CONVERSACIÓN · REPORTAR'),
            reportTitle: L('Report this comment', 'Reportar este comentario'),
            // A reply from here is a new recent row too.
            onChanged: _load,
          ),
        ],
      );
}
