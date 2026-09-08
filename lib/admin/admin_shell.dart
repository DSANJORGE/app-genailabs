import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show LogicalKeyboardKey, SystemNavigator;

import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import '../testu/testu_widgets.dart';
import 'admin_activity.dart';
import 'admin_api.dart';
import 'admin_iris.dart';
import 'admin_mastery.dart';
import 'admin_models.dart';
import 'admin_nav.dart';
import 'admin_overview.dart';
import 'admin_people.dart';
import 'admin_person.dart';
import 'admin_reading.dart';
import 'admin_team.dart';
import 'admin_theme.dart';
import 'admin_teams.dart';
import 'admin_threads.dart';
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
    // Conversaciones rides the personas module: it is the roster's scope
    // (scope.groovy) that decides which comments a manager sees.
    if (personas && me.can('personas_view')) AdminSection('threads', L('Conversations', 'Conversaciones')),
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

  /// The Iris panel toggle, and the thread behind it. Both live here so one
  /// conversation follows the user across screens and survives closing the
  /// panel: the panel state is session-scoped (spec §6.7), and a new sign-in
  /// builds a new shell, which is what starts it clean.
  bool _iris = false;
  final _thread = IrisThread();

  /// Where Iris has anything to say: the analytics screens and their two
  /// drill-downs. The roster screens are administration, not analysis.
  static const _withIris = {'overview', 'activity', 'mastery', 'person', 'team'};

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
    _thread.dispose();
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
    'people' => AdminPeople(api: widget.api, me: widget.me, nav: _nav),
    'teams' => AdminTeams(api: widget.api, me: widget.me, nav: _nav),
    'threads' => AdminThreads(api: widget.api, me: widget.me),
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
              ConsoleAct(L('Sign out', 'Cerrar sesión'), onTap: widget.onSignOut),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: t.bg,
      // Cmd-/ on a Mac, Ctrl-/ everywhere else: the panel is a companion to
      // whatever is on screen, so it opens without leaving the keyboard.
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.slash, meta: true):
              _toggleIris,
          const SingleActivator(LogicalKeyboardKey.slash, control: true):
              _toggleIris,
        },
        // autofocus is what gives CallbackShortcuts a focus scope to live
        // in; nothing else on the console asks for initial focus.
        child: Focus(
          autofocus: true,
          child: ValueListenableBuilder<ConsoleRoute>(
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
                    ? ContextBar(
                        filters: _filters,
                        topics: _topics,
                        teams: _teams,
                        // Mastery is cumulative and says so in its own
                        // footnote; the period control would be a lever
                        // wired to nothing.
                        period: r.section != 'mastery',
                      )
                    : null,
                titleAction:
                    _withIris.contains(r.section) ? _irisToggle(t) : null,
                endPanel: _iris && _withIris.contains(r.section)
                    ? IrisPanel(
                        api: widget.api,
                        nav: _nav,
                        filters: _filters,
                        persona: widget.me.persona,
                        screen: r.section,
                        selectedUser: r.section == 'person' ? r.entityId : null,
                        thread: _thread,
                        onClose: () => setState(() => _iris = false),
                      )
                    : null,
                onSignOut: widget.onSignOut,
                body: _page(r),
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggleIris() => setState(() => _iris = !_iris);

  /// The persona's own face, at the right of the title row: the tutor is
  /// present on every screen (law 4), and this is where she is on a laptop.
  Widget _irisToggle(TestuTokens t) {
    final name = personaName(widget.me);
    final avatar = widget.me.persona?.avatar;
    return TestuPressable(
      onTap: _toggleIris,
      child: Semantics(
        button: true,
        toggled: _iris,
        label: L('Ask $name', 'Pregunta a $name'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
          decoration: BoxDecoration(
            border: Border.all(color: _iris ? AdminTokens.focus : t.line2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonaAvatar(url: avatar),
              const SizedBox(width: 8),
              Text(name, style: kLabel),
            ],
          ),
        ),
      ),
    );
  }
}
