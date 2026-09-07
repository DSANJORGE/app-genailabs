import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import 'admin_api.dart';
import 'admin_charts.dart';
import 'admin_models.dart';
import 'admin_nav.dart';
import 'admin_reading.dart';
import 'admin_screen.dart';
import 'admin_theme.dart';
import 'admin_ui.dart';

/// Everything the Equipo screen draws, fetched in one shot. The team's own
/// numbers come from a scoped overview; the organisation's come from the
/// unscoped one, which is the only place the median lives. The roster is the
/// personas endpoints joined with the team's mastery rows — a member with no
/// rows is still a member, and has to appear as one.
typedef _TeamData = ({
  Overview team,
  Overview org,
  List<AdminUser> users,
  AdminReport report,
  List<AdminTeam> teams,
});

/// One row of the members table: the person, how their subtopics are spread
/// across the four levels, and the two yes/no facts a lead scans for.
class _Member {
  _Member({
    required this.user,
    required this.levels,
    required this.started,
    required this.weakest,
    required this.lastActivity,
  });

  final AdminUser user;

  /// Subtopics per level, for [LevelBar]. This row IS one person, so the bar
  /// spreads their subtopics — the cohort rule (levels counted per person)
  /// is what the Resumen and Equipos tables draw instead.
  final Map<String, int> levels;
  final bool started;
  final String? weakest;
  final DateTime? lastActivity;
}

/// Equipo (spec analytics-v1 §6.5) — one team against the organisation it
/// sits in: is it keeping up, what is it weakest at, and who inside it needs
/// a nudge. Every row drills into that person.
class AdminTeamPage extends StatefulWidget {
  const AdminTeamPage({
    super.key,
    required this.api,
    required this.me,
    required this.filters,
    required this.nav,
    required this.teamId,
  });

  final AdminApi api;
  final AdminMe me;
  final AnalyticsFilters filters;
  final ConsoleNav nav;
  final String teamId;

  @override
  State<AdminTeamPage> createState() => _AdminTeamPageState();
}

class _AdminTeamPageState extends State<AdminTeamPage>
    with FilteredFetch<_TeamData, AdminTeamPage> {
  @override
  AnalyticsFilters get filters => widget.filters;

  @override
  ConsoleNav get nav => widget.nav;

  /// Five reads, all in flight at once: waiting for them in sequence would
  /// make this the slowest screen in the console for no reason.
  /// `Future.wait` is what keeps a failure from leaving four unhandled
  /// errors behind it.
  @override
  Future<_TeamData> fetch() async {
    final q = {...widget.filters.query, 'team': widget.teamId};
    // The median is an organisation figure: the same window, no team.
    final org = {...widget.filters.query}..remove('team');
    final r = await Future.wait<Object>([
      widget.api.overview(q),
      widget.api.overview(org),
      widget.api.users(),
      widget.api.report(team: widget.teamId),
      widget.api.teams(),
    ]);
    return (
      team: r[0] as Overview,
      org: r[1] as Overview,
      users: r[2] as List<AdminUser>,
      report: r[3] as AdminReport,
      teams: r[4] as List<AdminTeam>,
    );
  }

  @override
  String errorText(Object e) =>
      L('This team could not be loaded.', 'No se pudo cargar este equipo.');

  @override
  Widget build(BuildContext context) => fetched(_page);

  String get _persona {
    final name = widget.me.persona?.name ?? '';
    return name.isEmpty ? 'Iris' : name;
  }

  /// The team's own row in `overview.teams[]`. A scoped overview sends one
  /// team; a server that ever sends the whole list still resolves here, and
  /// a team with no analytics at all falls back to what personas knows.
  TeamStat _stat(_TeamData d, AdminTeam? team) {
    for (final o in [d.team, d.org]) {
      for (final t in o.teams) {
        if (t.id == widget.teamId) return t;
      }
    }
    return TeamStat(widget.teamId, team?.name ?? widget.teamId,
        team?.members ?? 0, 0, 0, const Levels(), null);
  }

  Widget _page(BuildContext context, _TeamData d, String? highlight) {
    final team = _team(d);
    final stat = _stat(d, team);
    final members = _members(d);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(d, team, stat),
        const SizedBox(height: 20),
        Reading(
          personaName: _persona,
          avatarUrl: widget.me.persona?.avatar,
          sentences: teamReading(stat, d.org),
        ),
        const SizedBox(height: 22),
        Pulse(active: points(highlight, 'stat'), child: _stats(d, stat)),
        const SizedBox(height: 22),
        _activity(d),
        const SizedBox(height: 16),
        Pulse(active: points(highlight, 'iris'), child: _asked(d)),
        const SizedBox(height: 16),
        Pulse(
            active: points(highlight, 'member'),
            child: _roster(members, d.report.rows.isEmpty)),
      ],
    );
  }

  AdminTeam? _team(_TeamData d) {
    for (final t in d.teams) {
      if (t.id == widget.teamId) return t;
    }
    return null;
  }

  // ---------------------------------------------------------------- header

  Widget _header(_TeamData d, AdminTeam? team, TeamStat stat) {
    final manager = team?.manager;
    final parent = team?.parent;
    final meta = [
      if (manager != null && manager.isNotEmpty)
        L('Manager ${_userName(d, manager)}',
            'Responsable ${_userName(d, manager)}'),
      if (parent != null && parent.isNotEmpty)
        L('Part of ${_teamNameOf(d, parent)}', 'Dentro de ${_teamNameOf(d, parent)}'),
      L('${stat.members} ${stat.members == 1 ? 'person' : 'people'}',
          '${stat.members} ${stat.members == 1 ? 'persona' : 'personas'}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(teamName(stat),
            style: AdminTokens.title, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 7),
        Text(meta.join(' · '), style: AdminTokens.muted),
      ],
    );
  }

  /// `manager` and `parent` are ids; a console that printed the id would be
  /// asking the reader to know the database.
  String _userName(_TeamData d, String id) {
    for (final u in d.users) {
      if (u.id == id) return u.name;
    }
    return id;
  }

  String _teamNameOf(_TeamData d, String id) {
    for (final t in d.teams) {
      if (t.id == id) return t.name;
    }
    return id;
  }

  // ----------------------------------------------------------------- stats

  Widget _stats(_TeamData d, TeamStat stat) {
    final series = d.team.series;
    int sum(int Function(DayPoint) of) => series.fold(0, (a, b) => a + of(b));
    List<num> spark(int Function(DayPoint) of) => [
          for (final p in series.length > 7
              ? series.sublist(series.length - 7)
              : series)
            of(p),
        ];

    final median = d.org.median?.activeShare;
    return StatRow([
      StatBlock(
        label: L('Active 7 d', 'Activos 7 d'),
        value: grouped(stat.active7d),
        highlight: true,
        // The comparison a team is actually read against: not last week, the
        // rest of the organisation. Withheld under 5 learners, and then this
        // block simply says nothing.
        delta: median == null
            ? null
            : L('organisation median ${pct(median)}',
                'mediana de la organización ${pct(median)}'),
        spark: spark((p) => p.people),
      ),
      StatBlock(
        label: L('Answers', 'Respuestas'),
        value: grouped(sum((p) => p.answers)),
        spark: spark((p) => p.answers),
      ),
      StatBlock(
        label: L('Minutes', 'Minutos'),
        value: grouped(sum((p) => p.minutes)),
        spark: spark((p) => p.minutes),
      ),
      StatBlock(
        label: L('Questions to $_persona', 'Preguntas a $_persona'),
        value: grouped(d.team.iris.questions),
        spark: spark((p) => p.questions),
      ),
    ]);
  }

  // -------------------------------------------------------------- activity

  Widget _activity(_TeamData d) => ChartCard(
        eyebrow: L('Activity', 'Actividad'),
        legend: [
          (AdminTokens.focus, L('Active people', 'Personas activas')),
          (TestuTokens.of(context).mut, L('Answers', 'Respuestas')),
        ],
        footnote: L('Active people = at least one answer that day.',
            'Personas activas = al menos una respuesta ese día.'),
        child: activityChart(
          series: d.team.series,
          previous: null,
          peopleLabel: L('active people', 'personas activas'),
          answersLabel: L('answers', 'respuestas'),
        ),
      );

  Widget _asked(_TeamData d) {
    final sections = [...d.team.iris.sections]
      ..sort((x, y) => y.questions.compareTo(x.questions));
    final top = sections.isEmpty ? 0 : sections.first.questions;
    return ChartCard(
      eyebrow: L('What they ask about', 'Sobre qué preguntan'),
      height: null,
      footnote: L('Subtopic of the question, not its words.',
          'Subtema de la pregunta, nunca sus palabras.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (sections.isEmpty)
            Text(L('No questions yet.', 'Todavía no hay preguntas.'),
                style: AdminTokens.muted)
          else
            for (final s in sections)
              BarRow(label: s.name, value: s.questions, max: top),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- members

  /// The roster: everyone personas puts in this team, joined with whatever
  /// mastery rows they have. One clock for the whole table, so two rows can
  /// never disagree about what "this week" is.
  List<_Member> _members(_TeamData d) {
    final byUser = <String, List<MasteryRow>>{};
    for (final r in d.report.rows) {
      (byUser[r.user] ??= []).add(r);
    }
    return [
      for (final u in d.users)
        if (u.team == widget.teamId) _member(u, byUser[u.id] ?? const []),
    ];
  }

  _Member _member(AdminUser u, List<MasteryRow> rows) {
    // A subtopic can arrive as more than one row; its level is the sum, the
    // same aggregate Dominio draws a cell from.
    final bySection = <String, List<int>>{};
    final byTopic = <String, List<int>>{};
    final topicName = <String, String>{};
    var last = u.lastActivity;
    for (final r in rows) {
      topicName[r.topicId] = r.topic;
      for (final (map, key) in [(bySection, r.sectionKey), (byTopic, r.topicId)]) {
        final t = map.putIfAbsent(key, () => [0, 0]);
        t[0] += r.mastered;
        t[1] += r.answered;
      }
      final at = r.lastActivity;
      if (at != null && (last == null || at.isAfter(last))) last = at;
    }

    final levels = {'beginner': 0, 'competent': 0, 'expert': 0, 'none': 0};
    for (final t in bySection.values) {
      final level = levelOf(t[0], t[1]);
      levels[level ?? 'none'] = (levels[level ?? 'none'] ?? 0) + 1;
    }

    String? weakest;
    var worst = 2.0;
    for (final e in byTopic.entries) {
      if (e.value[1] == 0) continue;
      final share = e.value[0] / e.value[1];
      if (share < worst) {
        worst = share;
        weakest = topicName[e.key];
      }
    }

    return _Member(
      user: u,
      levels: levels,
      started: bySection.values.any((t) => t[1] > 0),
      weakest: weakest,
      lastActivity: last,
    );
  }

  Widget _roster(List<_Member> members, bool noRows) {
    final now = DateTime.now();
    bool active(_Member m) =>
        m.lastActivity != null && now.difference(m.lastActivity!).inDays < 7;
    final t = TestuTokens.of(context);
    Widget yesNo(bool value) => Text(
          value ? L('Yes', 'Sí') : L('No', 'No'),
          style: value ? AdminTokens.table : AdminTokens.muted,
        );

    return ChartCard(
      eyebrow: L('Members', 'Integrantes'),
      height: null,
      footnote: noRows
          ? L('Nobody in this team has answered anything yet.',
              'Todavía nadie de este equipo ha respondido nada.')
          : L(
              'The bar spreads that person’s subtopics across the four '
                  'levels. Cumulative, not just the selected period.',
              'La barra reparte los subtemas de esa persona entre los cuatro '
                  'niveles. Acumulado, no solo del periodo seleccionado.',
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LevelLegend(),
          const SizedBox(height: 12),
          AdminTable<_Member>(
            rows: members,
            emptyText: L('Nobody is in this team yet.',
                'Todavía no hay nadie en este equipo.'),
            onTap: (m) => widget.nav.go('person', entityId: m.user.id),
            columns: [
              AdminColumn(
                L('Name', 'Nombre'),
                (m) => Text(m.user.name, overflow: TextOverflow.ellipsis),
                sortKey: (m) => m.user.name,
                flex: 3,
              ),
              AdminColumn(
                L('Started', 'Han empezado'),
                (m) => yesNo(m.started),
                sortKey: (m) => m.started ? 0 : 1,
                width: 110,
              ),
              AdminColumn(
                L('Active 7 d', 'Activos 7 d'),
                (m) => yesNo(active(m)),
                sortKey: (m) => active(m) ? 0 : 1,
                width: 100,
              ),
              AdminColumn(
                L('Levels', 'Niveles'),
                (m) => LevelBar(m.levels),
                width: 180,
              ),
              AdminColumn(
                L('Weakest topic', 'Tema más débil'),
                (m) => Text(m.weakest ?? '—',
                    style: m.weakest == null
                        ? AdminTokens.muted
                        : TextStyle(
                            fontFamily: 'Geist', fontSize: 12.5, color: t.ink),
                    overflow: TextOverflow.ellipsis),
                sortKey: (m) => m.weakest ?? '',
                flex: 2,
              ),
              AdminColumn(
                L('Last activity', 'Última actividad'),
                (m) => Text(
                  m.lastActivity == null ? '—' : _date(m.lastActivity!),
                  style: AdminTokens.mono(11.5),
                ),
                sortKey: (m) => m.lastActivity?.millisecondsSinceEpoch ?? 0,
                width: 120,
                numeric: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}
