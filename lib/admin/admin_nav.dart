import 'package:flutter/foundation.dart';

import '../testu/testu_i18n.dart';

/// Console filter and navigation state — the two notifiers every analytics
/// screen listens to. Kept out of the widget files so a screen can be built
/// and tested without a shell around it.

/// The pilot's first day. Minsur launches 2026-09-14.
// ponytail: constant; a catalog setting when a second client exists.
final DateTime kPilotStart = DateTime(2026, 9, 14);

enum Period { d7, d30, d90, pilot }

extension PeriodLabel on Period {
  /// What the context bar calls this window — and what any screen without a
  /// context bar has to print, so a period-scoped number is never silent
  /// about which period it is.
  String get label => switch (this) {
        Period.d7 => L('7 d', '7 d'),
        Period.d30 => L('30 d', '30 d'),
        Period.d90 => L('90 d', '90 d'),
        Period.pilot => L('Pilot', 'Piloto'),
      };
}

/// `2026-09-07` — the date format every analytics query speaks.
String ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Period, topic and team, shared by Resumen, Actividad and Dominio so the
/// three screens never disagree about what window is on screen.
///
/// The three values are read-only from outside; [set] is the single mutation
/// point, so one user gesture is one notification even when it changes two
/// filters at once.
class AnalyticsFilters extends ChangeNotifier {
  Period _period = Period.d7;
  String? _topic;
  String? _team;

  Period get period => _period;

  /// `entitytopic` id, or null for every topic.
  String? get topic => _topic;

  /// Team id, or null for the whole scope the viewer can see.
  String? get team => _team;

  /// Last day of the window — today, inclusive.
  DateTime get to {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// First day of the window, inclusive. Built by calendar arithmetic rather
  /// than `subtract(Duration(days:))` so a DST change never shifts the day.
  DateTime get from {
    final t = to;
    return switch (_period) {
      Period.d7 => DateTime(t.year, t.month, t.day - 6),
      Period.d30 => DateTime(t.year, t.month, t.day - 29),
      Period.d90 => DateTime(t.year, t.month, t.day - 89),
      // Before launch day the pilot has not started: clamp to a one-day
      // window rather than handing every screen an inverted range.
      Period.pilot => kPilotStart.isAfter(t) ? t : kPilotStart,
    };
  }

  /// Calendar days in the window, inclusive of both ends — 7 for [Period.d7].
  /// Counted on the calendar rather than as `to.difference(from).inDays`,
  /// which is one short across a DST boundary.
  int get days =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays +
      1;

  /// Query string for every analytics endpoint. Unset filters are absent —
  /// the server reads a missing key as "all", never as an empty match.
  Map<String, String> get query => {
        'from': ymd(from),
        'to': ymd(to),
        'period': _period.name,
        'entitytopic': ?_topic,
        'team': ?_team,
      };

  /// Change one or more filters and notify once. Clearing is explicit
  /// (`clearTopic` / `clearTeam`) because a null argument means "leave it".
  void set({
    Period? period,
    String? topic,
    bool clearTopic = false,
    String? team,
    bool clearTeam = false,
  }) {
    final nextPeriod = period ?? _period;
    final nextTopic = clearTopic ? null : (topic ?? _topic);
    final nextTeam = clearTeam ? null : (team ?? _team);
    // Re-tapping the segment you are already on is not a filter change, and
    // must not refetch every screen listening here.
    if (nextPeriod == _period &&
        nextTopic == _topic &&
        nextTeam == _team) {
      return;
    }
    _period = nextPeriod;
    _topic = nextTopic;
    _team = nextTeam;
    notifyListeners();
  }
}

/// Where the content column is pointed: a section id, optionally a drill-down
/// entity, optionally the element an Iris citation asked us to pulse.
class ConsoleRoute {
  const ConsoleRoute(this.section,
      {this.entityId, this.highlight, this.stamp = 0});

  final String section;
  final String? entityId;
  final String? highlight;

  /// Which citation this is, counting from the start of the session. The
  /// highlight vocabulary is small (`stat`, `topic`, `iris`, ...), so two
  /// citations in a row often carry the same [highlight]; without a value
  /// that always changes, the second one would look like no change at all
  /// and its element would never pulse.
  final int stamp;
}

/// The console's router. Deliberately without value equality: navigating to
/// the view you are already on still has to fire, because that is how a
/// citation re-pulses its element.
class ConsoleNav extends ValueNotifier<ConsoleRoute> {
  ConsoleNav([super.value = const ConsoleRoute('resumen')]);

  int _stamp = 0;

  void go(String section, {String? entityId, String? highlight}) =>
      value = ConsoleRoute(section,
          entityId: entityId, highlight: highlight, stamp: ++_stamp);
}
