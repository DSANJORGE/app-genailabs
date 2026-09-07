import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import 'admin_activity.dart';
import 'admin_api.dart';
import 'admin_mastery.dart';
import 'admin_models.dart';
import 'admin_nav.dart';
import 'admin_overview.dart';
import 'admin_people.dart';
import 'admin_person.dart';
import 'admin_team.dart';
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

/// The route a console URL points at, or null when it names none.
///
/// Flutter web's default strategy keeps the route in the fragment
/// (`/admin/#/person?id=u42`); a console served with `usePathUrlStrategy()`
/// keeps it in the path. Read whichever one carries it, so a reload or a
/// pasted link lands where it says. Permission is not this function's
/// business -- [_AdminShellState._canOpen] decides that.
ConsoleRoute? routeFromUri(Uri uri) {
  final inner = uri.hasFragment ? Uri.tryParse(uri.fragment) : null;
  final u = inner ?? uri;
  final segments = u.pathSegments.where((s) => s.isNotEmpty);
  if (segments.isEmpty) return null;
  return ConsoleRoute(segments.last, entityId: u.queryParameters['id']);
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
  // ignore: prefer_final_fields -- Task 16 flips this from the top bar.
  bool _iris = false;

  /// True while a browser back/forward is being applied, so the resulting
  /// route change does not push the entry we are already standing on.
  bool _syncing = false;

  /// The address the browser is already on. [ConsoleNav] deliberately has no
  /// value equality (a citation re-pulses the view it cites), so without this
  /// re-tapping the current section would stack identical history entries and
  /// Back would need several presses to leave the page.
  Uri? _here;

  /// Whether this user's nav carries [id] -- module enabled AND the verb.
  bool _has(String id) => _sections.any((s) => s.id == id);

  bool _canOpen(ConsoleRoute r) => switch (r.section) {
    // Drill pages are analytics: same gate as the analytics sections, plus
    // an entity to be about.
    'person' || 'team' => _has('overview') && (r.entityId ?? '').isNotEmpty,
    _ => _has(r.section),
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
      _here = _uriOf(_nav.value);
      SystemNavigator.routeInformationUpdated(uri: _here!, replace: true);
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
    final uri = _uriOf(_nav.value);
    if (uri == _here) return;
    _here = uri;
    SystemNavigator.routeInformationUpdated(uri: uri);
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
    _here = _uriOf(route);
    return true;
  }

  ConsoleRoute? _fromUri(Uri uri) {
    final route = routeFromUri(uri);
    return route != null && _canOpen(route) ? route : null;
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
    if (_has('overview')) {
      widget.api.report().then((r) => _keep(() => _topics = r.topics), onError: (_) {});
    }
    if (_has('people')) {
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
    'overview' =>
      AdminOverview(api: widget.api, me: widget.me, filters: _filters, nav: _nav),
    'activity' =>
      AdminActivity(api: widget.api, me: widget.me, filters: _filters, nav: _nav),
    // Keyed by the entity: person A -> person B reuses this slot, and without
    // a key the State would keep A's data and never refetch. _canOpen has
    // already refused an empty id.
    'person' => AdminPerson(
        key: ValueKey('person.${route.entityId}'),
        api: widget.api,
        me: widget.me,
        filters: _filters,
        nav: _nav,
        userId: route.entityId!,
      ),
    'team' => AdminTeamPage(
        key: ValueKey('team.${route.entityId}'),
        api: widget.api,
        me: widget.me,
        filters: _filters,
        nav: _nav,
        teamId: route.entityId!,
      ),
    'mastery' =>
      AdminMastery(api: widget.api, me: widget.me, filters: _filters, nav: _nav),
    'people' => AdminPeople(api: widget.api, me: widget.me),
    'teams' => AdminTeams(api: widget.api, me: widget.me),
    _ => _notYet(route.section),
  };

  Widget _notYet(String label) => EmptyState(
    eyebrow: label,
    text: L('This screen is not built yet.', 'Esta pantalla todavía no está construida.'),
  );

  /// The shared context bar belongs to the screens that read the shared
  /// filters -- the whole analytics trio. Dominio ignores the period (mastery
  /// is cumulative) and says so in its own footnote.
  static const _withContextBar = {'overview', 'activity', 'mastery'};

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
