import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import 'admin_api.dart';
import 'admin_mastery.dart';
import 'admin_models.dart';
import 'admin_nav.dart';
import 'admin_people.dart';
import 'admin_teams.dart';
import 'admin_ui.dart';

/// One entry of the console nav: the id [ConsoleNav.go] takes, and what the
/// nav calls it. What each id renders is decided in one place,
/// [_AdminShellState._page] -- a section is a route, not a widget factory.
class AdminSection {
  const AdminSection(this.id, this.label);
  final String id, label;
}

/// Sections the signed-in user may open: the module enabled for the web
/// surface AND the matching `_view` verb (spec analytics-v1 §6). Resumen,
/// Actividad and Dominio are the analytics trio and stand or fall together;
/// Colaboradores needs `personas_view`, Equipos `personas_operate`.
List<AdminSection> sectionsFor(AdminMe me) {
  final web = me.webModules.map((m) => m.id).toSet();
  final analytics = web.contains('analytics') && me.can('analytics_view');
  final personas = web.contains('personas');
  return [
    if (analytics) ...[
      AdminSection('overview', L('Overview', 'Resumen')),
      AdminSection('activity', L('Activity', 'Actividad')),
      AdminSection('mastery', L('Mastery', 'Dominio')),
    ],
    if (personas && me.can('personas_view')) AdminSection('people', L('People', 'Colaboradores')),
    if (personas && me.can('personas_operate')) AdminSection('teams', L('Teams', 'Equipos')),
  ];
}

/// The console frame. It owns the three pieces every screen shares -- one
/// [ConsoleNav], one [AnalyticsFilters], and one cache of topic and team
/// names for the context bar -- so no two screens can disagree about where
/// the user is or what window they are looking at.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.me, required this.api, required this.onSignOut});
  final AdminMe me;
  final AdminApi api;
  final VoidCallback onSignOut;
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> with WidgetsBindingObserver {
  final _nav = ConsoleNav();
  final _filters = AnalyticsFilters();
  late final List<AdminSection> _sections;

  /// Topic id → name, and the teams in scope: the two label sources the
  /// context bar needs, fetched once for the whole session.
  Map<String, String> _topics = const {};
  List<AdminTeam> _teams = const [];

  /// The Iris panel toggle. Task 16 puts the panel behind it; keeping the
  /// state here is what will let one thread follow the user across screens.
  final bool _iris = false;

  /// True while a browser back/forward is being applied, so the resulting
  /// route change does not push the entry we are already standing on.
  bool _syncing = false;

  /// Drill pages are analytics, so they need the same permission the
  /// analytics sections do -- and an entity to be about.
  bool get _drill => _sections.any((s) => s.id == 'overview');

  bool _canOpen(ConsoleRoute r) => switch (r.section) {
    'person' || 'team' => _drill && (r.entityId ?? '').isNotEmpty,
    _ => _sections.any((s) => s.id == r.section),
  };

  @override
  void initState() {
    super.initState();
    _sections = sectionsFor(widget.me);
    if (_sections.isEmpty) return;
    // A reload or a pasted link lands on the section in the URL; anything
    // else opens on the first thing the user may see.
    _nav.value = (kIsWeb ? _fromUri(Uri.base) : null) ?? ConsoleRoute(_sections.first.id);
    // Give the first entry a real address, so browser back from the first
    // drill lands on a URL this shell can read again.
    if (kIsWeb) {
      SystemNavigator.routeInformationUpdated(uri: _uriOf(_nav.value), replace: true);
    }
    _nav.addListener(_pushHistory);
    WidgetsBinding.instance.addObserver(this);
    _loadLabels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nav.removeListener(_pushHistory);
    _nav.dispose();
    _filters.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------- history

  /// ponytail: `/section?id=…` through the engine's own history, no router
  /// package. Enough for back, forward and a pasted link; a real router only
  /// pays for itself once the console has nested routes.
  void _pushHistory() {
    if (!kIsWeb || _syncing) return;
    SystemNavigator.routeInformationUpdated(uri: _uriOf(_nav.value));
  }

  Uri _uriOf(ConsoleRoute r) => Uri(
    path: '/${r.section}',
    queryParameters: r.entityId == null ? null : {'id': r.entityId!},
  );

  /// The browser's back and forward buttons arrive here (the engine pushes
  /// the restored entry at the framework); everything else is ours already.
  @override
  Future<bool> didPushRouteInformation(RouteInformation info) async {
    final route = _fromUri(info.uri);
    if (route == null) return false;
    _syncing = true;
    _nav.value = route;
    _syncing = false;
    return true;
  }

  ConsoleRoute? _fromUri(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty);
    if (segments.isEmpty) return null;
    final route = ConsoleRoute(segments.last, entityId: uri.queryParameters['id']);
    return _canOpen(route) ? route : null;
  }

  // ----------------------------------------------------------------- data

  /// Names for the context bar's two selects. They only label filters, so a
  /// failure leaves the selects on "all" -- which is what the console shows
  /// unfiltered anyway. Both endpoints are already scoped server-side.
  ///
  /// ponytail: report.json is the one endpoint that already hands back the
  /// topic list; it also carries every mastery row, which this does not need.
  /// Read the names off Resumen's own overview fetch if that ever costs.
  void _loadLabels() {
    if (widget.me.can('analytics_view')) {
      widget.api.report().then((r) => _keep(() => _topics = r.topics), onError: (_) {});
    }
    if (widget.me.can('personas_view')) {
      widget.api.teams().then((t) => _keep(() => _teams = t), onError: (_) {});
    }
  }

  void _keep(VoidCallback change) {
    if (mounted) setState(change);
  }

  // ---------------------------------------------------------------- routes

  String _label(String section) => switch (section) {
    'person' => L('Person', 'Persona'),
    'team' => L('Team', 'Equipo'),
    _ => _sections.firstWhere((s) => s.id == section, orElse: () => _sections.first).label,
  };

  /// Every route resolves here, and nowhere else.
  Widget _page(ConsoleRoute route) => switch (route.section) {
    // Tasks 11-14 replace these four with AdminOverview, AdminActivity,
    // AdminPerson(userId: route.entityId!) and AdminTeamPage(teamId: …),
    // each taking api, me, filters and nav.
    'overview' => _notYet(_label('overview')),
    'activity' => _notYet(_label('activity')),
    'person' => _notYet(_label('person')),
    'team' => _notYet(_label('team')),
    'mastery' => AdminMastery(api: widget.api, me: widget.me),
    'people' => AdminPeople(api: widget.api, me: widget.me),
    'teams' => AdminTeams(api: widget.api, me: widget.me),
    _ => _notYet(route.section),
  };

  Widget _notYet(String label) => EmptyState(
    eyebrow: label,
    text: L('This screen is not built yet.', 'Esta pantalla todavía no está construida.'),
  );

  /// The shared context bar belongs to the screens that read the shared
  /// filters. Dominio still carries its own v0 controls; Task 15 rebuilds it
  /// on this bar and the set becomes the whole analytics trio.
  static const _withContextBar = {'overview', 'activity'};

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    if (_sections.isEmpty) {
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
      body: ValueListenableBuilder<ConsoleRoute>(
        valueListenable: _nav,
        builder: (context, route, _) {
          // A route the user may not open (a stale link, a revoked
          // permission) shows their first section rather than an error.
          final r = _canOpen(route) ? route : ConsoleRoute(_sections.first.id);
          return AdminScaffold(
            org: widget.me.organization,
            me: widget.me,
            sections: [for (final s in _sections) (s.id, s.label)],
            nav: _nav,
            title: _label(r.section),
            contextBar: _withContextBar.contains(r.section)
                ? ContextBar(filters: _filters, topics: _topics, teams: _teams)
                : null,
            // Task 16 swaps the placeholder for IrisPanel(...); nothing
            // flips the toggle yet, so the console has no end panel today.
            endPanel: _iris ? const SizedBox.shrink() : null,
            onSignOut: widget.onSignOut,
            body: _page(r),
          );
        },
      ),
    );
  }
}
