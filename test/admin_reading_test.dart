import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_reading.dart';
import 'package:genai_labs/testu/testu_i18n.dart';

/// Overview fixtures go through fromJson rather than the constructor: the
/// reading rules read the same keys the server sends, so a fixture that
/// parses is a fixture that matches production.
Overview _overview({
  Map<String, Object?> cohort = const {'total': 24, 'activated': 20, 'active7d': 12},
  List<Map<String, Object?>> series = const [],
  List<Map<String, Object?>> topics = const [],
  Map<String, Object?> previous = const {},
}) =>
    Overview.fromJson({
      'cohort': cohort,
      'series': series,
      'topics': topics,
      'previous': previous,
    });

Map<String, Object?> _topic(String name, {String? weakest, int beginners = 0}) => {
      'id': name.toLowerCase(),
      'name': name,
      'people': 10,
      'levels': {'beginner': beginners, 'competent': 3, 'expert': 2},
      if (weakest != null)
        'weakest': {'section': 's1', 'name': weakest, 'beginners': beginners},
    };

/// One team, used by both team-reading tests.
class TestuTeamFixture {
  static TeamStat get pisco => TeamStat.fromJson({
        'id': 't1',
        'name': 'Operaciones Pisco',
        'members': 9,
        'activated': 8,
        'active7d': 6,
        'levels': {'beginner': 2, 'competent': 4, 'expert': 2},
        'weakest': 'Ciberseguridad',
      });
}

void main() {
  group('overviewReading', () {
    test('activity leads, with the week-over-week delta', () {
      final o = _overview(previous: {'active7d': 9});
      expect(overviewReading(o).first,
          '12 of 24 people active this week, 3 more than the week before.');
    });

    test('an equal week says so rather than showing a zero', () {
      final o = _overview(previous: {'active7d': 12});
      expect(overviewReading(o).first,
          '12 of 24 people active this week, same as the week before.');
    });

    test('a fall reads as fewer', () {
      final o = _overview(previous: {'active7d': 15});
      expect(overviewReading(o).first,
          '12 of 24 people active this week, 3 fewer than the week before.');
    });

    test('the weakest subtopic across the filter', () {
      final o = _overview(topics: [
        _topic('Ciberseguridad', weakest: 'Phishing', beginners: 4),
        _topic('Derechos Humanos', weakest: 'Debida diligencia', beginners: 6),
      ]);
      expect(
        overviewReading(o),
        contains(
            'In Derechos Humanos the weakest subtopic is “Debida diligencia”: '
            'Beginner for 6 people.'),
      );
    });

    test('misconceptions are the finding that matters most', () {
      final o = _overview(series: [
        {'day': '2026-09-01', 'certainwrong': 4},
        {'day': '2026-09-02', 'certainwrong': 5},
      ]);
      expect(
        overviewReading(o),
        contains('9 confident but wrong answers in the period: misconceptions, '
            'the finding that matters most.'),
      );
    });

    test('a cohort that has not answered gets one teaching sentence', () {
      final o = _overview(
        cohort: {'total': 24, 'activated': 0, 'active7d': 0},
        previous: {'active7d': 0},
        topics: [_topic('Derechos Humanos', weakest: 'Debida diligencia', beginners: 6)],
      );
      expect(overviewReading(o), [
        'Nobody has answered yet. Data appears 15 minutes after the first session.',
      ]);
    });

    test('at most three sentences even when every rule fires', () {
      final o = _overview(
        previous: {'active7d': 9},
        series: [
          {'day': '2026-09-01', 'certainwrong': 9},
        ],
        topics: [
          _topic('Derechos Humanos', weakest: 'Debida diligencia', beginners: 6),
          _topic('Ciberseguridad', weakest: 'Phishing', beginners: 8),
        ],
      );
      expect(overviewReading(o).length, 3);
    });
  });

  test('activityReading opens on adoption', () {
    final a = Activity.fromJson({
      'series': [],
      'funnel': {'cohort': 24, 'signedin': 19, 'answered': 17, 'active7d': 12},
      'inactive': [
        for (var i = 0; i < 5; i++) {'user': 'u$i', 'name': 'P$i'},
      ],
    });
    final r = activityReading(a, Cohort(24, 17, 12, 20));
    expect(r.first,
        '19 of 24 people have opened the app; 17 have answered at least one question.');
    expect(r, contains('5 people have gone more than 7 days without activity.'));
  });

  test('teamReading compares the active share with the organisation median', () {
    final t = TestuTeamFixture.pisco;
    final o = Overview.fromJson({
      'cohort': {'total': 24, 'activated': 20, 'active7d': 12},
      'median': {'activeShare': 0.48, 'expertShare': 0.2},
    });
    expect(teamReading(t, o).first,
        'Operaciones Pisco: 6 of 9 people active this week, 67%.');
    expect(teamReading(t, o),
        contains('That is above the organisation median of 48%.'));
  });

  // Spanish is the shipping language and "más débil" is the console's one
  // word for weakness -- the teams column and the topic rows both use it.
  test('the Spanish team reading says «más débil», never «más flojo»', () {
    testuLang.value = 'es';
    addTearDown(() => testuLang.value = 'en');
    final t = TestuTeamFixture.pisco;
    final o = Overview.fromJson({'cohort': {'total': 24, 'activated': 20, 'active7d': 12}});
    final r = teamReading(t, o);
    expect(r, contains('El tema más débil es Ciberseguridad.'));
    expect(r.first, 'Operaciones Pisco: 6 de 9 personas activas esta semana, 67 %.');
  });

  test('personReading mirrors the tutor greeting: last worked, then weakest', () {
    final p = PersonReport.fromJson({
      'user': {'id': 'u1', 'firstName': 'Ana', 'lastName': 'Quispe'},
      'rows': [
        {
          'user': 'u1',
          'topic': 'Derechos Humanos',
          'section': '2. Debida diligencia',
          'answered': 5,
          'mastered': 3,
          'lastactivity': '2026-09-05T10:00:00',
        },
        {
          'user': 'u1',
          'topic': 'Ciberseguridad',
          'section': 'Phishing',
          'answered': 5,
          'mastered': 1,
          'lastactivity': '2026-09-01T10:00:00',
        },
      ],
    });
    final r = personReading(p);
    expect(r.first,
        'The last thing Ana worked on was “Debida diligencia”: 3 of 5 right.');
    expect(r, contains('Where Ana is weakest is “Phishing”: 1 of 5 right.'));
  });

  test('a learner without answers gets the invitation, not a broken sentence', () {
    final p = PersonReport.fromJson({
      'user': {'id': 'u1', 'firstName': 'Ana', 'lastName': 'Quispe'},
      'rows': [],
    });
    expect(personReading(p), ['Ana has not answered anything yet.']);
  });
}
