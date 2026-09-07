import 'package:eme_app_package/eme_http.dart' show EmeHttpException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import '../testu/testu_widgets.dart';
import 'admin_api.dart';
import 'admin_models.dart';

/// Equipos: list of teams with parent/manager/location/cost center, add and
/// edit. Mirrors admin_people.dart's load/mutate/mounted pattern.
class AdminTeams extends StatefulWidget {
  const AdminTeams({super.key, required this.api, required this.me});
  final AdminApi api;
  final AdminMe me;

  @override
  State<AdminTeams> createState() => _AdminTeamsState();
}

class _AdminTeamsState extends State<AdminTeams> {
  List<AdminTeam>? _teams;
  List<AdminUser>? _users;
  Object? _error;

  bool get _canOperate => widget.me.can('personas_operate');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final teams = widget.api.teams();
    final users = widget.api.users();
    try {
      final t = await teams;
      final u = await users;
      if (!mounted) return;
      setState(() {
        _teams = t;
        _users = u;
        _error = null;
      });
    } on EmeHttpException {
      rethrow;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

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

  /// Users eligible as a team's manager: `manager` or `orgadmin` role.
  List<AdminUser> get _managers =>
      [for (final u in _users ?? const <AdminUser>[]) if (u.role == 'manager' || u.role == 'orgadmin') u];

  String _managerName(String? id) {
    if (id == null || id.isEmpty) return '—';
    final u = (_users ?? const <AdminUser>[]).where((u) => u.id == id).firstOrNull;
    return u?.name ?? id;
  }

  String _teamName(String? id) {
    if (id == null || id.isEmpty) return '—';
    final t = (_teams ?? const <AdminTeam>[]).where((t) => t.id == id).firstOrNull;
    return t?.name ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(L('Could not load teams.', 'No se pudieron cargar los equipos.'), style: TextStyle(color: t.mut)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: Text(L('Retry', 'Reintentar'))),
        ]),
      );
    }
    if (_teams == null || _users == null) {
      return Center(child: CircularProgressIndicator(color: t.mut));
    }
    final teams = _teams!;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            if (_canOperate)
              SizedBox(width: 140, child: TestuButton(L('New team', 'Nuevo equipo'), onTap: () => _openEdit(null))),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    DataColumn(label: Text(L('Id', 'Id'))),
                    DataColumn(label: Text(L('Name', 'Nombre'))),
                    DataColumn(label: Text(L('Parent', 'Padre'))),
                    DataColumn(label: Text('Manager')),
                    DataColumn(label: Text(L('Location', 'Ubicación'))),
                    DataColumn(label: Text(L('Cost center', 'Centro de costo'))),
                    DataColumn(label: Text(L('Members', 'Miembros'))),
                  ],
                  rows: [for (final team in teams) _rowFor(team, t)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _rowFor(AdminTeam team, TestuTokens t) => DataRow(
        onSelectChanged: _canOperate ? (_) => _openEdit(team) : null,
        cells: [
          DataCell(Text(team.id, style: TextStyle(color: t.mut))),
          DataCell(Text(team.name)),
          DataCell(Text(_teamName(team.parent), style: TextStyle(color: t.mut))),
          DataCell(Text(_managerName(team.manager), style: TextStyle(color: t.mut))),
          DataCell(Text(team.location ?? '—', style: TextStyle(color: t.mut))),
          DataCell(Text(team.costcenter ?? '—', style: TextStyle(color: t.mut))),
          DataCell(Text('${team.members}')),
        ],
      );

  // ponytail: no team deletion -- an unwanted team just empties out and
  // stays listed; add a delete endpoint when someone actually asks for it.
  Future<void> _openEdit(AdminTeam? existing) async {
    final id = TextEditingController(text: existing?.id ?? '');
    final name = TextEditingController(text: existing?.name ?? '');
    final location = TextEditingController(text: existing?.location ?? '');
    final costcenter = TextEditingController(text: existing?.costcenter ?? '');
    String? parent = existing?.parent;
    String? manager = existing?.manager;
    final teams = _teams!;
    final parentChoices = [for (final tm in teams) if (tm.id != existing?.id) tm];
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
                  Text(
                    existing == null ? L('New team', 'Nuevo equipo') : L('Edit team', 'Editar equipo'),
                    style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  if (existing == null) ...[
                    TextField(
                      controller: id,
                      autofocus: true,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-z0-9]'))],
                      decoration: InputDecoration(hintText: L('Id', 'Id')),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(controller: name, decoration: InputDecoration(hintText: L('Name', 'Nombre'))),
                  const SizedBox(height: 8),
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: parentChoices.any((tm) => tm.id == parent) ? parent : null,
                    hint: Text(L('Parent', 'Padre')),
                    items: [
                      DropdownMenuItem(value: null, child: Text(L('None', 'Ninguno'))),
                      for (final tm in parentChoices) DropdownMenuItem(value: tm.id, child: Text(tm.name)),
                    ],
                    onChanged: (v) => setD(() => parent = v),
                  ),
                  DropdownButton<String?>(
                    isExpanded: true,
                    value: _managers.any((u) => u.id == manager) ? manager : null,
                    hint: Text('Manager'),
                    items: [
                      DropdownMenuItem(value: null, child: Text(L('None', 'Ninguno'))),
                      for (final u in _managers) DropdownMenuItem(value: u.id, child: Text(u.name)),
                    ],
                    onChanged: (v) => setD(() => manager = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(controller: location, decoration: InputDecoration(hintText: L('Location', 'Ubicación'))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: costcenter,
                    decoration: InputDecoration(hintText: L('Cost center', 'Centro de costo')),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton(onPressed: () => Navigator.pop(dctx), child: Text(L('Cancel', 'Cancelar'))),
                    const SizedBox(width: 8),
                    TestuAct(
                      L('Save', 'Guardar'),
                      primary: true,
                      onTap: () {
                        final teamId = existing?.id ?? id.text.trim();
                        final teamName = name.text.trim();
                        if (teamId.isEmpty || teamName.isEmpty) return;
                        Navigator.pop(dctx);
                        _mutate(() => widget.api.saveTeam(AdminTeam(
                              id: teamId,
                              name: teamName,
                              parent: parent,
                              manager: manager,
                              location: location.text.trim(),
                              costcenter: costcenter.text.trim(),
                              members: existing?.members ?? 0,
                            )));
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
}
