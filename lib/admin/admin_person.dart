import 'package:eme_app_package/eme_http.dart' show EmeHttpException;
import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import '../testu/testu_widgets.dart';
import 'admin_api.dart';
import 'admin_charts.dart';
import 'admin_models.dart';
import 'admin_nav.dart';
import 'admin_reading.dart';
import 'admin_screen.dart';
import 'admin_theme.dart';
import 'admin_ui.dart';

/// Persona (spec analytics-v1 §6.4) — one learner, read the way the app
/// reads them back to themselves: the same mastery pills, the same
/// calibration quadrant, the same correct/incorrect week bars. A training
/// lead lands here from a heatmap row, an inactive list or a team table, and
/// has to recognise what the learner sees on their own phone.
///
/// The reply is scoped server-side: person.json answers 403 for someone
/// outside the viewer's teams, and that is the one error this screen words
/// itself.
/// The reply plus the team names it needs to read one id back as a place.
typedef _PersonData = ({PersonReport person, List<AdminTeam> teams});

class AdminPerson extends StatefulWidget {
  const AdminPerson({
    super.key,
    required this.api,
    required this.me,
    required this.filters,
    required this.nav,
    required this.userId,
  });

  final AdminApi api;
  final AdminMe me;
  final AnalyticsFilters filters;
  final ConsoleNav nav;
  final String userId;

  @override
  State<AdminPerson> createState() => _AdminPersonState();
}

class _AdminPersonState extends State<AdminPerson>
    with FilteredFetch<_PersonData, AdminPerson> {
  @override
  AnalyticsFilters get filters => widget.filters;

  @override
  ConsoleNav get nav => widget.nav;

  /// A fixed 30-day window, not the shared period: the card below says
  /// "Últimos 30 días" and the usage and Iris lines are summed off the same
  /// reply, so the page would be lying if the console's period control could
  /// silently make it 7. `person.json` scopes itself to the learner, so no
  /// other filter belongs in this query.
  Map<String, String> get _window {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    return {
      'from': ymd(DateTime(to.year, to.month, to.day - 30)),
      'to': ymd(to),
      'period': 'd30',
    };
  }

  @override
  Future<_PersonData> fetch() async {
    // `user.team` is an id; only teams.json knows the name. That endpoint
    // needs personas_view and answers 403 without it -- and THAT 403 does
    // end the session, so a viewer who lacks the verb must never call it.
    final teams = widget.me.can('personas_view')
        ? widget.api.teams().catchError((_) => <AdminTeam>[])
        : Future.value(<AdminTeam>[]);
    final r = await Future.wait<Object>(
        [widget.api.person(widget.userId, _window), teams]);
    return (person: r[0] as PersonReport, teams: r[1] as List<AdminTeam>);
  }

  /// A manager reading someone outside their teams gets a 403 from
  /// person.groovy. That is not a breakage, it is the scope rule, and it is
  /// the only error on this screen worth its own sentence.
  @override
  String errorText(Object e) => e is EmeHttpException && e.statusCode == 403
      ? L('Outside your scope.', 'Fuera de tu alcance.')
      : loadError(e);

  @override
  bool canRetry(Object e) => !(e is EmeHttpException && e.statusCode == 403);

  @override
  Widget build(BuildContext context) => fetched(_page);

  String get _tutor => personaName(widget.me);

  Widget _page(BuildContext context, _PersonData d, ConsoleRoute route) {
    final p = d.person;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          pulse(route, {'stat', 'inactive'}, child: _header(d)),
          const SizedBox(height: 20),
          Reading(
            personaName: _tutor,
            avatarUrl: widget.me.persona?.avatar,
            sentences: personReading(p),
          ),
          const SizedBox(height: 22),
          pulse(route, {'topic'}, child: _pair(context, p)),
          const SizedBox(height: 16),
          _week(p),
          const SizedBox(height: 16),
          pulse(route, {'iris'}, child: _usage(p)),
          const SizedBox(height: 16),
          _table(p),
        ],
      );
  }

  // ---------------------------------------------------------------- header

  Widget _header(_PersonData d) {
    final p = d.person;
    final u = p.user;
    final t = TestuTokens.of(context);
    final meta = [
      if ((u.team ?? '').isNotEmpty) _teamName(d, u.team!),
      if (_lastSeen(p) != null)
        L('Last activity ${_lastSeen(p)}', 'Última actividad ${_lastSeen(p)}'),
      if (u.creationdate != null)
        L('In the app since ${u.creationdate}',
            'En la app desde ${u.creationdate}'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(u.name,
                  style: AdminTokens.title, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 12),
            TestuPill(roleLabel(u.role), color: t.mut, borderColor: t.line2),
          ],
        ),
        if (meta.isNotEmpty) ...[
          const SizedBox(height: 7),
          Text(meta.join(' · '), style: AdminTokens.muted),
        ],
      ],
    );
  }

  /// The id is the honest fallback: a team the roster does not carry (or a
  /// viewer who may not read the roster) still names something real.
  String _teamName(_PersonData d, String id) {
    for (final t in d.teams) {
      if (t.id == id) return t.name;
    }
    return id;
  }

  /// The freshest thing the reply knows about. person.json's `user` carries
  /// no `lastactivity`, so the mastery rows are what answer it; [
  /// AdminUser.lastlogin] is eMe's RAW string (not ISO-8601) and is printed
  /// verbatim as the last resort.
  String? _lastSeen(PersonReport p) {
    var at = p.user.lastActivity;
    for (final r in p.rows) {
      final d = r.lastActivity;
      if (d != null && (at == null || d.isAfter(at))) at = d;
    }
    return at == null ? p.user.lastlogin : date(at);
  }

  // ------------------------------------------------------- mastery + quad

  /// The two cards sit side by side on a laptop and stack below it — the same
  /// floor Resumen uses, because a topic name plus its pill stops being
  /// readable under ~450 px.
  Widget _pair(BuildContext context, PersonReport p) => LayoutBuilder(
        builder: (context, box) {
          final topics = _topics(p);
          final quad = _calibration(p);
          if (box.maxWidth < 900) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [topics, const SizedBox(height: 16), quad],
            );
          }
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: topics),
                const SizedBox(width: 16),
                Expanded(child: quad),
              ],
            ),
          );
        },
      );

  Widget _topics(PersonReport p) => ChartCard(
        eyebrow: L('Mastery by topic', 'Dominio por tema'),
        height: null,
        footnote: L(
          'Right answers over answered in the topic — the same level the '
              'learner sees in the app. Cumulative, not just the selected period.',
          'Aciertos sobre respondidas en el tema: el mismo nivel que la '
              'persona ve en la app. Acumulado, no solo del periodo seleccionado.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (p.topics.isEmpty)
              Text(L('No topics yet.', 'Todavía no hay temas.'),
                  style: AdminTokens.muted)
            else
              for (final t in p.topics) _TopicRow(t),
          ],
        ),
      );

  Widget _calibration(PersonReport p) {
    final share = p.calibration.calibrated;
    return ChartCard(
      eyebrow: L('Calibration', 'Calibración') +
          (share == null ? '' : ' · ${pct(share)}'),
      height: null,
      footnote: L(
        'Calibration = answers where confidence matched the result. '
            'Cumulative, not just the selected period.',
        'Calibración = respuestas donde la confianza coincidió con el '
            'resultado. Acumulado, no solo del periodo seleccionado.',
      ),
      child: Quad(
        cc: p.calibration.cc,
        cu: p.calibration.cu,
        ic: p.calibration.ic,
        iu: p.calibration.iu,
      ),
    );
  }

  // ------------------------------------------------------------ the period

  Widget _week(PersonReport p) {
    final days = [
      for (final d in p.series)
        (
          label: dm(d.day),
          correct: d.correct,
          // The server sends the day's total and how many were right; a
          // reply that ever disagrees must not draw a negative bar.
          incorrect: d.answers - d.correct < 0 ? 0 : d.answers - d.correct,
        ),
    ];
    final correct = days.fold<int>(0, (a, d) => a + d.correct);
    final incorrect = days.fold<int>(0, (a, d) => a + d.incorrect);
    final silent = correct + incorrect == 0;
    return ChartCard(
      eyebrow: L('Last 30 days', 'Últimos 30 días'),
      height: silent ? null : 220,
      legend: silent
          ? const []
          : [
              (AdminTokens.seriesPositive, L('Correct', 'Correctas')),
              (AdminTokens.seriesNegative, L('Incorrect', 'Incorrectas')),
            ],
      // The bars are a comparison; the totals are the reading, so they exist
      // as text rather than only inside a hover tooltip.
      footnote: silent
          ? L('The last 30 days, whatever period the rest of the console is on.',
              'Los últimos 30 días, sea cual sea el periodo del resto de la consola.')
          : L(
              '$correct correct · $incorrect incorrect in 30 days, whatever '
                  'period the rest of the console is on.',
              '$correct correctas · $incorrect incorrectas en 30 días, sea cual '
                  'sea el periodo del resto de la consola.',
            ),
      child: silent
          ? Text(L('Nothing answered yet.', 'Todavía sin respuestas.'),
              style: AdminTokens.muted)
          : correctIncorrectBars(days),
    );
  }

  // ------------------------------------------------------------ usage line

  Widget _usage(PersonReport p) {
    final iris = _irisLine(p);
    return ChartCard(
      eyebrow: L('Usage', 'Uso'),
      height: null,
      // Same reply as the chart above, so the same 30 days. Worded without a
      // count: the Iris line is absent when nobody asked anything.
      footnote:
          L('Usage over the last 30 days.', 'Uso de los últimos 30 días.'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L('${p.sessions} sessions · ${p.minutes} min · ${p.activeDays} active days',
                '${p.sessions} sesiones · ${p.minutes} min · ${p.activeDays} días activos'),
            style: AdminTokens.body,
          ),
          if (iris != null) ...[
            const SizedBox(height: 6),
            Text(iris, style: AdminTokens.body),
          ],
        ],
      ),
    );
  }

  /// What this learner asked the tutor, as one sentence. Every clause is
  /// dropped when the server has nothing for it: a person who never asked
  /// gets no line at all, rather than a row of zeros.
  String? _irisLine(PersonReport p) {
    if (p.irisQuestions == 0) return null;
    final sections = [
      for (final s in p.irisSections.take(3))
        if (s.name.isNotEmpty) sectionName(s.name),
    ];
    final helpful = p.irisHelpfulShare;
    return [
      L('${p.irisQuestions} questions to $_tutor',
          '${p.irisQuestions} preguntas a $_tutor'),
      if (sections.isNotEmpty)
        L('about ${sections.join(', ')}', 'sobre ${sections.join(', ')}'),
      if (helpful != null)
        L('${pct(helpful)} helpful', '${pct(helpful)} útiles'),
    ].join(' · ');
  }

  // ---------------------------------------------------------- the subtopics

  Widget _table(PersonReport p) => ChartCard(
        eyebrow: L('Subtopics', 'Subtemas'),
        height: null,
        footnote: L(
          'Mastered / answered / questions in the subtopic. Cumulative, not '
              'just the selected period.',
          'Dominadas / respondidas / preguntas del subtema. Acumulado, no solo '
              'del periodo seleccionado.',
        ),
        child: AdminTable<MasteryRow>(
          rows: p.rows,
          emptyText: L('Nothing answered yet.', 'Todavía sin respuestas.'),
          columns: [
            AdminColumn(
              L('Topic', 'Tema'),
              (r) => Text(r.topic, overflow: TextOverflow.ellipsis),
              sortKey: (r) => r.topic,
              flex: 2,
            ),
            AdminColumn(
              L('Subtopic', 'Subtema'),
              (r) => Text(sectionName(r.section), overflow: TextOverflow.ellipsis),
              sortKey: (r) => sectionName(r.section),
              flex: 3,
            ),
            AdminColumn(
              L('Level', 'Nivel'),
              (r) {
                final m = mastery(r.mastered, r.answered);
                return TestuPill(m.label, color: m.color, borderColor: m.border);
              },
              sortKey: (r) => r.answered == 0 ? 0 : r.mastered / r.answered,
              width: 130,
            ),
            AdminColumn(
              L('Mastered / answered / questions', 'Dominadas / respondidas / preguntas'),
              (r) => Text('${r.mastered}/${r.answered}/${r.questions}',
                  style: AdminTokens.mono(12)),
              sortKey: (r) => r.answered,
              width: 150,
              numeric: true,
            ),
            AdminColumn(
              L('Attempts', 'Intentos'),
              (r) => Text('${r.j['attempts'] ?? 0}', style: AdminTokens.mono(12)),
              sortKey: (r) => (r.j['attempts'] as num?)?.toInt() ?? 0,
              width: 90,
              numeric: true,
            ),
            AdminColumn(
              L('Last activity', 'Última actividad'),
              (r) => Text(date(r.lastActivity), style: AdminTokens.mono(11.5)),
              sortKey: (r) =>
                  r.lastActivity?.millisecondsSinceEpoch ?? 0,
              width: 120,
              numeric: true,
            ),
          ],
        ),
      );
}

/// A topic's line, exactly the app dashboard's row (testu_dashboard.dart:
/// `_liveTopicRow`): what it is, how far the learner got, and the mastery
/// pill they see on their own phone.
class _TopicRow extends StatelessWidget {
  const _TopicRow(this.topic);

  final PersonTopic topic;

  @override
  Widget build(BuildContext context) {
    final m = mastery(topic.mastered, topic.answered);
    final weak = topic.weakest;
    final detail = L(
      '${topic.mastered} of ${topic.answered} questions',
      '${topic.mastered} de ${topic.answered} preguntas',
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(topic.name,
                style: AdminTokens.table, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          // Two lines, not one long one: the level pill is ~150 px of a 410 px
          // card, so "8 de 13 preguntas · revisar Debida diligencia" on one
          // line always ended at "· re…" -- and the subtopic to revisit is the
          // half a reader acts on.
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(detail,
                    style: AdminTokens.muted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (weak != null && weak.isNotEmpty)
                  Text(
                    '${L('review', 'revisar')} ${sectionName(weak)}',
                    style: kLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          TestuPill(m.status.isEmpty ? m.label : '${m.label} · ${m.status}',
              color: m.color, borderColor: m.border),
        ],
      ),
    );
  }
}

/// The app's mastery pill for a tally — its words and its four colour pairs
/// (testu_topics.dart:`masteryOf`), on the one threshold rule [levelOf].
///
/// Ported rather than imported: `testu_topics.dart` reaches the learner
/// session, the PDF viewer and the chat socket, none of which belong in a
/// web console bundle.
({String label, String status, Color color, Color border}) mastery(
    int mastered, int answered) {
  const t = TestuTokens.instance;
  final level = levelOf(mastered, answered);
  final (label, status, color) = switch (level) {
    'beginner' => (
        L('Beginner', 'Principiante'),
        L('Needs practice', 'Necesita práctica'),
        // The fill red misses 4.5:1 at 10.5 px; the app's text red is what
        // the pill has always used.
        AdminTokens.redText,
      ),
    'competent' => (
        L('Competent', 'Competente'),
        L('Review soon', 'Repasar pronto'),
        t.gold,
      ),
    'expert' => (L('Expert', 'Experto'), L('Stable', 'Estable'), t.greenText),
    _ => (L('Not started', 'Sin empezar'), '', t.mut),
  };
  return (
    label: label,
    status: status,
    color: color,
    border: AdminTokens.levelEdge(level),
  );
}
