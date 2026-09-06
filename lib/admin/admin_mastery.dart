import 'package:eme_app_package/eme_http.dart' show EmeHttpException;
import 'package:flutter/material.dart';
import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import '../testu/testu_widgets.dart';
import 'admin_api.dart';
import 'admin_csv.dart';
import 'admin_download.dart';
import 'admin_models.dart';

/// Aggregate level for a user (or a user x topic) from summed
/// answered/mastered, on the same thresholds as testu_topics.dart's
/// masteryOf: under half right = beginner, under 90% = competent, no
/// answers = not started (null).
String? levelOf(int mastered, int answered) {
  if (answered == 0) return null;
  final share = mastered / answered;
  if (share >= 0.9) return 'expert';
  if (share >= 0.5) return 'competent';
  return 'beginner';
}

String _levelLabel(String? level) => switch (level) {
      'beginner' => L('Beginner', 'Principiante'),
      'competent' => L('Competent', 'Competente'),
      'expert' => L('Expert', 'Experto'),
      _ => L('Not started', 'Sin empezar'),
    };

Color _levelColor(String? level, TestuTokens t) => switch (level) {
      'expert' => t.green,
      'competent' => t.amber,
      'beginner' => t.red,
      _ => t.faint,
    };

String _fmtDate(DateTime? d) {
  if (d == null) return '—';
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

/// Running answered/mastered sum for one user, or one user x topic.
class _Tally {
  int answered = 0;
  int mastered = 0;
}

class _Person {
  _Person(this.id, this.name, this.team);
  final String id, name;
  final String? team;
  DateTime? lastActivity;
}

/// user -> _Person, with lastActivity the max across all their rows.
Map<String, _Person> _people(List<MasteryRow> rows) {
  final out = <String, _Person>{};
  for (final r in rows) {
    final p = out.putIfAbsent(r.user, () => _Person(r.user, r.name, r.team));
    final la = r.lastActivity;
    if (la != null && (p.lastActivity == null || la.isAfter(p.lastActivity!))) {
      p.lastActivity = la;
    }
  }
  return out;
}

/// user -> topicId -> tally, summing a user's sections within one topic.
Map<String, Map<String, _Tally>> _byUserTopic(List<MasteryRow> rows) {
  final out = <String, Map<String, _Tally>>{};
  for (final r in rows) {
    final byTopic = out.putIfAbsent(r.user, () => {});
    final tly = byTopic.putIfAbsent(r.topicId, () => _Tally());
    tly.answered += r.answered;
    tly.mastered += r.mastered;
  }
  return out;
}

/// user -> tally across every topic/section (the "per person" aggregate the
/// team tab's level breakdown is built from).
Map<String, _Tally> _byUser(List<MasteryRow> rows) {
  final out = <String, _Tally>{};
  for (final r in rows) {
    final tly = out.putIfAbsent(r.user, () => _Tally());
    tly.answered += r.answered;
    tly.mastered += r.mastered;
  }
  return out;
}

/// topic id -> display name, preferring the report's topic list and
/// falling back to whatever name a row itself carries.
Map<String, String> _topicNames(AdminReport report) {
  final names = {...report.topics};
  for (final r in report.rows) {
    names.putIfAbsent(r.topicId, () => r.topic);
  }
  return names;
}

/// Dominio: topic/team-filtered mastery report, by person and by team, with
/// CSV export and (analytics_operate only) recompute. Mirrors admin_teams's
/// load/mounted pattern.
class AdminMastery extends StatefulWidget {
  const AdminMastery({super.key, required this.api, required this.me});
  final AdminApi api;
  final AdminMe me;

  @override
  State<AdminMastery> createState() => _AdminMasteryState();
}

class _AdminMasteryState extends State<AdminMastery> {
  AdminReport? _report;
  List<AdminTeam>? _teams;
  Object? _error;
  String? _topic;
  String? _team;
  bool _recomputing = false;

  bool get _canOperate => widget.me.can('analytics_operate');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final report = widget.api.report(topic: _topic, team: _team);
    final teams = widget.api.teams();
    try {
      final r = await report;
      final tm = await teams;
      if (!mounted) return;
      setState(() {
        _report = r;
        _teams = tm;
        _error = null;
      });
    } on EmeHttpException {
      rethrow;
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  void _setTopic(String? v) {
    setState(() => _topic = v);
    _load();
  }

  void _setTeam(String? v) {
    setState(() => _team = v);
    _load();
  }

  Future<void> _recompute() async {
    setState(() => _recomputing = true);
    try {
      await widget.api.recompute();
      await Future.delayed(const Duration(seconds: 5));
      await _load();
    } on EmeHttpException {
      rethrow;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errText(e))));
    } finally {
      if (mounted) setState(() => _recomputing = false);
    }
  }

  void _exportCsv() {
    final rows = _report!.rows;
    final table = [
      const [
        'user', 'name', 'team', 'topic', 'section', 'questions', 'answered',
        'mastered', 'attempts', 'correct', 'level', 'lastactivity',
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
        ],
    ];
    downloadCsv('dominio.csv', csvOf(table));
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(L('Could not load the report.', 'No se pudo cargar el informe.'), style: TextStyle(color: t.mut)),
          const SizedBox(height: 12),
          TextButton(onPressed: _load, child: Text(L('Retry', 'Reintentar'))),
        ]),
      );
    }
    if (_report == null || _teams == null) {
      return Center(child: CircularProgressIndicator(color: t.mut));
    }
    final report = _report!;
    final teams = _teams!;
    final summary = report.summary;
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: report.topics.containsKey(_topic) ? _topic : null,
                  hint: Text(L('All topics', 'Todos los temas')),
                  items: [
                    DropdownMenuItem(value: null, child: Text(L('All topics', 'Todos los temas'))),
                    for (final e in report.topics.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: _setTopic,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: teams.any((tm) => tm.id == _team) ? _team : null,
                  hint: Text(L('All teams', 'Todos los equipos')),
                  items: [
                    DropdownMenuItem(value: null, child: Text(L('All teams', 'Todos los equipos'))),
                    for (final tm in teams) DropdownMenuItem(value: tm.id, child: Text(tm.name)),
                  ],
                  onChanged: _setTeam,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: TestuButton(L('Export CSV', 'Exportar CSV'), onTap: report.rows.isEmpty ? null : _exportCsv),
              ),
              if (_canOperate) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: TestuButton(L('Recompute', 'Recalcular'), onTap: _recomputing ? null : _recompute),
                ),
              ],
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _Stat(L('ACTIVE 7D', 'ACTIVOS 7D'), '${summary.activeUsers7d}'),
              const SizedBox(width: 32),
              _Stat(L('ANSWERS 7D', 'RESPUESTAS 7D'), '${summary.answers7d}'),
              const SizedBox(width: 32),
              Expanded(
                child: _Stat(
                  L('LEVELS', 'NIVELES'),
                  '${_levelLabel('beginner')} ${summary.levels['beginner'] ?? 0}  ·  '
                  '${_levelLabel('competent')} ${summary.levels['competent'] ?? 0}  ·  '
                  '${_levelLabel('expert')} ${summary.levels['expert'] ?? 0}',
                ),
              ),
            ]),
            const SizedBox(height: 16),
            if (report.rows.isEmpty)
              Expanded(
                child: Center(
                  child: Text(L('No answers yet.', 'Aún no hay respuestas.'), style: TextStyle(color: t.mut)),
                ),
              )
            else ...[
              TabBar(
                isScrollable: true,
                labelColor: t.ink,
                unselectedLabelColor: t.mut,
                tabs: [Tab(text: L('By person', 'Por persona')), Tab(text: L('By team', 'Por equipo'))],
              ),
              Expanded(
                child: TabBarView(children: [
                  _personTab(report, t),
                  _teamTab(report, teams, t),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _personTab(AdminReport report, TestuTokens t) {
    final rows = report.rows;
    final topicNames = _topicNames(report);
    final presentTopics = {for (final r in rows) r.topicId};
    final topicIds = presentTopics.toList()
      ..sort((a, b) => (topicNames[a] ?? a).compareTo(topicNames[b] ?? b));
    final people = _people(rows);
    final byUserTopic = _byUserTopic(rows);
    final rowsByUser = <String, List<MasteryRow>>{};
    for (final r in rows) {
      rowsByUser.putIfAbsent(r.user, () => []).add(r);
    }
    final userIds = people.keys.toList()..sort((a, b) => people[a]!.name.compareTo(people[b]!.name));

    Widget headerCell(String text, {int flex = 1}) => Expanded(
          flex: flex,
          child: Text(text, style: TextStyle(color: t.faint, fontSize: 10.5, fontWeight: FontWeight.w600)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            headerCell(L('Name', 'Nombre'), flex: 2),
            for (final id in topicIds) headerCell(topicNames[id] ?? id),
            SizedBox(
              width: 110,
              child: Text(L('Last activity', 'Última actividad'),
                  style: TextStyle(color: t.faint, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ),
            // ponytail: rough alignment with ExpansionTile's built-in chevron below.
            const SizedBox(width: 40),
          ]),
        ),
        Divider(color: t.line, height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: userIds.length,
            itemBuilder: (context, i) {
              final uid = userIds[i];
              final person = people[uid]!;
              final topics = byUserTopic[uid] ?? const {};
              return ExpansionTile(
                title: Row(children: [
                  Expanded(flex: 2, child: Text(person.name, style: TextStyle(color: t.ink))),
                  for (final id in topicIds) Expanded(child: _levelCell(topics[id], t)),
                  SizedBox(
                    width: 110,
                    child: Text(_fmtDate(person.lastActivity), style: TextStyle(color: t.mut, fontSize: 11)),
                  ),
                ]),
                children: [
                  for (final r in rowsByUser[uid]!)
                    ListTile(
                      dense: true,
                      title: Text('${topicNames[r.topicId] ?? r.topic} · ${r.section}', style: TextStyle(color: t.ink, fontSize: 12.5)),
                      trailing: Text(
                        '${r.mastered}/${r.answered}/${r.questions}  ·  ${_levelLabel(levelOf(r.mastered, r.answered))}',
                        style: TextStyle(color: t.mut, fontSize: 11.5),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _levelCell(_Tally? tally, TestuTokens t) {
    final answered = tally?.answered ?? 0;
    final mastered = tally?.mastered ?? 0;
    final level = levelOf(mastered, answered);
    return Text('$mastered/$answered', style: TextStyle(color: _levelColor(level, t), fontSize: 12));
  }

  Widget _teamTab(AdminReport report, List<AdminTeam> teams, TestuTokens t) {
    final rows = report.rows;
    final people = _people(rows);
    final byUser = _byUser(rows);
    final teamNames = {for (final tm in teams) tm.id: tm.name};
    String teamLabel(String key) => key.isEmpty ? L('No team', 'Sin equipo') : (teamNames[key] ?? key);

    final byTeam = <String, List<String>>{};
    for (final uid in people.keys) {
      byTeam.putIfAbsent(people[uid]!.team ?? '', () => []).add(uid);
    }
    final teamKeys = byTeam.keys.toList()..sort((a, b) => teamLabel(a).compareTo(teamLabel(b)));
    final now = DateTime.now();

    DataRow rowFor(String key) {
      final members = byTeam[key]!;
      final active7d = members.where((uid) {
        final la = people[uid]!.lastActivity;
        return la != null && now.difference(la) <= const Duration(days: 7);
      }).length;
      var beginner = 0, competent = 0, expert = 0;
      for (final uid in members) {
        final tly = byUser[uid];
        switch (levelOf(tly?.mastered ?? 0, tly?.answered ?? 0)) {
          case 'beginner':
            beginner++;
          case 'competent':
            competent++;
          case 'expert':
            expert++;
        }
      }
      return DataRow(cells: [
        DataCell(Text(teamLabel(key))),
        DataCell(Text('${members.length}')),
        DataCell(Text('$active7d')),
        DataCell(Text('$beginner')),
        DataCell(Text('$competent')),
        DataCell(Text('$expert')),
      ]);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: [
            DataColumn(label: Text(L('Team', 'Equipo'))),
            DataColumn(label: Text(L('Members with activity', 'Miembros con actividad'))),
            DataColumn(label: Text(L('Active 7d', 'Activos 7d'))),
            DataColumn(label: Text(_levelLabel('beginner'))),
            DataColumn(label: Text(_levelLabel('competent'))),
            DataColumn(label: Text(_levelLabel('expert'))),
          ],
          rows: [for (final key in teamKeys) rowFor(key)],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TestuEyebrow(label),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
