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

/// Actividad (spec analytics-v1 §6.2 and §6.8) — the screen a training lead
/// opens to answer "is the organisation actually using this, and what is it
/// asking about".
///
/// It reads top to bottom in one order and never varies: what the numbers
/// mean, how far the cohort got (adoption), how much they did (daily
/// series), when they did it (hours), what they asked the tutor, and finally
/// who has stopped. The context bar belongs to the shell; this screen only
/// listens to the filters it publishes.
class AdminActivity extends StatefulWidget {
  const AdminActivity({
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
  State<AdminActivity> createState() => _AdminActivityState();
}

/// The four counters the daily card can draw. `minutes` and `sessions` are
/// zero until the 1.1.1 app ships its instrumentation (spec §7), which is
/// what the card's footnote says rather than pretending the org was idle.
enum _Series { people, answers, minutes, sessions }

class _AdminActivityState extends State<AdminActivity>
    with FilteredFetch<Activity, AdminActivity> {
  @override
  AnalyticsFilters get filters => widget.filters;

  @override
  ConsoleNav get nav => widget.nav;

  @override
  Future<Activity> fetch() => widget.api.activity(widget.filters.query);

  @override
  String errorText(Object e) =>
      L('Activity could not be loaded.', 'No se pudo cargar la actividad.');

  @override
  Widget build(BuildContext context) => fetched(_page);

  String get _persona {
    final name = widget.me.persona?.name ?? '';
    return name.isEmpty ? 'Iris' : name;
  }

  Widget _page(BuildContext context, Activity a, String? highlight) {
    // `funnel` is the screen's own cohort: activityReading reads the same
    // five numbers, so both come from one place.
    final answered = a.funnel['answered'] ?? 0;
    final cohort = Cohort(
      a.funnel['cohort'] ?? 0,
      answered,
      a.funnel['active7d'] ?? 0,
      a.funnel['active30d'] ?? 0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Reading(
          personaName: _persona,
          avatarUrl: widget.me.persona?.avatar,
          sentences: activityReading(a, cohort),
        ),
        const SizedBox(height: 22),
        // Adoption reads even at zero -- it is the one card that explains an
        // empty screen, so it never hides behind the empty state.
        Pulse(active: points(highlight, 'funnel'), child: _adoption(a)),
        const SizedBox(height: 16),
        if (answered == 0)
          EmptyState(
            eyebrow: L('No activity yet', 'Todavía sin actividad'),
            text: L(
              'The charts appear as soon as someone answers their first '
                  'question. The list below is who to nudge until then.',
              'Los gráficos aparecen en cuanto alguien responde su primera '
                  'pregunta. La lista de abajo es a quién avisar mientras tanto.',
            ),
          )
        else ...[
          _DailyCard(a.series),
          const SizedBox(height: 16),
          _hours(a),
          const SizedBox(height: 16),
          Pulse(active: points(highlight, 'iris'), child: _irisPair(context, a)),
          const SizedBox(height: 16),
          Pulse(active: points(highlight, 'iris'), child: _themes(context, a)),
        ],
        const SizedBox(height: 16),
        Pulse(active: points(highlight, 'inactive'), child: _inactive(a)),
      ],
    );
  }

  // -------------------------------------------------------------- adoption

  Widget _adoption(Activity a) => ChartCard(
        eyebrow: L('Adoption', 'Adopción'),
        height: null,
        footnote: L(
          'Signed in = the account has been opened at least once. Every share '
              'is read against the cohort.',
          'Han entrado = la cuenta se ha abierto al menos una vez. Cada '
              'porcentaje se lee sobre la cohorte.',
        ),
        child: Funnel([
          (L('Cohort', 'Cohorte'), a.funnel['cohort'] ?? 0),
          (L('Signed in', 'Han entrado'), a.funnel['signedin'] ?? 0),
          (L('Answered', 'Han respondido'), a.funnel['answered'] ?? 0),
          (L('Active 7 d', 'Activos 7 d'), a.funnel['active7d'] ?? 0),
          (L('Active 30 d', 'Activos 30 d'), a.funnel['active30d'] ?? 0),
        ]),
      );

  // ------------------------------------------------------------------ hours

  /// The heatmap is a fixed 418 px grid, so the card lets its child size
  /// itself and pins it to the left rather than stretching a 14 px cell.
  Widget _hours(Activity a) => ChartCard(
        eyebrow: L('When they learn', 'Cuándo aprenden'),
        height: null,
        footnote: L(
          'Answers by weekday and hour. The count is in every cell.',
          'Respuestas por día de la semana y hora. El recuento está en cada celda.',
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: hoursHeatmap(a.hours),
        ),
      );

  // ------------------------------------------------------------- Iris usage

  /// The two Iris cards sit side by side on a laptop and stack below it —
  /// the same floor Resumen uses, because a subtopic name plus its bar stops
  /// being readable under ~450 px.
  Widget _irisPair(BuildContext context, Activity a) => LayoutBuilder(
        builder: (context, box) {
          final usage = _irisUsage(a);
          final asked = _asked(a);
          if (box.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [usage, const SizedBox(height: 16), asked],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: usage),
                const SizedBox(width: 16),
                Expanded(child: asked),
              ],
            ),
          );
        },
      );

  /// A share the server could not compute is "—", never 0 %.
  String _share(double? value) => value == null ? '—' : pct(value);

  Widget _irisUsage(Activity a) {
    final cited = a.iris.citedShare;
    return ChartCard(
      eyebrow: L('$_persona usage', 'Uso de $_persona'),
      height: null,
      footnote: cited == null
          ? null
          : L('${pct(cited)} of replies pointed at the source they came from.',
              '${pct(cited)} de las respuestas señalaron la fuente de la que salen.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 150,
            child: dailyBars(a.series, value: (d) => d.questions),
          ),
          const SizedBox(height: 14),
          StatRow([
            StatBlock(
              label: L('Rated', 'Valoradas'),
              value: _share(a.iris.ratedShare),
            ),
            StatBlock(
              label: L('Helpful', 'Útiles'),
              value: _share(a.iris.helpfulShare),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _asked(Activity a) {
    final sections = [...a.iris.sections]
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
              BarRow(
                label: s.name,
                value: s.questions,
                max: top,
                tooltip: _askedTip(s),
              ),
        ],
      ),
    );
  }

  /// What will not fit on the bar: the count spelled out and the helpfulness,
  /// which the server leaves null until somebody rates a reply.
  String _askedTip(SectionQ s) {
    final helpful = s.helpfulShare;
    return '${s.name} · ${s.questions} ${L('questions', 'preguntas')} · '
        '${helpful == null ? L('not rated yet', 'todavía sin valorar') : L('${pct(helpful)} helpful', '${pct(helpful)} útiles')}';
  }

  // ----------------------------------------------------------------- themes

  Widget _themes(BuildContext context, Activity a) {
    final counts = _themeCounts(a.iris.themes);
    final segments = [
      for (var i = 0; i < _themeKeys.length; i++)
        (_themePalette[i], _themeLabel(_themeKeys[i]), counts[i]),
    ];
    final labels = a.iris.labels;
    return ChartCard(
      eyebrow: L('Question themes', 'Temas de las preguntas'),
      height: null,
      footnote: L('Aggregated: no individual question is ever shown.',
          'Agregado: nunca se muestra ninguna pregunta individual.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StackedBar(segments),
          const SizedBox(height: 12),
          Legend([
            for (final (color, label, count) in segments)
              if (count > 0) (color, '$label · $count'),
          ]),
          // The label cloud is withheld by the server until enough people
          // have asked (§6.8): an empty list is the privacy gate doing its
          // job, not a failure to report.
          if (labels.isNotEmpty) ...[
            const SizedBox(height: 18),
            _chips(context, labels),
          ],
        ],
      ),
    );
  }

  /// The seven theme buckets in one fixed order. `unclassified` is not a
  /// theme the reader can act on — it folds into "Other" rather than
  /// becoming an eighth colour.
  static const _themeKeys = [
    'concept',
    'procedure',
    'example',
    'source',
    'challenge',
    'offtopic',
    'other',
  ];

  /// Seven qualitative colours, never the level trio: these are categories,
  /// not levels, and reusing red/amber/green here would read as bad/ok/good.
  static final List<Color> _themePalette = [
    TestuTokens.instance.orange,
    TestuTokens.instance.blue,
    TestuTokens.instance.green,
    TestuTokens.instance.amber,
    TestuTokens.instance.violet,
    TestuTokens.instance.gold,
    TestuTokens.instance.mut,
  ];

  /// Anything the palette does not name — `unclassified`, and any theme a
  /// later server adds — lands in "Other" rather than disappearing from a
  /// bar whose whole job is to add up to the total.
  List<int> _themeCounts(Map<String, int> themes) {
    final named = _themeKeys.toSet();
    var other = 0;
    for (final e in themes.entries) {
      if (!named.contains(e.key) || e.key == 'other') other += e.value;
    }
    return [
      for (final k in _themeKeys) k == 'other' ? other : (themes[k] ?? 0),
    ];
  }

  static String _themeLabel(String key) => switch (key) {
        'concept' => L('Clarify a concept', 'Aclarar un concepto'),
        'procedure' => L('How it is done', 'Cómo se hace'),
        'example' => L('Ask for an example', 'Pedir un ejemplo'),
        'source' => L('Where in the source', 'Dónde está en la fuente'),
        'challenge' => L('Discuss the answer', 'Discutir la respuesta'),
        'offtopic' => L('Off topic', 'Fuera del tema'),
        _ => L('Other', 'Otro'),
      };

  /// The LLM's topic labels, sized 11-15 px by how many questions share
  /// them. Size is a comparison, so the count also rides in the tooltip.
  Widget _chips(BuildContext context, List<(String, int)> labels) {
    final t = TestuTokens.of(context);
    var min = labels.first.$2;
    var max = labels.first.$2;
    for (final (_, count) in labels) {
      if (count < min) min = count;
      if (count > max) max = count;
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, count) in labels)
          Tooltip(
            message: '$label · $count',
            waitDuration: Duration.zero,
            textStyle: AdminTokens.mono(11),
            decoration: BoxDecoration(
              color: t.card2,
              border: Border.all(color: t.line),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: t.line2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: max == min ? 13 : 11 + 4 * (count - min) / (max - min),
                  color: t.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --------------------------------------------------------------- inactive

  Widget _inactive(Activity a) {
    // One clock for the whole table, so two rows can never disagree about
    // what "today" is. `inactive` is wall-clock (7 days), not the period.
    final today = DateTime.now();
    // Never started sorts as the longest absence there is, without pretending
    // to be a number of days.
    int days(InactivePerson p) => p.lastActivity == null
        ? 1 << 30
        : today.difference(p.lastActivity!).inDays;

    return ChartCard(
      eyebrow: L('No activity', 'Sin actividad'),
      height: null,
      footnote: L(
        'Everyone in scope with no answer in the last 7 days, whatever period '
            'is selected above.',
        'Todas las personas de tu alcance sin ninguna respuesta en los últimos '
            '7 días, sea cual sea el periodo seleccionado arriba.',
      ),
      child: AdminTable<InactivePerson>(
        rows: a.inactive,
        initialSort: 3,
        emptyText: L('Everyone has been active this week.',
            'Todo el mundo ha estado activo esta semana.'),
        onTap: (p) => widget.nav.go('person', entityId: p.user),
        columns: [
          AdminColumn(
            L('Name', 'Nombre'),
            (p) => Text(p.name, overflow: TextOverflow.ellipsis),
            sortKey: (p) => p.name,
            flex: 3,
          ),
          AdminColumn(
            L('Team', 'Equipo'),
            (p) => Text(p.team ?? '—',
                style: AdminTokens.muted, overflow: TextOverflow.ellipsis),
            sortKey: (p) => p.team ?? '',
            flex: 2,
          ),
          AdminColumn(
            L('Last activity', 'Última actividad'),
            (p) => Text(
              p.lastActivity == null ? '—' : _date(p.lastActivity!),
              style: AdminTokens.mono(11.5),
            ),
            sortKey: days,
            width: 130,
            numeric: true,
          ),
          AdminColumn(
            L('Days', 'Días'),
            (p) => Text(
              p.lastActivity == null ? L('Never', 'Nunca') : '${days(p)}',
              style: AdminTokens.mono(12.5),
            ),
            sortKey: days,
            width: 90,
            numeric: true,
          ),
        ],
      ),
    );
  }
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// The daily series and its toggle, on its own state: switching counter
/// redraws one chart, not the heatmap's 168 cells and the tables below it.
/// The choice survives a filter change, which is what a reader comparing two
/// periods on the same counter expects.
class _DailyCard extends StatefulWidget {
  const _DailyCard(this.series);

  final List<DayPoint> series;

  @override
  State<_DailyCard> createState() => _DailyCardState();
}

class _DailyCardState extends State<_DailyCard> {
  _Series _toggle = _Series.people;

  int _value(DayPoint d) => switch (_toggle) {
        _Series.people => d.people,
        _Series.answers => d.answers,
        _Series.minutes => d.minutes,
        _Series.sessions => d.sessions,
      };

  @override
  Widget build(BuildContext context) {
    // A flat zero on a counter the app does not send yet is not "nobody used
    // it": say which version starts sending it instead.
    final silent = (_toggle == _Series.minutes || _toggle == _Series.sessions) &&
        widget.series.every((d) => _value(d) == 0);
    return ChartCard(
      eyebrow: L('Daily activity', 'Actividad diaria'),
      trailing: Segmented<_Series>(
        value: _toggle,
        items: [
          (_Series.people, L('People', 'Personas')),
          (_Series.answers, L('Answers', 'Respuestas')),
          (_Series.minutes, L('Minutes', 'Minutos')),
          (_Series.sessions, L('Sessions', 'Sesiones')),
        ],
        onChanged: (v) => setState(() => _toggle = v),
      ),
      footnote: silent
          ? L('Available from app version 1.1.1.',
              'Disponible desde la versión 1.1.1 de la app.')
          : switch (_toggle) {
              _Series.people => L(
                  'Active people = at least one answer that day.',
                  'Personas activas = al menos una respuesta ese día.'),
              _Series.answers => L('One bar per day of the selected period.',
                  'Una barra por día del periodo seleccionado.'),
              _Series.minutes => L('Time with the app open, measured on the device.',
                  'Tiempo con la app abierta, medido en el dispositivo.'),
              _Series.sessions => L(
                  'A session ends after 30 minutes without activity.',
                  'Una sesión termina tras 30 minutos sin actividad.'),
            },
      child: dailyBars(widget.series, value: _value),
    );
  }
}
