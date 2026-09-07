import 'dart:async';

import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import '../testu/testu_widgets.dart';
import 'admin_api.dart';
import 'admin_csv.dart';
import 'admin_download.dart';
import 'admin_heatmap.dart';
import 'admin_models.dart';
import 'admin_nav.dart';
import 'admin_reading.dart';
import 'admin_theme.dart';
import 'admin_ui.dart';

/// `levelOf` lives with the models now (one rule, shared with the reading
/// rules); it stays importable from here, which is where the console has
/// always asked for it.
export 'admin_models.dart' show levelOf;

/// Dominio (spec analytics-v1 §6.3) — the cohort as one picture: people down
/// the side, subtopics across the top, one tinted cell per person and
/// subtopic. The reader finds the red band before they read a single number,
/// and clicking a name opens that person.
///
/// Mastery is cumulative, so this screen reads the topic and team filters and
/// deliberately ignores the period — said out loud in the footnote rather
/// than left for someone to discover.

String _levelLabel(String? level) => switch (level) {
      'beginner' => L('Beginner', 'Principiante'),
      'competent' => L('Competent', 'Competente'),
      'expert' => L('Expert', 'Experto'),
      _ => L('Not started', 'Sin empezar'),
    };

/// Section titles arrive numbered ("2. Debida diligencia"); a column header
/// has no room for the ordinal and the topic header already gives the order.
String _sectionName(String raw) => raw.replaceFirst(RegExp(r'^\d+\.\s*'), '');

String _date(DateTime? d) => d == null
    ? '—'
    : '${d.toLocal().day.toString().padLeft(2, '0')}-'
        '${d.toLocal().month.toString().padLeft(2, '0')}';

/// Today's report as a CSV — the columns the console has always exported,
/// plus the four calibration counters report.json started sending with them.
/// Pure, so the export is testable without a browser.
String masteryCsv(List<MasteryRow> rows) => csvOf([
      const [
        'user', 'name', 'team', 'topic', 'section', 'questions', 'answered',
        'mastered', 'attempts', 'correct', 'level', 'lastactivity',
        'certaincorrect', 'certainwrong', 'unsurecorrect', 'unsurewrong',
      ],
      for (final r in rows)
        [
          r.user,
          r.name,
          r.team ?? '',
          r.topic,
          r.section,
          '${r.questions}',
          '${r.answered}',
          '${r.mastered}',
          '${r.j['attempts'] ?? ''}',
          '${r.j['correct'] ?? ''}',
          r.level ?? '',
          '${r.j['lastactivity'] ?? ''}',
          '${r.certainCorrect}',
          '${r.certainWrong}',
          '${r.unsureCorrect}',
          '${r.unsureWrong}',
        ],
    ]);

/// Running answered/mastered sum for one user, one user x topic, or one
/// user x subtopic.
class _Tally {
  int answered = 0;
  int mastered = 0;
  int attempts = 0;
  int questions = 0;
  DateTime? last;

  String? get level => levelOf(mastered, answered);
}

class _Person {
  _Person(this.id, this.name, this.team);
  final String id, name;
  final String? team;
}

/// user -> _Person. Last activity is per cell here, not per person: it rides
/// the subtopic tally the tooltip is built from.
Map<String, _Person> _people(List<MasteryRow> rows) {
  final out = <String, _Person>{};
  for (final r in rows) {
    out.putIfAbsent(r.user, () => _Person(r.user, r.name, r.team));
  }
  return out;
}

/// user -> "topic/section" -> tally. One cell of the grid, and the only
/// aggregate that can legitimately hold more than one row (a section split
/// across two rows still has one level).
Map<String, Map<String, _Tally>> _byUserSection(List<MasteryRow> rows) {
  final out = <String, Map<String, _Tally>>{};
  for (final r in rows) {
    _add(out.putIfAbsent(r.user, () => {}).putIfAbsent(_colKey(r), () => _Tally()), r);
  }
  return out;
}

void _add(_Tally t, MasteryRow r) {
  t.answered += r.answered;
  t.mastered += r.mastered;
  t.attempts += (r.j['attempts'] as num?)?.toInt() ?? 0;
  t.questions += r.questions;
  final la = r.lastActivity;
  if (la != null && (t.last == null || la.isAfter(t.last!))) t.last = la;
}

/// Section ids are catalog-wide ordinals ("5"), so the topic has to be part
/// of the column identity or two topics would share a column.
String _colKey(MasteryRow r) => '${r.topicId}/${r.j['componentsection']}';

/// topic id -> display name, preferring the report's topic list and
/// falling back to whatever name a row itself carries.
Map<String, String> _topicNames(AdminReport report) {
  final names = {...report.topics};
  for (final r in report.rows) {
    names.putIfAbsent(r.topicId, () => r.topic);
  }
  return names;
}

/// Grouped by team, or one flat alphabetical list.
enum _Sort { name, team, weakest }

class AdminMastery extends StatefulWidget {
  const AdminMastery({
    super.key,
    required this.api,
    required this.me,
    required this.filters,
    required this.nav,
  });

  final AdminApi api;
  final AdminMe me;
  final AnalyticsFilters filters;
  final ConsoleNav nav;

  @override
  State<AdminMastery> createState() => _AdminMasteryState();
}

class _AdminMasteryState extends State<AdminMastery> {
  AdminReport? _report;

  /// Team id -> name, for the group rows. Labels only: a failure here leaves
  /// the ids showing rather than the screen.
  Map<String, String> _teams = const {};
  Object? _error;
  bool _loading = true;
  bool _byTeam = false;
  _Sort _sort = _Sort.team;
  bool _recomputing = false;

  /// Same debounce-and-stamp as Actividad: a slow answer to an abandoned
  /// filter must never overwrite a fast answer to the current one.
  Timer? _debounce;
  int _request = 0;

  bool get _canOperate => widget.me.can('analytics_operate');

  @override
  void initState() {
    super.initState();
    widget.filters.addListener(_schedule);
    _fetch();
    widget.api.teams().then(
        (t) => _keep(() => _teams = {for (final x in t) x.id: x.name}),
        onError: (_) {});
  }

  @override
  void dispose() {
    widget.filters.removeListener(_schedule);
    _debounce?.cancel();
    super.dispose();
  }

  void _keep(VoidCallback change) {
    if (mounted) setState(change);
  }

  /// What this screen actually reads off the shared filters. The period is
  /// deliberately absent: mastery is cumulative, so a period tap must not
  /// blank the grid to redraw the same numbers.
  String get _key => '${widget.filters.topic}|${widget.filters.team}';
  String? _fetched;

  void _schedule() {
    if (_key == _fetched) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), _reload);
  }

  void _reload() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _fetch();
  }

  /// report.json takes the topic and the team, and nothing else: mastery is a
  /// running total, so the period would be a filter it cannot honour.
  Future<AdminReport> _fetchReport() => widget.api.report(
        topic: widget.filters.topic,
        team: widget.filters.team,
      );

  Future<void> _fetch() async {
    final mine = ++_request;
    _fetched = _key;
    try {
      final r = await _fetchReport();
      if (!mounted || mine != _request) return;
      setState(() {
        _report = r;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || mine != _request) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  /// The newest `computedat` in the report — what moves when the rollup has
  /// actually rerun. ISO-8601 sorts lexically, so a string max is a date max.
  String _stamp(AdminReport? r) {
    var out = '';
    for (final row in r?.rows ?? const <MasteryRow>[]) {
      final at = '${row.j['computedat'] ?? ''}';
      if (at.compareTo(out) > 0) out = at;
    }
    return out;
  }

  /// Recompute is a background job with no completion channel, so the console
  /// watches for its result: poll the report every 5 s, up to six times, and
  /// say plainly when the wait ran out rather than claiming success.
  Future<void> _recompute() async {
    final before = _stamp(_report);
    setState(() => _recomputing = true);
    try {
      await widget.api.recompute();
      for (var i = 0; i < 6; i++) {
        // No timer to cancel: every hop back checks mounted before it touches
        // the tree, which is what dispose during a poll needs.
        await Future<void>.delayed(const Duration(seconds: 5));
        if (!mounted) return;
        final r = await _fetchReport();
        if (!mounted) return;
        if (_stamp(r) != before) {
          setState(() {
            _report = r;
            _error = null;
            _loading = false;
          });
          showToast(context, L('Mastery recomputed.', 'Dominio recalculado.'));
          return;
        }
      }
      if (mounted) {
        showToast(
          context,
          L('Still recomputing. Reload in a minute.',
              'Sigue recalculando. Recarga en un minuto.'),
        );
      }
    } catch (e) {
      if (mounted) showToast(context, errText(e), error: true);
    } finally {
      if (mounted) setState(() => _recomputing = false);
    }
  }

  void _exportCsv() =>
      downloadCsv('dominio.csv', masteryCsv(_report?.rows ?? const []));

  String get _persona {
    final name = widget.me.persona?.name ?? '';
    return name.isEmpty ? 'Iris' : name;
  }

  String _teamLabel(String? id) => (id == null || id.isEmpty)
      ? L('No team', 'Sin equipo')
      : (_teams[id] ?? id);

  @override
  Widget build(BuildContext context) => crossfade(_state(context));

  Widget _state(BuildContext context) {
    if (_error != null) {
      return ConsolePanelError(
        text: L('Mastery could not be loaded.', 'No se pudo cargar el dominio.'),
        onRetry: _reload,
      );
    }
    final report = _report;
    if (_loading || report == null) return const Skeleton(lines: 6, height: 22);
    return _page(context, report);
  }

  Widget _page(BuildContext context, AdminReport report) {
    final grid = _Grid.of(report, _teamLabel, byTeam: _byTeam, sort: _sort);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Reading(
          personaName: _persona,
          avatarUrl: widget.me.persona?.avatar,
          sentences: masteryReading(report),
        ),
        const SizedBox(height: 22),
        _actions(),
        const SizedBox(height: 14),
        if (grid.cols.isEmpty)
          EmptyState(
            eyebrow: L('No mastery yet', 'Todavía sin dominio'),
            text: L(
              'Nobody in this filter has answered a question yet. The grid '
                  'fills in 15 minutes after the first session.',
              'Nadie de este filtro ha respondido todavía. La cuadrícula se '
                  'llena 15 minutos después de la primera sesión.',
            ),
          )
        else
          ChartCard(
            eyebrow: L('People × subtopics', 'Personas × subtemas'),
            height: null,
            trailing: Segmented<bool>(
              value: _byTeam,
              items: [
                (false, L('By person', 'Por persona')),
                (true, L('By team', 'Por equipo')),
              ],
              onChanged: (v) => setState(() => _byTeam = v),
            ),
            footnote: L(
              'Cell = right answers over the questions answered in that '
                  'subtopic (last attempt per question); the count is on '
                  'hover, clicking opens the person. Cumulative mastery, not '
                  'limited to the selected period.',
              'Celda = aciertos sobre las preguntas respondidas del subtema '
                  '(último intento por pregunta); el recuento aparece al pasar '
                  'el ratón y al hacer clic se abre la persona. Dominio '
                  'acumulado, no limitado al periodo seleccionado.',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LevelLegend(),
                const SizedBox(height: 14),
                HeatmapGrid(
                  cols: grid.cols,
                  rows: grid.rows,
                  rowHeader:
                      _byTeam ? L('Team', 'Equipo') : L('Person', 'Persona'),
                  onRow: _open,
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Row ids carry their kind, so one callback serves people and teams
  /// without the grid knowing either exists.
  void _open(String id) => widget.nav.go(
        id.startsWith('u:') ? 'person' : 'team',
        entityId: id.substring(2),
      );

  Widget _actions() => Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Select<_Sort>(
            value: _sort,
            hint: L('Sort', 'Ordenar'),
            items: [
              (_Sort.name, L('Sort: name', 'Orden: nombre')),
              (_Sort.team, L('Sort: team', 'Orden: equipo')),
              (_Sort.weakest, L('Sort: weakest', 'Orden: más débil')),
            ],
            onChanged: (v) => setState(() => _sort = v ?? _Sort.team),
          ),
          TestuAct(
            L('Export CSV', 'Exportar CSV'),
            onTap: (_report?.rows.isEmpty ?? true) ? null : _exportCsv,
          ),
          if (_canOperate)
            TestuAct(
              L('Recompute', 'Recalcular'),
              onTap: _recomputing ? null : _recompute,
            ),
          if (_recomputing)
            Text(L('Recomputing…', 'Recalculando…'),
                style: AdminTokens.muted),
        ],
      );
}

/// The report, shaped into columns and rows. Kept out of the state class so
/// the shaping is one pure step over the parsed report rather than a dozen
/// fields that have to stay in sync.
class _Grid {
  _Grid(this.cols, this.rows);
  final List<HeatCol> cols;
  final List<HeatRow> rows;

  static _Grid of(
    AdminReport report,
    String Function(String?) teamLabel, {
    required bool byTeam,
    required _Sort sort,
  }) {
    final data = report.rows;
    if (data.isEmpty) return _Grid(const [], const []);
    final topicNames = _topicNames(report);

    // Columns: every subtopic present, ordered by topic then by the ordinal
    // the section title still carries.
    final colTopic = <String, String>{};
    final colName = <String, String>{};
    final colOrder = <String, String>{};
    for (final r in data) {
      final key = _colKey(r);
      colTopic[key] = topicNames[r.topicId] ?? r.topic;
      colName[key] = _sectionName(r.section);
      colOrder[key] = '${colTopic[key]} ${r.section}';
    }
    final colKeys = colOrder.keys.toList()
      ..sort((a, b) => colOrder[a]!.compareTo(colOrder[b]!));
    final cols = [for (final k in colKeys) HeatCol(colTopic[k]!, colName[k]!)];

    final people = _people(data);
    final bySection = _byUserSection(data);

    // The summary strip and every group row count PEOPLE per level, never
    // rows: one learner is one Beginner in a subtopic however many rows the
    // server split it across.
    Map<String, int> levelsOf(Iterable<String> users, String col) {
      final out = {'beginner': 0, 'competent': 0, 'expert': 0, 'none': 0};
      for (final u in users) {
        final k = bySection[u]?[col]?.level ?? 'none';
        out[k] = (out[k] ?? 0) + 1;
      }
      return out;
    }

    final byTeamId = <String, List<String>>{};
    for (final p in people.values) {
      byTeamId.putIfAbsent(p.team ?? '', () => []).add(p.id);
    }

    /// Cells a person is at Beginner in — what "weakest" sorts on.
    int weakness(String user) =>
        colKeys.where((c) => bySection[user]?[c]?.level == 'beginner').length;
    int teamWeakness(String id) =>
        byTeamId[id]!.fold(0, (a, u) => a + weakness(u));

    final everyone = people.keys.toList();
    final summary = [for (final c in colKeys) levelsOf(everyone, c)];
    // The weakest column is the one the reading names; the strip underlines
    // it so the sentence and the picture point at the same thing.
    var worst = 0;
    for (var i = 0; i < summary.length; i++) {
      if ((summary[i]['beginner'] ?? 0) > (summary[worst]['beginner'] ?? 0)) {
        worst = i;
      }
    }
    final anyBeginner = summary.any((m) => (m['beginner'] ?? 0) > 0);

    HeatCell groupCell(String title, Map<String, int> levels,
            {bool mark = false}) =>
        HeatCell(
          title: title,
          levels: levels,
          highlight: mark,
          detail: [
            for (final k in const ['beginner', 'competent', 'expert'])
              if ((levels[k] ?? 0) > 0) '${levels[k]} ${_levelLabel(k)}',
          ].join(' · '),
        );

    HeatRow personRow(_Person p) => HeatRow(
          id: 'u:${p.id}',
          label: p.name,
          cells: [
            for (final c in colKeys)
              if (bySection[p.id]?[c] case final t?)
                HeatCell(
                  title: '${p.name} · ${colName[c]}',
                  level: t.level,
                  levelLabel: _levelLabel(t.level),
                  mastered: t.mastered,
                  answered: t.answered,
                  questions: t.questions,
                  detail: L(
                    '${t.mastered} of ${t.answered} questions mastered · '
                        '${t.attempts} attempts · last activity ${_date(t.last)}',
                    '${t.mastered} de ${t.answered} preguntas dominadas · '
                        '${t.attempts} intentos · última actividad ${_date(t.last)}',
                  ),
                )
              else
                null,
          ],
        );

    HeatRow teamRow(String id) {
      final members = byTeamId[id]!;
      final name = teamLabel(id.isEmpty ? null : id);
      final n = members.length;
      return HeatRow(
        id: 'g:$id',
        label: '$name · $n '
            '${n == 1 ? L('person', 'persona') : L('people', 'personas')}',
        group: true,
        cells: [
          for (final c in colKeys)
            groupCell('$name · ${colName[c]}', levelsOf(members, c)),
        ],
      );
    }

    int byTeamName(String a, String b) => teamLabel(a.isEmpty ? null : a)
        .compareTo(teamLabel(b.isEmpty ? null : b));
    int byName(String a, String b) => people[a]!.name.compareTo(people[b]!.name);
    int byWeakness(String a, String b) {
      final d = weakness(b).compareTo(weakness(a));
      return d != 0 ? d : byName(a, b);
    }

    final rows = <HeatRow>[
      HeatRow(
        id: '',
        label: L('People by level', 'Personas por nivel'),
        group: true,
        cells: [
          for (var i = 0; i < colKeys.length; i++)
            groupCell(
              '${colTopic[colKeys[i]]} · ${colName[colKeys[i]]}',
              summary[i],
              mark: anyBeginner && i == worst,
            ),
        ],
      ),
    ];

    final teamIds = byTeamId.keys.toList()
      ..sort(sort == _Sort.weakest
          ? (a, b) => teamWeakness(b).compareTo(teamWeakness(a))
          : byTeamName);

    if (byTeam) {
      rows.addAll(teamIds.map(teamRow));
      return _Grid(cols, rows);
    }

    // Sorting by name is the one view that drops the team rows: a flat A→Z
    // list is what someone looking for a person wants, and team rows in the
    // middle of it would only be in the way.
    if (sort == _Sort.name) {
      everyone.sort(byName);
      rows.addAll([for (final u in everyone) personRow(people[u]!)]);
      return _Grid(cols, rows);
    }

    for (final id in teamIds) {
      rows.add(teamRow(id));
      final members = byTeamId[id]!
        ..sort(sort == _Sort.weakest ? byWeakness : byName);
      rows.addAll([for (final u in members) personRow(people[u]!)]);
    }
    return _Grid(cols, rows);
  }
}
