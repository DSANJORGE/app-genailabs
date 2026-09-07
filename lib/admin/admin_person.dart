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
  Widget build(BuildContext context) => fetched(_page);

  String get _persona {
    final name = widget.me.persona?.name ?? '';
    return name.isEmpty ? 'Iris' : name;
  }

  Widget _page(BuildContext context, _PersonData d, String? highlight) {
    final p = d.person;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(d),
          const SizedBox(height: 20),
          Reading(
            personaName: _persona,
            avatarUrl: widget.me.persona?.avatar,
            sentences: personReading(p),
          ),
          const SizedBox(height: 22),
          Pulse(active: points(highlight, 'topic'), child: _pair(context, p)),
          const SizedBox(height: 16),
          _week(p),
          const SizedBox(height: 16),
          _usage(p),
          const SizedBox(height: 16),
          Pulse(active: points(highlight, 'subtopic'), child: _table(p)),
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
            TestuPill(_role(u.role), color: t.mut, borderColor: t.line2),
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

  static String _role(String role) => switch (role) {
        'admin' || 'orgadmin' => L('Admin', 'Admin'),
        'manager' => L('Manager', 'Responsable'),
        _ => L('Member', 'Miembro'),
      };

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
    return at == null ? p.user.lastlogin : _date(at);
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
        'Calibration = answers where confidence matched the result.',
        'Calibración = respuestas donde la confianza coincidió con el resultado.',
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

  Widget _week(PersonReport p) => ChartCard(
        eyebrow: L('Last 30 days', 'Últimos 30 días'),
        legend: [
          (AdminTokens.seriesPositive, L('Correct', 'Correctas')),
          (AdminTokens.seriesNegative, L('Incorrect', 'Incorrectas')),
        ],
        footnote: L(
          'The last 30 days, whatever period the rest of the console is on.',
          'Los últimos 30 días, sea cual sea el periodo del resto de la consola.',
        ),
        child: correctIncorrectBars([
          for (final d in p.series)
            (
              label: _dayLabel(d.day),
              correct: d.correct,
              // The server sends the day's total and how many were right; a
              // reply that ever disagrees must not draw a negative bar.
              incorrect: d.answers - d.correct < 0 ? 0 : d.answers - d.correct,
            ),
        ]),
      );

  // ------------------------------------------------------------ usage line

  Widget _usage(PersonReport p) {
    final iris = _irisLine(p);
    return Column(
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
        const SizedBox(height: 6),
        // Same reply as the chart above, so the same 30 days.
        Text(L('Both lines cover the last 30 days.',
            'Ambas líneas cubren los últimos 30 días.'),
            style: AdminTokens.footnote),
      ],
    );
  }

  /// What this learner asked the tutor, as one sentence. Every clause is
  /// dropped when the server has nothing for it: a person who never asked
  /// gets no line at all, rather than a row of zeros.
  String? _irisLine(PersonReport p) {
    if (p.irisQuestions == 0) return null;
    final sections = [
      for (final s in p.irisSections.take(3))
        if (s.name.isNotEmpty) _sectionName(s.name),
    ];
    final helpful = p.irisHelpfulShare;
    return [
      L('${p.irisQuestions} questions to $_persona',
          '${p.irisQuestions} preguntas a $_persona'),
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
              (r) => Text(_sectionName(r.section), overflow: TextOverflow.ellipsis),
              sortKey: (r) => _sectionName(r.section),
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
              (r) => Text(r.lastActivity == null ? '—' : _date(r.lastActivity!),
                  style: AdminTokens.mono(11.5)),
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
            width: 150,
            child: Text(topic.name,
                style: AdminTokens.table, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              weak == null || weak.isEmpty
                  ? detail
                  : '$detail · ${L('review', 'revisar')} ${_sectionName(weak)}',
              style: AdminTokens.muted,
              overflow: TextOverflow.ellipsis,
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
        int mastered, int answered) =>
    switch (levelOf(mastered, answered)) {
      'beginner' => (
          label: L('Beginner', 'Principiante'),
          status: L('Needs practice', 'Necesita práctica'),
          color: const Color(0xFFD08B8B),
          border: const Color(0xFF6E3535),
        ),
      'competent' => (
          label: L('Competent', 'Competente'),
          status: L('Review soon', 'Repasar pronto'),
          color: const Color(0xFFCDB96A),
          border: const Color(0xFF8A7A3A),
        ),
      'expert' => (
          label: L('Expert', 'Experto'),
          status: L('Stable', 'Estable'),
          color: const Color(0xFF7DBB9C),
          border: const Color(0xFF2F6A4C),
        ),
      _ => (
          label: L('Not started', 'Sin empezar'),
          status: '',
          color: const Color(0xFF8B8F98),
          border: const Color(0xFF2C2C33),
        ),
    };

/// Section titles arrive numbered ("2. Debida diligencia"); the ordinal is
/// noise everywhere the console reads one back.
String _sectionName(String raw) => raw.replaceFirst(RegExp(r'^\d+\.\s*'), '');

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}

String _dayLabel(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
