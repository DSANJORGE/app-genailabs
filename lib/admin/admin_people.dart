import 'package:eme_app_package/eme_http.dart' show EmeHttpException;
import 'package:flutter/material.dart';
import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import 'admin_api.dart';
import 'admin_csv.dart';
import 'admin_models.dart';
import 'admin_nav.dart';
import 'admin_reading.dart';
import 'admin_theme.dart';
import 'admin_ui.dart';

const _roles = ['users', 'manager', 'training', 'orgadmin'];

/// Colaboradores: list + filter, add, team/role changes, disable, CSV import.
class AdminPeople extends StatefulWidget {
  const AdminPeople({super.key, required this.api, required this.me, required this.nav});
  final AdminApi api;
  final AdminMe me;
  final ConsoleNav nav;

  @override
  State<AdminPeople> createState() => _AdminPeopleState();
}

class _AdminPeopleState extends State<AdminPeople> {
  List<AdminUser>? _users;
  List<AdminTeam>? _teams;
  Object? _error;
  final _search = TextEditingController();

  bool get _canOperate => widget.me.can('personas_operate');
  bool get _canManage => widget.me.can('personas_manage');
  bool get _canViewProfile => widget.me.can('analytics_view');

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Both reads in flight at once, joined by `Future.wait` -- awaiting them
  /// one after the other leaves the second future's failure unhandled when
  /// the first one throws, which is an error nobody catches and a screen
  /// stuck on its skeleton.
  Future<void> _load() async {
    try {
      final r = await Future.wait<Object>(
          [widget.api.users(), widget.api.teams()]);
      if (!mounted) return;
      setState(() {
        _users = r[0] as List<AdminUser>;
        _teams = r[1] as List<AdminTeam>;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// Runs a mutating call, reloads the list on success, toasts on a plain
  /// Exception. EmeHttpException (401/403) is rethrown -- the
  /// AdminSession.onSignedOut hook already fired at the HTTP layer; this
  /// screen doesn't get to handle it too.
  Future<void> _mutate(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on EmeHttpException {
      rethrow;
    } catch (e) {
      if (!mounted) return;
      showToast(context, errText(e), error: true);
    }
  }

  /// A team id resolved to its name -- the one lookup the Team cell, its
  /// sort key and the search box all share, so a search for "Norte" matches
  /// what the cell actually shows rather than the id underneath it.
  String _teamName(String? id) {
    if (id == null || id.isEmpty) return '';
    return (_teams ?? const <AdminTeam>[]).where((t) => t.id == id).firstOrNull?.name ?? '';
  }

  List<AdminUser> get _filtered {
    final users = _users ?? const <AdminUser>[];
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return users;
    return [
      for (final u in users)
        if (u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            _teamName(u.team).toLowerCase().contains(q))
          u,
    ];
  }

  /// `disableuser.json` 403s when the target is `orgadmin`/`training` and the
  /// caller lacks `personas_manage` -- a 403 signs the whole console out, so
  /// the button has to know the rule before the user ever clicks it, not
  /// just react to the failure.
  bool _canDisable(AdminUser u) {
    if (!_canOperate) return false;
    final restricted = u.role == 'orgadmin' || u.role == 'training';
    return !restricted || _canManage;
  }

  @override
  Widget build(BuildContext context) => crossfade(_body(context));

  Widget _body(BuildContext context) {
    if (_error != null) {
      return ConsolePanelError(
        text: L('Could not load people.', 'No se pudieron cargar los colaboradores.'),
        onRetry: _load,
      );
    }
    if (_users == null || _teams == null) {
      return const Skeleton(lines: 6, height: 22);
    }
    final t = TestuTokens.of(context);
    final teams = _teams!;
    // No inset of its own: the scaffold already pads the content column, and
    // a second 20 px put this table's left edge 20 px right of the title's.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: _searchField(t)),
          if (_canOperate) ...[
            const SizedBox(width: 10),
            ConsoleAct(L('Add', 'Añadir'), onTap: () => _openAdd(teams)),
            const SizedBox(width: 8),
            ConsoleAct(L('Import CSV', 'Importar CSV'),
                onTap: () => _openImport(teams)),
          ],
        ]),
        const SizedBox(height: 16),
        _table(teams, t),
        if (_canViewProfile) ...[
          const SizedBox(height: 10),
          Text(L('Click a row to open the profile.', 'Haz clic en una fila para ver la ficha.'),
              style: AdminTokens.footnote),
        ],
      ],
    );
  }

  /// The search pill, on the same 28 px line as the acts beside it: 11.5 px
  /// like a [Select], 6 px of vertical padding like one.
  Widget _searchField(TestuTokens t) => TextField(
        controller: _search,
        style: TextStyle(fontFamily: 'Geist', fontSize: 11.5, color: t.ink),
        decoration: InputDecoration(
          hintText: L('Search by name, email or team', 'Buscar por nombre, correo o equipo'),
          hintStyle: TextStyle(fontFamily: 'Geist', fontSize: 11.5, color: t.mut),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: t.line2)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: t.line2)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: AdminTokens.focus)),
        ),
      );

  Widget _table(List<AdminTeam> teams, TestuTokens t) => AdminTable<AdminUser>(
        rows: _filtered,
        onTap: _canViewProfile ? (u) => widget.nav.go('person', entityId: u.id) : null,
        emptyText: _search.text.trim().isEmpty
            ? L('No collaborators yet.', 'Todavía no hay colaboradores.')
            : L('No one matches.', 'Nadie coincide.'),
        columns: [
          AdminColumn(
            L('Name', 'Nombre'),
            (u) => Text(u.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            sortKey: (u) => u.name,
            flex: 3,
          ),
          AdminColumn(
            L('Email', 'Correo'),
            (u) => Text(u.email, style: TextStyle(color: t.mut), maxLines: 1, overflow: TextOverflow.ellipsis),
            sortKey: (u) => u.email,
            flex: 3,
          ),
          // Fixed, not flexed: these two cells hold controls, and a control
          // squeezed to "Oper…" is worse than a table that scrolls. 140 fits
          // "Mantenimiento" and "Training / L&D" whole and leaves the longer
          // names one tooltip away.
          AdminColumn(
            L('Team', 'Equipo'),
            (u) => _teamCell(u, teams, t),
            sortKey: (u) => _teamName(u.team),
            width: 140,
          ),
          AdminColumn(
            L('Role', 'Rol'),
            (u) => _roleCell(u, t),
            sortKey: (u) => roleLabel(u.role),
            width: 140,
          ),
          AdminColumn(
            L('Last activity', 'Última actividad'),
            (u) => Text(date(u.lastActivity), style: AdminTokens.mono(11.5)),
            sortKey: (u) => u.lastActivity?.millisecondsSinceEpoch ?? 0,
            // 100, not 80: "Última actividad" at 11 px is 92 px, and at 80
            // the header read "Última activi…" over every row.
            width: 100,
            numeric: true,
          ),
          AdminColumn(
            L('Status', 'Estado'),
            (u) => Text(
              u.enabled ? L('Active', 'Activo') : L('Inactive', 'Inactivo'),
              // Both states are table body text and must clear 4.5:1 on
              // `card` -- `faint` doesn't, `mut` does.
              style: TextStyle(color: u.enabled ? t.green : t.mut),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            sortKey: (u) => u.enabled ? 0 : 1,
            width: 65,
          ),
          AdminColumn('', (u) => _actions(u, t), width: 90),
        ],
      );

  Widget _teamCell(AdminUser u, List<AdminTeam> teams, TestuTokens t) {
    if (!_canOperate) {
      final name = _teamName(u.team);
      return Text(name.isEmpty ? '—' : name,
          style: TextStyle(color: t.mut), maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Select<String>(
      value: teams.any((x) => x.id == u.team) ? u.team : null,
      hint: L('None', 'Ninguno'),
      fill: true,
      semanticLabel: L('Change team', 'Cambiar equipo'),
      items: [
        (null, L('None', 'Ninguno')),
        for (final team in teams) (team.id, team.name),
      ],
      onChanged: (v) => _mutate(() => widget.api.setTeam(u.id, v)),
    );
  }

  Widget _roleCell(AdminUser u, TestuTokens t) {
    if (!_canManage) {
      return Text(roleLabel(u.role), style: TextStyle(color: t.mut), maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    return Select<String>(
      value: u.role,
      fill: true,
      semanticLabel: L('Change role', 'Cambiar rol'),
      items: [for (final r in _roles) (r, roleLabel(r))],
      onChanged: (v) => v == null ? null : _mutate(() => widget.api.setRole(u.id, v)),
    );
  }

  Widget _actions(AdminUser u, TestuTokens t) {
    if (!_canDisable(u)) return const SizedBox.shrink();
    final isSelf = u.id == widget.me.id;
    return TextButton(
      onPressed: (isSelf || !u.enabled) ? null : () => _mutate(() => widget.api.disableUser(u.id)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 28),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: AdminTokens.redText,
        // `faint` is for mono eyebrows only (constraints, R10).
        disabledForegroundColor: t.mut.withValues(alpha: 0.6),
        textStyle: const TextStyle(fontFamily: 'Geist', fontSize: 12, fontWeight: FontWeight.w500),
      ),
      child: Text(L('Disable', 'Desactivar')),
    );
  }

  Future<void> _openAdd(List<AdminTeam> teams) async {
    final email = TextEditingController();
    final first = TextEditingController();
    final last = TextEditingController();
    String? team;
    var role = 'users';
    final roles = ['users', 'manager', if (_canManage) ...['training', 'orgadmin']];
    final t = TestuTokens.of(context);
    await showConsoleForm(
      context,
      title: L('Add collaborator', 'Añadir colaborador'),
      fields: (dctx, setD) => [
        TextField(
          controller: email,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          style: AdminTokens.table,
          decoration: consoleField(t, hint: L('Email', 'Correo')),
        ),
        const SizedBox(height: 8),
        TextField(
            controller: first,
            style: AdminTokens.table,
            decoration: consoleField(t, hint: L('First name', 'Nombre'))),
        const SizedBox(height: 8),
        TextField(
            controller: last,
            style: AdminTokens.table,
            decoration: consoleField(t, hint: L('Last name', 'Apellidos'))),
        const SizedBox(height: 8),
        Select<String>(
          value: team,
          hint: L('Team', 'Equipo'),
          fill: true,
          items: [
            (null, L('None', 'Ninguno')),
            for (final tm in teams) (tm.id, tm.name),
          ],
          onChanged: (v) => setD(() => team = v),
        ),
        const SizedBox(height: 8),
        Select<String>(
          value: role,
          fill: true,
          items: [for (final r in roles) (r, roleLabel(r))],
          onChanged: (v) => setD(() => role = v ?? role),
        ),
      ],
      primary: (dctx, _) => ConsoleAct(
        L('Save', 'Guardar'),
        primary: true,
        onTap: () {
          final e = email.text.trim();
          if (e.isEmpty) return;
          Navigator.pop(dctx);
          _mutate(() => widget.api.createUser(
                email: e,
                firstName: first.text.trim(),
                lastName: last.text.trim(),
                team: team,
                role: role,
              ));
        },
      ),
    );
  }

  Future<void> _openImport(List<AdminTeam> teams) async {
    final textCtl = TextEditingController();
    final teamIds = {for (final tm in teams) tm.id};
    final existing = {for (final u in _users!) u.email};
    CsvImport? preview;
    final t = TestuTokens.of(context);
    await showConsoleForm(
      context,
      title: L('Import CSV', 'Importar CSV'),
      width: 560,
      fields: (dctx, setD) => [
        Text(
          // ponytail: paste-in text field rather than a file picker; add
          // file_picker only if Minsur asks for a real file upload.
          L('Paste the CSV text (header: email,firstName,lastName,team).',
              'Pega el texto CSV (encabezado: email,firstName,lastName,team).'),
          style: AdminTokens.muted,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: textCtl,
          maxLines: 6,
          style: AdminTokens.mono(12),
          decoration: consoleField(t),
          onChanged: (v) => setD(() => preview =
              v.trim().isEmpty ? null : parseUsersCsv(v, teamIds: teamIds, existingEmails: existing)),
        ),
        const SizedBox(height: 12),
        if (preview != null && preview!.rows.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: SingleChildScrollView(
              child: AdminTable<CsvRow>(
                rows: preview!.rows,
                columns: [
                  AdminColumn(L('Email', 'Correo'), (r) => Text(r.email), flex: 3),
                  AdminColumn(L('Name', 'Nombre'), (r) => Text('${r.firstName} ${r.lastName}'.trim()), flex: 2),
                  AdminColumn(L('Team', 'Equipo'), (r) => Text(r.team), width: 100),
                  AdminColumn(
                    L('Error', 'Error'),
                    (r) => Text(r.error ?? '',
                        style: TextStyle(color: r.error == null ? t.green : AdminTokens.redText)),
                    flex: 2,
                  ),
                ],
              ),
            ),
          ),
        // What the paste amounts to, before anything is sent. A
        // preview table with an Error column on every row and a
        // disabled button was the whole explanation until now.
        if (preview != null) ...[
          const SizedBox(height: 10),
          Text(_csvSummary(preview!), style: AdminTokens.footnote),
        ],
      ],
      primary: (dctx, _) => ConsoleAct(
        L('Import ${preview?.valid.length ?? 0} rows', 'Importar ${preview?.valid.length ?? 0} filas'),
        primary: true,
        onTap: (preview?.valid.isNotEmpty ?? false)
            ? () {
                final bytes = preview!.toCsvBytes();
                Navigator.pop(dctx);
                _mutate(() async {
                  final n = await widget.api.importUsers(bytes);
                  if (mounted) {
                    showToast(context, L('Imported $n', 'Importadas $n'));
                  }
                });
              }
            : null,
      ),
    );
  }
}

/// The import preview in one line: what will be created, what was rejected,
/// or why nothing was recognised at all. The dialog's own empty and error
/// state -- a table of red cells does not tell a reader what to do next.
String _csvSummary(CsvImport preview) {
  if (preview.missingColumns.isNotEmpty) {
    final missing = preview.missingColumns.join(', ');
    return L(
      'The header is missing $missing. The first line has to be: '
          'email,firstName,lastName,team.',
      'Al encabezado le faltan $missing. La primera línea debe ser: '
          'email,firstName,lastName,team.',
    );
  }
  if (preview.rows.isEmpty) {
    return L(
      'No rows recognised. The first line has to be the header: '
          'email,firstName,lastName,team.',
      'No se reconoció ninguna fila. La primera línea debe ser el encabezado: '
          'email,firstName,lastName,team.',
    );
  }
  final ok = preview.valid.length;
  final bad = preview.rows.length - ok;
  if (ok == 0) {
    return L('No row can be imported: fix the $bad below and paste again.',
        'No se puede importar ninguna fila: corrige las $bad de abajo y '
            'vuelve a pegar.');
  }
  return bad == 0
      ? L('$ok rows ready to import.', '$ok filas listas para importar.')
      : L('$ok rows ready · $bad rejected, listed below.',
          '$ok filas listas · $bad descartadas, con el motivo abajo.');
}
