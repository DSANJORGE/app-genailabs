import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_nav.dart';

void main() {
  test('d7 spans seven inclusive days', () {
    final f = AnalyticsFilters();
    expect(f.period, Period.d7);
    expect(f.days, 7);
    expect(f.query['period'], 'd7');
    expect(f.query['from'], matches(r'^\d{4}-\d{2}-\d{2}$'));
    expect(f.query['to'], matches(r'^\d{4}-\d{2}-\d{2}$'));
  });

  test('d30 and d90 span their whole window; pilot starts at kPilotStart', () {
    final f = AnalyticsFilters();
    f.set(period: Period.d30);
    expect(f.days, 30);
    f.set(period: Period.d90);
    expect(f.days, 90);
  });

  test('pilot never hands a screen an inverted window', () {
    final f = AnalyticsFilters();
    f.set(period: Period.pilot);
    expect(f.from.isAfter(f.to), isFalse);
    expect(f.days, greaterThanOrEqualTo(1));
    // From launch day on, the window opens on the pilot's first day.
    if (!kPilotStart.isAfter(f.to)) expect(f.from, kPilotStart);
  });

  test('set() does not notify when nothing actually changes', () {
    final f = AnalyticsFilters();
    f.set(period: Period.d30, topic: 'seguridad');
    var n = 0;
    f.addListener(() => n++);

    f.set(period: Period.d30); // re-tapping the active segment
    f.set(topic: 'seguridad'); // re-picking the current topic
    f.set(); // nothing at all
    f.set(clearTeam: true); // clearing an already-empty filter
    expect(n, 0);

    f.set(period: Period.d7);
    expect(n, 1);
  });

  test('query omits the filters that are not set', () {
    final f = AnalyticsFilters();
    expect(f.query.containsKey('entitytopic'), isFalse);
    expect(f.query.containsKey('team'), isFalse);

    f.set(topic: 'seguridad', team: 'norte');
    expect(f.query['entitytopic'], 'seguridad');
    expect(f.query['team'], 'norte');

    f.set(clearTopic: true);
    expect(f.query.containsKey('entitytopic'), isFalse);
    expect(f.query['team'], 'norte');

    f.set(clearTeam: true);
    expect(f.query.containsKey('team'), isFalse);
  });

  test('AnalyticsFilters notifies once per set', () {
    final f = AnalyticsFilters();
    var n = 0;
    f.addListener(() => n++);
    f.set(period: Period.d30, topic: 'seguridad');
    expect(n, 1);
  });

  test('ConsoleNav.go notifies once', () {
    final nav = ConsoleNav();
    var n = 0;
    nav.addListener(() => n++);
    nav.go('persona', entityId: 'ana', highlight: 'answers');
    expect(n, 1);
    expect(nav.value.section, 'persona');
    expect(nav.value.entityId, 'ana');
    expect(nav.value.highlight, 'answers');
  });
}
