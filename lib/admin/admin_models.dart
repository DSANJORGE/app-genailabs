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

class AdminMe {
  AdminMe(this.id, this.email, this.name, this.role, this.permissions,
      this.modules);
  final String id, email, name, role;
  final Set<String> permissions;
  final List<SuiteModule> modules;

  bool can(String p) => permissions.contains(p);
  List<SuiteModule> get webModules =>
      [for (final m in modules) if (m.enabled && m.surfaces.contains('web')) m];

  factory AdminMe.fromJson(Map j) {
    final u = j['user'] as Map? ?? {};
    return AdminMe(
      '${u['id'] ?? ''}',
      '${u['email'] ?? ''}',
      '${u['firstName'] ?? ''} ${u['lastName'] ?? ''}'.trim(),
      '${j['role'] ?? 'users'}',
      {for (final p in (j['permissions'] as List? ?? [])) '$p'},
      [for (final m in (j['modules'] as List? ?? [])) SuiteModule.fromJson(m)],
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
  });
  final String id, email, firstName, lastName, role;
  final String? team;
  final bool enabled;
  final DateTime? lastActivity;

  String get name => '$firstName $lastName'.trim().isEmpty
      ? id
      : '$firstName $lastName'.trim();

  factory AdminUser.fromJson(Map j) => AdminUser(
        id: '${j['id']}',
        email: '${j['email'] ?? ''}',
        firstName: '${j['firstName'] ?? ''}',
        lastName: '${j['lastName'] ?? ''}',
        team: j['team']?.toString(),
        role: '${j['role'] ?? 'users'}',
        enabled: j['enabled'] != false,
        lastActivity: DateTime.tryParse('${j['lastactivity'] ?? ''}'),
      );
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

/// One user x topic-section mastery row from analytics/report.json. Kept as
/// a thin view over the raw map (rather than named fields for every column)
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
  int get questions => (j['questions'] as num?)?.toInt() ?? 0;
  int get answered => (j['answered'] as num?)?.toInt() ?? 0;
  int get mastered => (j['mastered'] as num?)?.toInt() ?? 0;
  String? get level => j['level']?.toString();
  DateTime? get lastActivity => DateTime.tryParse('${j['lastactivity'] ?? ''}');
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
}
