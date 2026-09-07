import 'package:eme_app_package/eme_http.dart' show EmeHttpException;
import 'package:flutter/material.dart';
import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import '../testu/testu_widgets.dart';
import 'admin_api.dart';
import 'admin_csv.dart';
import 'admin_models.dart';

const _roles = ['users', 'manager', 'training', 'orgadmin'];

String _roleLabel(String role) => switch (role) {
      'users' => L('Learner', 'Colaborador'),
      'manager' => 'Manager',
      'training' => 'Training / L&D',
      'orgadmin' => L('Org admin', 'Admin de organización'),
      _ => role,
    };

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

/// Colaboradores: list + filter, add, team/role changes, disable, CSV import.
class AdminPeople extends StatefulWidget {
  const AdminPeople({super.key, required this.api, required this.me});
  final AdminApi api;
  final AdminMe me;

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

  Future<void> _load() async {
    final users = widget.api.users();
    final teams = widget.api.teams();
    try {
      final u = await users;
      final t = await teams;
      if (!mounted) return;
      setState(() {
        _users = u;
        _teams = t;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  /// Runs a mutating call, reloads the list on success, shows a SnackBar on
  /// a plain Exception. EmeHttpException (401/403) is rethrown -- the
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
    }
  }

  List<AdminUser> get _filtered {
    final users = _users ?? const <AdminUser>[];
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return users;
    return [
      for (final u in users)
        if (u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.team ?? '').toLowerCase().contains(q))
          u,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(L('Could not load people.', 'No se pudieron cargar los colaboradores.'), style: TextStyle(color: t.mut)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: Text(L('Retry', 'Reintentar'))),
        ]),
      );
    }
    if (_users == null || _teams == null) {
      return Center(child: CircularProgressIndicator(color: t.mut));
    }
    final teams = _teams!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  hintText: L('Search by name, email or team', 'Buscar por nombre, correo o equipo'),
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            if (_canOperate) ...[
              const SizedBox(width: 12),
              SizedBox(width: 140, child: TestuButton(L('Add', 'Añadir'), onTap: () => _openAdd(teams))),
              const SizedBox(width: 12),
              SizedBox(width: 160, child: TestuButton(L('Import CSV', 'Importar CSV'), onTap: () => _openImport(teams))),
            ],
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(L('Name', 'Nombre'))),
                    DataColumn(label: Text(L('Email', 'Correo'))),
                    DataColumn(label: Text(L('Team', 'Equipo'))),
                    DataColumn(label: Text(L('Role', 'Rol'))),
                    DataColumn(label: Text(L('Last activity', 'Última actividad'))),
                    DataColumn(label: Text(L('Status', 'Estado'))),
                    const DataColumn(label: Text('')),
                  ],
                  rows: [for (final u in _filtered) _rowFor(u, teams, t)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _rowFor(AdminUser u, List<AdminTeam> teams, TestuTokens t) {
    final isSelf = u.id == widget.me.id;
    return DataRow(cells: [
      DataCell(Text(u.name)),
      DataCell(Text(u.email, style: TextStyle(color: t.mut))),
      DataCell(_canOperate
          ? DropdownButton<String?>(
              value: teams.any((x) => x.id == u.team) ? u.team : null,
              hint: Text(L('None', 'Ninguno')),
              items: [
                DropdownMenuItem(value: null, child: Text(L('None', 'Ninguno'))),
                for (final team in teams) DropdownMenuItem(value: team.id, child: Text(team.name)),
              ],
              onChanged: (v) => _mutate(() => widget.api.setTeam(u.id, v)),
            )
          : Text(u.team ?? '—', style: TextStyle(color: t.mut)))
      ,
      DataCell(_canManage
          ? DropdownButton<String>(
              value: u.role,
              items: [for (final r in _roles) DropdownMenuItem(value: r, child: Text(_roleLabel(r)))],
              onChanged: (v) => v == null ? null : _mutate(() => widget.api.setRole(u.id, v)),
            )
          : Text(_roleLabel(u.role), style: TextStyle(color: t.mut))),
      DataCell(Text(_fmtDate(u.lastActivity), style: TextStyle(color: t.mut))),
      DataCell(Text(
        u.enabled ? L('Active', 'Activo') : L('Inactive', 'Inactivo'),
        style: TextStyle(color: u.enabled ? t.green : t.faint),
      )),
      DataCell(_canOperate
          ? IconButton(
              icon: Icon(Icons.block, color: t.red),
              tooltip: L('Disable', 'Desactivar'),
              onPressed: (isSelf || !u.enabled) ? null : () => _mutate(() => widget.api.disableUser(u.id)),
            )
          : const SizedBox.shrink()),
    ]);
  }

  Future<void> _openAdd(List<AdminTeam> teams) async {
    final email = TextEditingController();
    final first = TextEditingController();
    final last = TextEditingController();
    String? team;
    var role = 'users';
    final roles = ['users', 'manager', if (_canManage) ...['training', 'orgadmin']];
    final t = TestuTokens.of(context);
    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => Dialog(
          backgroundColor: t.card,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: t.line2)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(L('Add collaborator', 'Añadir colaborador'),
                      style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: email,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(hintText: L('Email', 'Correo')),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: first, decoration: InputDecoration(hintText: L('First name', 'Nombre'))),
                  const SizedBox(height: 8),
                  TextField(controller: last, decoration: InputDecoration(hintText: L('Last name', 'Apellidos'))),
                  const SizedBox(height: 8),
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: team,
                    hint: Text(L('Team', 'Equipo')),
                    items: [
                      DropdownMenuItem(value: null, child: Text(L('None', 'Ninguno'))),
                      for (final tm in teams) DropdownMenuItem(value: tm.id, child: Text(tm.name)),
                    ],
                    onChanged: (v) => setD(() => team = v),
                  ),
                  DropdownButton<String>(
                    isExpanded: true,
                    value: role,
                    items: [for (final r in roles) DropdownMenuItem(value: r, child: Text(_roleLabel(r)))],
                    onChanged: (v) => setD(() => role = v ?? role),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(dctx), child: Text(L('Cancel', 'Cancelar'))),
                    const SizedBox(width: 8),
                    TestuAct(
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
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openImport(List<AdminTeam> teams) async {
    final textCtl = TextEditingController();
    final teamIds = {for (final tm in teams) tm.id};
    final existing = {for (final u in _users!) u.email};
    CsvImport? preview;
    final t = TestuTokens.of(context);
    await showDialog<void>(
      context: context,
      builder: (dctx) => StatefulBuilder(
        builder: (dctx, setD) => Dialog(
          backgroundColor: t.card,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: t.line2)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(L('Import CSV', 'Importar CSV'),
                      style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    // ponytail: paste-in text field rather than a file picker; add
                    // file_picker only if Minsur asks for a real file upload.
                    L('Paste the CSV text (header: email,firstName,lastName,team).',
                        'Pega el texto CSV (encabezado: email,firstName,lastName,team).'),
                    style: TextStyle(color: t.faint, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: textCtl,
                    maxLines: 6,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    onChanged: (v) => setD(() => preview =
                        v.trim().isEmpty ? null : parseUsersCsv(v, teamIds: teamIds, existingEmails: existing)),
                  ),
                  const SizedBox(height: 12),
                  if (preview != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: DataTable(
                          columns: [
                            DataColumn(label: Text(L('Email', 'Correo'))),
                            DataColumn(label: Text(L('Name', 'Nombre'))),
                            DataColumn(label: Text(L('Team', 'Equipo'))),
                            DataColumn(label: Text(L('Error', 'Error'))),
                          ],
                          rows: [
                            for (final r in preview!.rows)
                              DataRow(cells: [
                                DataCell(Text(r.email)),
                                DataCell(Text('${r.firstName} ${r.lastName}'.trim())),
                                DataCell(Text(r.team)),
                                DataCell(Text(r.error ?? '', style: TextStyle(color: r.error == null ? t.green : t.red))),
                              ]),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(dctx), child: Text(L('Cancel', 'Cancelar'))),
                    const SizedBox(width: 8),
                    TestuAct(
                      L('Import ${preview?.valid.length ?? 0} rows', 'Importar ${preview?.valid.length ?? 0} filas'),
                      primary: true,
                      onTap: (preview?.valid.isNotEmpty ?? false)
                          ? () {
                              final bytes = preview!.toCsvBytes();
                              Navigator.pop(dctx);
                              _mutate(() async {
                                final n = await widget.api.importUsers(bytes);
                                if (mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(content: Text(L('Imported $n', 'Importadas $n'))));
                                }
                              });
                            }
                          : null,
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
