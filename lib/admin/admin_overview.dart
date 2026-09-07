import 'dart:async';

import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import 'admin_api.dart';
import 'admin_charts.dart';
import 'admin_models.dart';
import 'admin_nav.dart';
import 'admin_reading.dart';
import 'admin_theme.dart';
import 'admin_ui.dart';

/// Resumen (spec analytics-v1 §6.1) — the screen a training lead opens to
/// answer "who needs help this week" in under a minute.
///
/// It reads top to bottom in one order and never varies: what the numbers
/// mean (the tutor's [Reading]), the five numbers themselves, the shape of
/// the period, then where the weakness is — by topic, by confidence, by
/// subtopic, by team. The context bar belongs to the shell; this screen only
/// listens to the filters it publishes.
class AdminOverview extends StatefulWidget {
  const AdminOverview({
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
  State<AdminOverview> createState() => _AdminOverviewState();
}

class _AdminOverviewState extends State<AdminOverview> {
  Overview? _data;
  Object? _error;
  bool _loading = true;

  /// Every filter gesture is debounced, and every reply is stamped: a slow
  /// answer to an abandoned filter must never overwrite a fast answer to the
  /// current one.
  Timer? _debounce;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    widget.filters.addListener(_schedule);
    _fetch();
  }

  @override
  void dispose() {
    widget.filters.removeListener(_schedule);
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule() {
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

  Future<void> _fetch() async {
    final mine = ++_request;
    try {
      final data = await widget.api.overview(widget.filters.query);
      if (!mounted || mine != _request) return;
      setState(() {
        _data = data;
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

  @override
  Widget build(BuildContext context) => crossfade(_state(context));

  Widget _state(BuildContext context) {
    if (_error != null) {
      return ConsolePanelError(
        text: L('The overview could not be loaded.', 'No se pudo cargar el resumen.'),
        onRetry: _reload,
      );
    }
    final data = _data;
    if (_loading || data == null) return const Skeleton(lines: 6, height: 22);
    // The highlight is a per-citation thing (Task 16), so only the page body
    // rebuilds on it -- not the fetch, not the filters.
    return ValueListenableBuilder<ConsoleRoute>(
      valueListenable: widget.nav,
      builder: (context, route, _) => _page(context, data, route.highlight),
    );
  }

  /// True when an Iris citation is pointing at [what]. Citation ids name the
  /// element they quote ("teams.pisco", "gap.phishing"), so a prefix match is
  /// what connects one to a panel.
  bool _points(String? highlight, String what) =>
      highlight != null && highlight.toLowerCase().contains(what);

  Widget _page(BuildContext context, Overview o, String? highlight) {
    // Nobody has answered: the reading says when data appears and the stat
    // row still renders its zeros, so the shape of the screen is learnable
    // before there is anything in it.
    final empty = o.cohort.activated == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Reading(
          personaName: _persona,
          avatarUrl: widget.me.persona?.avatar,
          sentences: overviewReading(o),
        ),
        const SizedBox(height: 22),
        Pulse(active: highlight != null, child: _stats(o)),
        const SizedBox(height: 22),
        if (empty)
          EmptyState(
            eyebrow: L('No activity yet', 'Todavía sin actividad'),
            text: L(
              'The charts and tables appear as soon as someone answers their '
                  'first question.',
              'Los gráficos y las tablas aparecen en cuanto alguien responde '
                  'su primera pregunta.',
            ),
          )
        else ...[
          _activity(context, o),
          const SizedBox(height: 16),
          _pair(context, o),
          const SizedBox(height: 16),
          Pulse(active: _points(highlight, 'gap'), child: _gaps(o)),
          const SizedBox(height: 16),
          Pulse(active: _points(highlight, 'team'), child: _teams(o)),
        ],
      ],
    );
  }

  String get _persona {
    final name = widget.me.persona?.name ?? '';
    return name.isEmpty ? 'Iris' : name;
  }

  // ----------------------------------------------------------------- stats

  Widget _stats(Overview o) {
    final series = o.series;
    int sum(int Function(DayPoint) of) =>
        series.fold(0, (a, d) => a + of(d));
    List<num> spark(int Function(DayPoint) of) => [
          for (final d in series.length > 7
              ? series.sublist(series.length - 7)
              : series)
            of(d),
        ];

    final answers = sum((d) => d.answers);
    final minutes = sum((d) => d.minutes);
    final wrong = sum((d) => d.certainwrong);
    final active = o.cohort.active7d;
    final previous = o.previous;

    return StatRow([
      StatBlock(
        label: L('Active 7 d', 'Activos 7 d'),
        value: _grouped(active),
        delta: _delta(active, previous['active7d'], week: true),
        deltaPositive: _better(active, previous['active7d']),
        spark: spark((d) => d.people),
      ),
      StatBlock(
        label: L('Answers', 'Respuestas'),
        value: _grouped(answers),
        delta: _delta(answers, previous['answers']),
        deltaPositive: _better(answers, previous['answers']),
        spark: spark((d) => d.answers),
      ),
      StatBlock(
        label: L('Minutes in the app', 'Minutos en la app'),
        value: _grouped(minutes),
        // Minutes have no good direction -- more is not better -- so this
        // one carries the per-person reading instead of a delta.
        delta: L(
          '≈ ${active == 0 ? 0 : (minutes / active).round()} min per active person',
          '≈ ${active == 0 ? 0 : (minutes / active).round()} min por persona activa',
        ),
        spark: spark((d) => d.minutes),
      ),
      StatBlock(
        label: L('Misconceptions', 'Conceptos erróneos'),
        value: _grouped(wrong),
        delta: _delta(wrong, previous['certainwrong']),
        // The one stat where up is bad: the colour follows the meaning, not
        // the sign.
        deltaPositive: _better(wrong, previous['certainwrong'], moreIsBetter: false),
        spark: spark((d) => d.certainwrong),
      ),
      StatBlock(
        label: L('Questions to Iris', 'Preguntas a Iris'),
        value: _grouped(o.iris.questions),
        delta: _delta(o.iris.questions, previous['questions']),
        deltaPositive: _better(o.iris.questions, previous['questions']),
        spark: spark((d) => d.questions),
      ),
    ]);
  }

  /// No `previous` key means the server computed no comparison — say nothing
  /// rather than compare against an assumed zero.
  String? _delta(int now, int? before, {bool week = false}) =>
      before == null ? null : deltaLine(now - before, week: week);

  bool? _better(int now, int? before, {bool moreIsBetter = true}) {
    if (before == null || now == before) return null;
    return (now > before) == moreIsBetter;
  }

  // ---------------------------------------------------------------- panels

  Widget _activity(BuildContext context, Overview o) {
    final t = TestuTokens.of(context);
    return ChartCard(
      eyebrow: L('Daily activity', 'Actividad diaria'),
      legend: [
        (AdminTokens.focus, L('Active people', 'Personas activas')),
        (t.mut, L('Answers', 'Respuestas')),
      ],
      footnote: L('Active people = at least one answer that day.',
          'Personas activas = al menos una respuesta ese día.'),
      // ponytail: no previous-period ghost line. overview.json sends the
      // previous window as sums, not as a series, so there is nothing to
      // draw -- the stat-row deltas carry that comparison instead.
      child: activityChart(
        series: o.series,
        peopleLabel: L('active people', 'personas activas'),
        answersLabel: L('answers', 'respuestas'),
      ),
    );
  }

  /// Mastery and calibration sit side by side on a laptop and stack below
  /// it: two cards squeezed under ~450 px each stop being readable, and the
  /// console's floor is 900 px of window, not of content.
  Widget _pair(BuildContext context, Overview o) => LayoutBuilder(
        builder: (context, box) {
          final mastery = _topics(o);
          final calibration = _calibration(o);
          if (box.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [mastery, const SizedBox(height: 16), calibration],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: mastery),
                const SizedBox(width: 16),
                Expanded(child: calibration),
              ],
            ),
          );
        },
      );

  Widget _topics(Overview o) => ChartCard(
        eyebrow: L('Mastery by topic · people', 'Dominio por tema · personas'),
        height: null,
        footnote: L(
          'Level per person: right answers over answered in the topic. Under '
              'half = Beginner, under 90% = Competent. Cumulative, not just '
              'the selected period.',
          'Nivel por persona: aciertos sobre respondidas en el tema. Menos de '
              'la mitad = Principiante, menos del 90 % = Competente. '
              'Acumulado, no solo del periodo seleccionado.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LevelLegend(),
            const SizedBox(height: 12),
            if (o.topics.isEmpty)
              Text(L('No topics yet.', 'Todavía no hay temas.'),
                  style: AdminTokens.muted)
            else
              for (final t in o.topics) _TopicRow(t),
          ],
        ),
      );

  Widget _calibration(Overview o) {
    final share = o.calibration.calibrated;
    return ChartCard(
      eyebrow: L('Confidence calibration', 'Calibración de confianza') +
          (share == null ? '' : ' · ${pct(share)}'),
      height: null,
      footnote: L(
        'Calibration = answers where confidence matched the result. '
            'Cumulative, not just the selected period.',
        'Calibración = respuestas donde la confianza coincidió con el '
            'resultado. Acumulado, no solo del periodo seleccionado.',
      ),
      // The model already carries the server's own keys: `iu` is
      // incorrect-while-certain, the misconception cell.
      child: Quad(
        cc: o.calibration.cc,
        cu: o.calibration.cu,
        ic: o.calibration.ic,
        iu: o.calibration.iu,
      ),
    );
  }

  Widget _gaps(Overview o) => ChartCard(
        eyebrow: L('Knowledge gaps', 'Brechas de conocimiento'),
        height: null,
        footnote: L('The five subtopics with the weakest signal.',
            'Los cinco subtemas con la señal más débil.'),
        child: AdminTable<Gap>(
          rows: o.gaps,
          emptyText: L('No gap stands out yet.',
              'Todavía no destaca ninguna brecha.'),
          onTap: (g) {
            // Dominio, already filtered to the topic the gap lives in --
            // one gesture from "this is the problem" to "here is who has it".
            widget.filters.set(topic: g.topicId);
            widget.nav.go('mastery');
          },
          columns: [
            AdminColumn(
              L('Subtopic', 'Subtema'),
              (g) => _TwoLine(g.name, g.topic),
              sortKey: (g) => g.name,
              flex: 3,
            ),
            AdminColumn(
              L('What the numbers say', 'Lo que dicen los números'),
              (g) => Text(_gapLine(g),
                  style: AdminTokens.muted, overflow: TextOverflow.ellipsis),
              flex: 4,
            ),
            AdminColumn(
              L('Levels', 'Niveles'),
              (g) => LevelBar(_bars(g.levels)),
              width: 160,
            ),
          ],
        ),
      );

  Widget _teams(Overview o) => ChartCard(
        eyebrow: L('Teams', 'Equipos'),
        height: null,
        footnote: L(
          'Levels are cumulative; the activity columns follow the selected period.',
          'Los niveles son acumulados; las columnas de actividad siguen el '
              'periodo seleccionado.',
        ),
        child: AdminTable<TeamStat>(
          rows: o.teams,
          emptyText: L('No teams yet.', 'Todavía no hay equipos.'),
          onTap: (t) {
            // The id-less bucket is "learners without a team": a real row
            // with real numbers, but there is no team page to open for it.
            if (t.id.isEmpty) return;
            widget.nav.go('team', entityId: t.id);
          },
          columns: [
            AdminColumn(
              L('Team', 'Equipo'),
              (t) => Text(teamName(t), overflow: TextOverflow.ellipsis),
              sortKey: (t) => teamName(t),
              flex: 2,
            ),
            AdminColumn(
              L('People', 'Personas'),
              (t) => Text('${t.members}', style: AdminTokens.mono(12.5)),
              sortKey: (t) => t.members,
              width: 80,
              numeric: true,
            ),
            AdminColumn(
              L('Started', 'Han empezado'),
              (t) => Text(pct(t.members == 0 ? 0 : t.activated / t.members),
                  style: AdminTokens.mono(12.5)),
              sortKey: (t) => t.members == 0 ? 0 : t.activated / t.members,
              width: 120,
              numeric: true,
            ),
            AdminColumn(
              L('Active 7 d', 'Activos 7 d'),
              (t) => Text('${t.active7d}', style: AdminTokens.mono(12.5)),
              sortKey: (t) => t.active7d,
              width: 110,
              numeric: true,
            ),
            AdminColumn(
              L('Levels', 'Niveles'),
              (t) => LevelBar(_bars(t.levels)),
              width: 220,
            ),
            AdminColumn(
              L('Weakest topic', 'Tema más débil'),
              (t) => Text(t.weakest ?? '—',
                  style: AdminTokens.muted, overflow: TextOverflow.ellipsis),
              flex: 2,
            ),
          ],
        ),
      );
}

/// A topic's line in the mastery card: who it is, how the cohort sits inside
/// it, and the one subtopic dragging it down.
class _TopicRow extends StatelessWidget {
  const _TopicRow(this.topic);

  final TopicStat topic;

  @override
  Widget build(BuildContext context) {
    final weakest = topic.weakest;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(topic.name,
                style: AdminTokens.table, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Expanded(flex: 3, child: LevelBar(_bars(topic.levels))),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              weakest == null
                  ? '—'
                  : L('↓ ${weakest.name} · ${weakest.beginners} beg.',
                      '↓ ${weakest.name} · ${weakest.beginners} princ.'),
              style: kLabel,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// A table cell that carries its own context on a second, muted line.
class _TwoLine extends StatelessWidget {
  const _TwoLine(this.top, this.bottom);

  final String top, bottom;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(top, overflow: TextOverflow.ellipsis),
          Text(bottom, style: AdminTokens.muted, overflow: TextOverflow.ellipsis),
        ],
      );
}

/// [Levels] calls the empty bucket `notstarted`; [LevelBar] paints it as
/// `none`. Rename here rather than teach either side the other's word.
Map<String, int> _bars(Levels l) => {
      'beginner': l.beginner,
      'competent': l.competent,
      'expert': l.expert,
      'none': l.notstarted,
    };

/// A gap read out loud: the three counters that make it a gap, in the order
/// a training lead acts on them.
String _gapLine(Gap g) => L(
      '${g.beginners} at Beginner, ${g.questions} questions to Iris, '
          '${g.misconceptions} misconceptions',
      '${g.beginners} en Principiante, ${g.questions} preguntas a Iris, '
          '${g.misconceptions} conceptos erróneos',
    );

/// 1284 -> "1 284". Four figures and up read as groups on a dashboard; an
/// unbroken run of digits does not.
String _grouped(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer(value < 0 ? '−' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return out.toString();
}
