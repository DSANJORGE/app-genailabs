import 'package:flutter/material.dart';
import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import 'admin_api.dart';
import 'admin_models.dart';
import 'admin_mastery.dart';
import 'admin_people.dart';
import 'admin_teams.dart';

class AdminSection {
  AdminSection(this.id, this.label, this.build);
  final String id;
  final String label;
  final Widget Function(AdminApi api, AdminMe me) build;
}

/// Sections the signed-in user may open: module enabled for the web surface AND at least the `_view` verb.
List<AdminSection> sectionsFor(AdminMe me) {
  final web = me.webModules.map((m) => m.id).toSet();
  return [
    if (web.contains('personas') && me.can('personas_view'))
      AdminSection('people', L('People', 'Colaboradores'), (api, me) => AdminPeople(api: api, me: me)),
    if (web.contains('personas') && me.can('personas_operate'))
      AdminSection('teams', L('Teams', 'Equipos'), (api, me) => AdminTeams(api: api, me: me)),
    if (web.contains('analytics') && me.can('analytics_view'))
      AdminSection('mastery', L('Mastery', 'Dominio'), (api, me) => AdminMastery(api: api, me: me)),
  ];
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.me, required this.api, required this.onSignOut});
  final AdminMe me;
  final AdminApi api;
  final VoidCallback onSignOut;
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final sections = sectionsFor(widget.me);
    if (sections.isEmpty) {
      // ponytail: plain message + sign-out; upgrade to a "contact your
      // administrator" flow (support link, request-access CTA) only if
      // someone asks -- this account state hasn't come up yet.
      return Scaffold(
        backgroundColor: t.bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                L('Your account has no console access.', 'Tu cuenta no tiene acceso a la consola.'),
                style: TextStyle(color: t.mut),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: widget.onSignOut, child: Text(L('Sign out', 'Cerrar sesión'))),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      body: Row(children: [
        NavigationRail(
          backgroundColor: t.card,
          selectedIndex: _i,
          onDestinationSelected: (i) => setState(() => _i = i),
          labelType: NavigationRailLabelType.all,
          leading: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(widget.me.name, style: TextStyle(color: t.mut, fontSize: 12)),
          ),
          trailing: IconButton(icon: Icon(Icons.logout, color: t.mut), onPressed: widget.onSignOut),
          destinations: [for (final s in sections) NavigationRailDestination(icon: const Icon(Icons.circle_outlined), label: Text(s.label))],
        ),
        // ponytail: rebuilds the section fresh on every rail switch (no
        // IndexedStack/keep-alive) -- fine for 3 shallow admin sections;
        // upgrade only if a section must keep an in-progress form alive
        // across tab switches.
        Expanded(child: sections[_i].build(widget.api, widget.me)),
      ]),
    );
  }
}
