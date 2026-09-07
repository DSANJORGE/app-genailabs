import 'dart:convert';

/// Typed replies for the plugin's services/testu/* endpoints. Every
/// fromJson is defensive: numerics via `(j['x'] as num?)?.toInt()`, ids and
/// names coerced with `'${j['x']}'` so a server returning a bare number or
/// null for an optional field never crashes the parse (plan ruling R6).
class SuiteModule {
  SuiteModule(this.id, this.name, this.surfaces, this.enabled);
  final String id, name;
  final List<String> surfaces;
  final bool enabled;

  factory SuiteModule.fromJson(Map j) => SuiteModule(
        '${j['id']}',
        '${j['name'] ?? j['id']}',
        [for (final s in (j['surfaces'] as List? ?? [])) '$s'],
        j['enabled'] == true,
      );
}

/// The site's tutor as me.json sends it: the organisation the console
/// belongs to, and the face and language its Iris speaks with. Absent on a
/// server that predates the `persona` key in me.groovy, so every consumer
/// treats it as optional.
class AdminPersona {
  AdminPersona(this.name, {this.avatar, this.organization, this.language});
  final String name;

  /// Avatar image URL, organisation name, `en`/`es`. Empty strings from the
  /// eMe record land here as null: an empty avatar URL would blow up
  /// NetworkImage, and an empty organisation must fall back, not print.
  final String? avatar, organization, language;

  factory AdminPersona.fromJson(Map j) => AdminPersona(
        '${j['name'] ?? ''}',
        avatar: _some(j['avatar']),
        organization: _some(j['organization']),
        language: _some(j['language']),
      );

  static String? _some(Object? v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}

class AdminMe {
  AdminMe(this.id, this.email, this.name, this.role, this.permissions,
      this.modules, {this.persona});
  final String id, email, name, role;
  final Set<String> permissions;
  final List<SuiteModule> modules;
  final AdminPersona? persona;

  bool can(String p) => permissions.contains(p);
  List<SuiteModule> get webModules =>
      [for (final m in modules) if (m.enabled && m.surfaces.contains('web')) m];

  /// What the nav calls this console. The tutor persona carries the client's
  /// name; without one the product name is the honest fallback.
  String get organization => persona?.organization ?? 'TestU';

  factory AdminMe.fromJson(Map j) {
    final u = j['user'] as Map? ?? {};
    final persona = j['persona'];
    return AdminMe(
      '${u['id'] ?? ''}',
      '${u['email'] ?? ''}',
      '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(),
      '${j['role'] ?? 'users'}',
      {for (final p in (j['permissions'] as List? ?? [])) '$p'},
      [for (final m in (j['modules'] as List? ?? [])) SuiteModule.fromJson(m)],
      persona: persona is Map ? AdminPersona.fromJson(persona) : null,
    );
  }
}

class AdminUser {
  AdminUser({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.team,
    required this.role,
    required this.enabled,
    this.lastActivity,
    this.lastlogin,
    this.creationdate,
  });
  final String id, email, firstName, lastName, role;
  final String? team;
  final bool enabled;
  final DateTime? lastActivity;

  /// eMe's raw last-login string (e.g. `2026-09-06 22:55:49 -0300`), kept
  /// verbatim -- it is NOT ISO-8601, so DateTime.parse would throw. Only
  /// `person.json`'s `user.lastlogin` populates this; `personas/users.json`
  /// doesn't send it.
  final String? lastlogin;

  /// eMe's raw account-creation string, kept verbatim for the same reason as
  /// [lastlogin].
  // ponytail: person.groovy does not send this yet -- the Persona header
  // prints the line the day it does, and stays silent until then.
  final String? creationdate;

  String get name => '$firstName $lastName'.trim().isEmpty
      ? id
      : '$firstName $lastName'.trim();

  factory AdminUser.fromJson(Map j) {
    var first = '${j['firstName'] ?? ''}';
    var last = '${j['lastName'] ?? ''}';
    // person.json sends ONE flat `name` where users.json sends the two
    // halves. Split on the first space so the reading rules still have a
    // given name to address the learner by.
    if (first.isEmpty && last.isEmpty) {
      final flat = '${j['name'] ?? ''}'.trim();
      final cut = flat.indexOf(' ');
      first = cut < 0 ? flat : flat.substring(0, cut);
      last = cut < 0 ? '' : flat.substring(cut + 1);
    }
    return AdminUser(
      id: '${j['id']}',
      email: '${j['email'] ?? ''}',
      firstName: first,
      lastName: last,
      team: j['team']?.toString(),
      role: '${j['role'] ?? 'users'}',
      enabled: j['enabled'] != false,
      lastActivity: DateTime.tryParse('${j['lastactivity'] ?? ''}'),
      lastlogin: j['lastlogin']?.toString(),
      creationdate: j['creationdate']?.toString(),
    );
  }
}

class AdminTeam {
  AdminTeam({
    required this.id,
    required this.name,
    this.parent,
    this.manager,
    this.location,
    this.costcenter,
    this.members = 0,
  });
  final String id, name;
  final String? parent, manager, location, costcenter;
  final int members;

  factory AdminTeam.fromJson(Map j) => AdminTeam(
        id: '${j['id']}',
        name: '${j['name'] ?? j['id']}',
        parent: j['parent']?.toString(),
        manager: j['manager']?.toString(),
        location: j['location']?.toString(),
        costcenter: j['costcenter']?.toString(),
        members: (j['members'] as num?)?.toInt() ?? 0,
      );
}

/// Aggregate level for a mastery tally — one row, one user x topic, or a
/// whole person — on the same thresholds as the app's own
/// testu_topics.dart:masteryOf: under half right = beginner, under 90 % =
/// competent, no answers = not started (null). The one place the console
/// turns two counts into a level; admin_mastery.dart re-exports it, which is
/// how the Dominio screen and the reading rules stay on one rule.
String? levelOf(int mastered, int answered) {
  if (answered == 0) return null;
  final share = mastered / answered;
  if (share >= 0.9) return 'expert';
  if (share >= 0.5) return 'competent';
  return 'beginner';
}

/// One user x topic-section mastery row from analytics/report.json (and,
/// since Task 9, analytics/person.json's `rows[]`, same shape). Kept as a
/// thin view over the raw map (rather than named fields for every column)
/// since the report table just displays these; see report({topic, team}).
class MasteryRow {
  MasteryRow(this.j);
  final Map j;

  String get user => '${j['user']}';
  String get name => '${j['name'] ?? j['user']}';
  String? get team => j['team']?.toString();
  String get topicId => '${j['entitytopic'] ?? ''}';
  String get topic => '${j['topic'] ?? j['entitytopic'] ?? ''}';
  String get section => '${j['section'] ?? j['componentsection'] ?? ''}';

  /// Subtopic identity. Section ids are catalog-wide ordinals ("5"), so the
  /// topic has to be part of the key or two topics would share one column.
  String get sectionKey => '$topicId/${j['componentsection']}';
  int get questions => (j['questions'] as num?)?.toInt() ?? 0;
  int get answered => (j['answered'] as num?)?.toInt() ?? 0;
  int get mastered => (j['mastered'] as num?)?.toInt() ?? 0;
  String? get level => j['level']?.toString();
  DateTime? get lastActivity => DateTime.tryParse('${j['lastactivity'] ?? ''}');

  // person.json's rows[] add these four confidence-vs-correctness counters.
  int get certainCorrect => (j['certaincorrect'] as num?)?.toInt() ?? 0;
  int get certainWrong => (j['certainwrong'] as num?)?.toInt() ?? 0;
  int get unsureCorrect => (j['unsurecorrect'] as num?)?.toInt() ?? 0;
  int get unsureWrong => (j['unsurewrong'] as num?)?.toInt() ?? 0;
}

class ReportSummary {
  ReportSummary(this.activeUsers7d, this.answers7d, this.levels);
  final int activeUsers7d, answers7d;
  final Map<String, int> levels;

  factory ReportSummary.fromJson(Map j) => ReportSummary(
        (j['activeusers7d'] as num?)?.toInt() ?? 0,
        (j['answers7d'] as num?)?.toInt() ?? 0,
        {
          for (final e in ((j['levels'] as Map?) ?? {}).entries)
            '${e.key}': (e.value as num).toInt(),
        },
      );
}

class AdminReport {
  AdminReport(this.rows, this.summary, this.topics);
  final List<MasteryRow> rows;
  final ReportSummary summary;
  final Map<String, String> topics;
}

/// One calendar day of console analytics. The console's charts all read this
/// one shape (people/answers over time, minutes, sessions, misconceptions,
/// correct vs incorrect), so a screen never invents a second series type.
///
/// Every counter defaults to 0: the daily series is dense (a day with no
/// activity is still a point on the x axis), and the server only sends the
/// fields a given endpoint computes.
class DayPoint {
  const DayPoint(
    this.day, {
    this.people = 0,
    this.answers = 0,
    this.minutes = 0,
    this.sessions = 0,
    this.certainwrong = 0,
    this.questions = 0,
    this.correct = 0,
  });

  final DateTime day;
  final int people, answers, minutes, sessions, certainwrong, questions, correct;

  /// `day` is `yyyy-MM-dd`; every counter is missing unless the endpoint
  /// computes it (`correct` only appears in person.json's series).
  factory DayPoint.fromJson(Map j) => DayPoint(
        DateTime.tryParse('${j['day'] ?? ''}') ?? DateTime(1970),
        people: (j['people'] as num?)?.toInt() ?? 0,
        answers: (j['answers'] as num?)?.toInt() ?? 0,
        minutes: (j['minutes'] as num?)?.toInt() ?? 0,
        sessions: (j['sessions'] as num?)?.toInt() ?? 0,
        certainwrong: (j['certainwrong'] as num?)?.toInt() ?? 0,
        questions: (j['questions'] as num?)?.toInt() ?? 0,
        correct: (j['correct'] as num?)?.toInt() ?? 0,
      );
}

/// Notstarted/beginner/competent/expert headcount bucket, shared by
/// overview.levels, topics[].levels and teams[].levels.
class Levels {
  const Levels({
    this.notstarted = 0,
    this.beginner = 0,
    this.competent = 0,
    this.expert = 0,
  });
  final int notstarted, beginner, competent, expert;

  int get total => notstarted + beginner + competent + expert;
  Map<String, int> get asMap => {
        'notstarted': notstarted,
        'beginner': beginner,
        'competent': competent,
        'expert': expert,
      };

  factory Levels.fromJson(Map j) => Levels(
        notstarted: (j['notstarted'] as num?)?.toInt() ?? 0,
        beginner: (j['beginner'] as num?)?.toInt() ?? 0,
        competent: (j['competent'] as num?)?.toInt() ?? 0,
        expert: (j['expert'] as num?)?.toInt() ?? 0,
      );
}

/// A topic's weakest section (overview.topics[].weakest); null when the
/// topic has no beginners to call out.
class Weakest {
  Weakest(this.section, this.name, this.beginners);
  final String section, name;
  final int beginners;

  factory Weakest.fromJson(Map j) => Weakest(
        '${j['section'] ?? ''}',
        '${j['name'] ?? j['section'] ?? ''}',
        (j['beginners'] as num?)?.toInt() ?? 0,
      );
}

class TopicStat {
  TopicStat(this.id, this.name, this.people, this.levels, this.weakest);
  final String id, name;
  final int people;
  final Levels levels;
  final Weakest? weakest;

  factory TopicStat.fromJson(Map j) => TopicStat(
        '${j['id'] ?? ''}',
        '${j['name'] ?? j['id'] ?? ''}',
        (j['people'] as num?)?.toInt() ?? 0,
        Levels.fromJson(j['levels'] as Map? ?? {}),
        j['weakest'] == null ? null : Weakest.fromJson(j['weakest'] as Map),
      );
}

class TeamStat {
  TeamStat(
    this.id,
    this.name,
    this.members,
    this.activated,
    this.active7d,
    this.levels,
    this.weakest,
  );
  final String id, name;
  final int members, activated, active7d;
  final Levels levels;

  /// Unlike [TopicStat.weakest] this is just the weakest topic's NAME
  /// (or null), not a [Weakest] record.
  final String? weakest;

  /// `overview.teams[]` includes a bucket with `id: ""`, `name: ""` for
  /// learners without a team; kept as-is, never filtered.
  factory TeamStat.fromJson(Map j) => TeamStat(
        '${j['id'] ?? ''}',
        '${j['name'] ?? ''}',
        (j['members'] as num?)?.toInt() ?? 0,
        (j['activated'] as num?)?.toInt() ?? 0,
        (j['active7d'] as num?)?.toInt() ?? 0,
        Levels.fromJson(j['levels'] as Map? ?? {}),
        j['weakest']?.toString(),
      );
}

class Calibration {
  Calibration(this.cc, this.cu, this.ic, this.iu);
  final int cc, cu, ic, iu;

  int get total => cc + cu + ic + iu;
  double? get calibrated => total == 0 ? null : (cc + ic) / total;

  factory Calibration.fromJson(Map j) => Calibration(
        (j['cc'] as num?)?.toInt() ?? 0,
        (j['cu'] as num?)?.toInt() ?? 0,
        (j['ic'] as num?)?.toInt() ?? 0,
        (j['iu'] as num?)?.toInt() ?? 0,
      );
}

/// One row of `overview.gaps[]`. The server sends more keys than this model
/// keeps (`helpfulShare`); `topicId` and `levels` are the two additions
/// beyond the brief's field list -- everything else is left unparsed.
class Gap {
  Gap(
    this.section,
    this.name,
    this.topic,
    this.topicId,
    this.score,
    this.beginners,
    this.questions,
    this.misconceptions,
    this.unanswered,
    this.people,
    this.levels,
  );
  final String section, name, topic, topicId;
  final double score;
  final int beginners, questions, misconceptions, unanswered, people;

  /// Headcount per level for this subtopic, so a gap row carries the same
  /// stacked bar a topic row does instead of inferring one from [beginners].
  final Levels levels;

  factory Gap.fromJson(Map j) => Gap(
        '${j['section'] ?? ''}',
        '${j['name'] ?? ''}',
        '${j['topic'] ?? ''}',
        '${j['topicId'] ?? ''}',
        ((j['score'] as num?) ?? 0).toDouble(),
        (j['beginners'] as num?)?.toInt() ?? 0,
        (j['questions'] as num?)?.toInt() ?? 0,
        (j['misconceptions'] as num?)?.toInt() ?? 0,
        (j['unanswered'] as num?)?.toInt() ?? 0,
        (j['people'] as num?)?.toInt() ?? 0,
        Levels.fromJson(j['levels'] as Map? ?? {}),
      );
}

/// One IRIS section row (`iris.sections[]`, and `person.irisSections`).
class SectionQ {
  SectionQ(this.section, this.name, this.questions, this.helpfulShare);
  final String section, name;
  final int questions;
  final double? helpfulShare;

  factory SectionQ.fromJson(Map j) => SectionQ(
        '${j['section'] ?? ''}',
        '${j['name'] ?? j['section'] ?? ''}',
        (j['questions'] as num?)?.toInt() ?? 0,
        (j['helpfulShare'] as num?)?.toDouble(),
      );
}

/// IRIS (the tutor's Q&A assistant) usage stats, shared by
/// `overview.iris` and `activity.iris`. Shares are `null` when the org
/// hasn't rated/cited enough to compute one.
class IrisStats {
  IrisStats(
    this.questions,
    this.people,
    this.citedShare,
    this.ratedShare,
    this.helpfulShare,
    this.themes,
    this.sections,
    this.labels,
  );
  final int questions, people;
  final double? citedShare, ratedShare, helpfulShare;
  final Map<String, int> themes;
  final List<SectionQ> sections;
  final List<(String label, int count)> labels;

  factory IrisStats.fromJson(Map j) => IrisStats(
        (j['questions'] as num?)?.toInt() ?? 0,
        (j['people'] as num?)?.toInt() ?? 0,
        (j['citedShare'] as num?)?.toDouble(),
        (j['ratedShare'] as num?)?.toDouble(),
        (j['helpfulShare'] as num?)?.toDouble(),
        {
          for (final t in (j['themes'] as List? ?? []))
            '${(t as Map)['theme'] ?? ''}': (t['count'] as num?)?.toInt() ?? 0,
        },
        [
          for (final s in (j['sections'] as List? ?? []))
            SectionQ.fromJson(s as Map),
        ],
        [
          for (final l in (j['labels'] as List? ?? []))
            (
              '${(l as Map)['label'] ?? ''}',
              (l['count'] as num?)?.toInt() ?? 0,
            ),
        ],
      );
}

class Cohort {
  Cohort(this.total, this.activated, this.active7d, this.active30d);
  final int total, activated, active7d, active30d;

  factory Cohort.fromJson(Map j) => Cohort(
        (j['total'] as num?)?.toInt() ?? 0,
        (j['activated'] as num?)?.toInt() ?? 0,
        (j['active7d'] as num?)?.toInt() ?? 0,
        (j['active30d'] as num?)?.toInt() ?? 0,
      );
}

/// analytics/overview.json's full reply.
class Overview {
  Overview({
    required this.cohort,
    required this.series,
    this.previousSeries = const [],
    required this.levels,
    required this.topics,
    required this.calibration,
    required this.teams,
    this.median,
    required this.previous,
    required this.gaps,
    required this.iris,
  });
  final Cohort cohort;
  final List<DayPoint> series;

  /// The same window immediately before [series], for the activity chart's
  /// ghost line. Empty on a server that predates it -- the chart then draws
  /// no comparison rather than a flat zero line.
  final List<DayPoint> previousSeries;
  final Levels levels;
  final List<TopicStat> topics;
  final Calibration calibration;
  final List<TeamStat> teams;

  /// Null when the org has fewer than 5 learners (server withholds it).
  final ({double activeShare, double expertShare})? median;
  final Map<String, int> previous;
  final List<Gap> gaps;
  final IrisStats iris;

  factory Overview.fromJson(Map j) {
    final median = j['median'] as Map?;
    return Overview(
      cohort: Cohort.fromJson(j['cohort'] as Map? ?? {}),
      series: [
        for (final d in (j['series'] as List? ?? [])) DayPoint.fromJson(d as Map),
      ],
      previousSeries: [
        for (final d in (j['previousSeries'] as List? ?? []))
          DayPoint.fromJson(d as Map),
      ],
      levels: Levels.fromJson(j['levels'] as Map? ?? {}),
      topics: [
        for (final t in (j['topics'] as List? ?? [])) TopicStat.fromJson(t as Map),
      ],
      calibration: Calibration.fromJson(j['calibration'] as Map? ?? {}),
      teams: [
        for (final t in (j['teams'] as List? ?? [])) TeamStat.fromJson(t as Map),
      ],
      median: median == null
          ? null
          : (
              activeShare: ((median['activeShare'] as num?) ?? 0).toDouble(),
              expertShare: ((median['expertShare'] as num?) ?? 0).toDouble(),
            ),
      previous: {
        for (final e in ((j['previous'] as Map?) ?? {}).entries)
          '${e.key}': (e.value as num).toInt(),
      },
      gaps: [for (final g in (j['gaps'] as List? ?? [])) Gap.fromJson(g as Map)],
      iris: IrisStats.fromJson(j['iris'] as Map? ?? {}),
    );
  }
}

/// One row of `activity.inactive[]`.
class InactivePerson {
  InactivePerson(this.user, this.name, this.team, this.lastActivity);
  final String user, name;
  final String? team;

  /// ISO-8601 or null (unlike [AdminUser.lastlogin], this one IS parseable).
  final DateTime? lastActivity;

  factory InactivePerson.fromJson(Map j) => InactivePerson(
        '${j['user'] ?? ''}',
        '${j['name'] ?? j['user'] ?? ''}',
        j['team']?.toString(),
        j['lastactivity'] == null
            ? null
            : DateTime.tryParse('${j['lastactivity']}'),
      );
}

/// analytics/activity.json's full reply.
class Activity {
  Activity({
    required this.series,
    required this.funnel,
    required this.hours,
    required this.inactive,
    required this.iris,
  });
  final List<DayPoint> series;
  final Map<String, int> funnel;

  /// `[weekday, hour, count]` triples, Monday = 0.
  final List<(int weekday, int hour, int count)> hours;
  final List<InactivePerson> inactive;
  final IrisStats iris;

  factory Activity.fromJson(Map j) => Activity(
        series: [
          for (final d in (j['series'] as List? ?? [])) DayPoint.fromJson(d as Map),
        ],
        funnel: {
          for (final e in ((j['funnel'] as Map?) ?? {}).entries)
            '${e.key}': (e.value as num).toInt(),
        },
        hours: [
          for (final h in (j['hours'] as List? ?? []))
            if (h is List && h.length >= 3 && h[0] is num && h[1] is num && h[2] is num)
              ((h[0] as num).toInt(), (h[1] as num).toInt(), (h[2] as num).toInt()),
        ],
        inactive: [
          for (final p in (j['inactive'] as List? ?? []))
            InactivePerson.fromJson(p as Map),
        ],
        iris: IrisStats.fromJson(j['iris'] as Map? ?? {}),
      );
}

/// One row of `person.topics[]` -- unlike [TopicStat], scoped to a single
/// learner (a level and mastered/answered counts, not a headcount bucket).
class PersonTopic {
  PersonTopic(this.id, this.name, this.level, this.mastered, this.answered,
      this.weakest);
  final String id, name;
  final String? level;
  final int mastered, answered;

  /// The learner's weakest SECTION name for this topic, or null.
  final String? weakest;

  factory PersonTopic.fromJson(Map j) => PersonTopic(
        '${j['id'] ?? ''}',
        '${j['name'] ?? j['id'] ?? ''}',
        j['level']?.toString(),
        (j['mastered'] as num?)?.toInt() ?? 0,
        (j['answered'] as num?)?.toInt() ?? 0,
        j['weakest']?.toString(),
      );
}

/// analytics/person.json's full reply, for one learner.
class PersonReport {
  PersonReport({
    required this.user,
    required this.rows,
    required this.series,
    required this.calibration,
    required this.topics,
    required this.sessions,
    required this.minutes,
    required this.activeDays,
    required this.irisQuestions,
    required this.irisSections,
    this.irisHelpfulShare,
  });
  final AdminUser user;
  final List<MasteryRow> rows;
  final List<DayPoint> series;
  final Calibration calibration;
  final List<PersonTopic> topics;
  final int sessions, minutes, activeDays;
  final int irisQuestions;
  final List<SectionQ> irisSections;
  final double? irisHelpfulShare;

  factory PersonReport.fromJson(Map j) {
    final usage = j['usage'] as Map? ?? {};
    final iris = j['iris'] as Map? ?? {};
    return PersonReport(
      user: AdminUser.fromJson(j['user'] as Map? ?? {}),
      rows: [for (final r in (j['rows'] as List? ?? [])) MasteryRow(r as Map)],
      series: [
        for (final d in (j['series'] as List? ?? [])) DayPoint.fromJson(d as Map),
      ],
      calibration: Calibration.fromJson(j['calibration'] as Map? ?? {}),
      topics: [
        for (final t in (j['topics'] as List? ?? []))
          PersonTopic.fromJson(t as Map),
      ],
      sessions: (usage['sessions'] as num?)?.toInt() ?? 0,
      minutes: (usage['minutes'] as num?)?.toInt() ?? 0,
      activeDays: (usage['activeDays'] as num?)?.toInt() ?? 0,
      irisQuestions: (iris['questions'] as num?)?.toInt() ?? 0,
      irisSections: [
        for (final s in (iris['sections'] as List? ?? []))
          SectionQ.fromJson(s as Map),
      ],
      irisHelpfulShare: (iris['helpfulShare'] as num?)?.toDouble(),
    );
  }
}

/// One citation in an `ask.json` reply. `value` is pre-formatted to a
/// String here: numbers/strings pass through as-is, maps/lists are
/// compact-JSON-encoded (the server may send any of the four).
class Citation {
  Citation(this.id, this.label, this.value, this.view, this.filters);
  final String id, label, value, view;
  final Map<String, String> filters;

  factory Citation.fromJson(Map j) {
    final v = j['value'];
    final value = switch (v) {
      null => '',
      num n => n is double && n == n.roundToDouble() ? n.toInt().toString() : '$n',
      String s => s,
      _ => jsonEncode(v),
    };
    return Citation(
      '${j['id'] ?? ''}',
      '${j['label'] ?? ''}',
      value,
      '${j['view'] ?? ''}',
      {
        for (final e in ((j['filters'] as Map?) ?? {}).entries)
          '${e.key}': '${e.value}',
      },
    );
  }
}

/// analytics/ask.json's success reply (`{ok:true, ...}`); on `ok:false` or
/// a non-2xx status [AdminApi.ask] throws `AskUnavailable` instead of
/// constructing this.
class AskReply {
  AskReply(this.answer, this.citations, this.followups);
  final String answer;
  final List<Citation> citations;
  final List<String> followups;

  factory AskReply.fromJson(Map j) => AskReply(
        '${j['answer'] ?? ''}',
        [
          for (final c in (j['citations'] as List? ?? []))
            Citation.fromJson(c as Map),
        ],
        [for (final f in (j['followups'] as List? ?? [])) '$f'],
      );
}
