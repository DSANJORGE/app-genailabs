import 'package:flutter/foundation.dart';

/// Console filter and navigation state — the two notifiers every analytics
/// screen listens to. Kept out of the widget files so a screen can be built
/// and tested without a shell around it.

/// The pilot's first day. Minsur launches 2026-09-14.
// ponytail: constant; a catalog setting when a second client exists.
final DateTime kPilotStart = DateTime(2026, 9, 14);

enum Period { d7, d30, d90, pilot }

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
      Period.pilot => kPilotStart,
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
        'from': _ymd(from),
        'to': _ymd(to),
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
    if (period != null) _period = period;
    if (clearTopic) {
      _topic = null;
    } else if (topic != null) {
      _topic = topic;
    }
    if (clearTeam) {
      _team = null;
    } else if (team != null) {
      _team = team;
    }
    notifyListeners();
  }

  static String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Where the content column is pointed: a section id, optionally a drill-down
/// entity, optionally the element an Iris citation asked us to pulse.
class ConsoleRoute {
  const ConsoleRoute(this.section, {this.entityId, this.highlight});

  final String section;
  final String? entityId;
  final String? highlight;
}

/// The console's router. Deliberately without value equality: navigating to
/// the view you are already on still has to fire, because that is how a
/// citation re-pulses its element.
class ConsoleNav extends ValueNotifier<ConsoleRoute> {
  ConsoleNav([super.value = const ConsoleRoute('resumen')]);

  void go(String section, {String? entityId, String? highlight}) =>
      value = ConsoleRoute(section, entityId: entityId, highlight: highlight);
}
