/// Where the learner app is, as a browser address (spec:
/// minsur-pilot-readiness E2): `/hoy`, `/temas`, `/temas/<topicId>`,
/// `/iris`, `/dashboard`, plus `?q=<questionId>&c=<messageId>` for a thread
/// deep link. Pure Dart so the grammar is testable without a widget tree.
/// The shell (testu_shell.dart) turns one of these into screens; Part D's
/// notification tap builds one and hands it to `openLearnerRoute`.
class LearnerRoute {
  const LearnerRoute(this.tab, {this.topicId, this.questionId, this.messageId});

  /// Index into the shell's IndexedStack: 0 Hoy, 1 Temas, 2 Iris, 3 Dashboard.
  final int tab;

  /// eMe `entitytopic` — what TestuSessionScreen/TestuTopicHomeScreen key on.
  final String? topicId;
  final String? questionId;
  final String? messageId;

  /// Path segment per tab, in nav order.
  static const paths = ['hoy', 'temas', 'iris', 'dashboard'];

  Uri toUri() {
    final q = <String, String>{'q': ?questionId, 'c': ?messageId};
    return Uri(
      path: '/${paths[tab]}${topicId == null ? '' : '/$topicId'}',
      queryParameters: q.isEmpty ? null : q,
    );
  }

  /// Reads a route off the address the browser shows
  /// (`…/learn/#/temas/t1?q=q9`, the engine's default hash strategy) or off
  /// the bare path the engine hands back on browser Back (`/temas/t1?q=q9`).
  /// Null when the address names no tab.
  static LearnerRoute? fromUri(Uri uri) {
    final u = uri.hasFragment ? (Uri.tryParse(uri.fragment) ?? uri) : uri;
    final s = u.pathSegments.where((x) => x.isNotEmpty).toList();
    if (s.isEmpty) return null;
    final tab = paths.indexOf(s.first);
    if (tab < 0) return null;
    return LearnerRoute(
      tab,
      topicId: tab == 1 && s.length > 1 ? s[1] : null,
      questionId: u.queryParameters['q'],
      messageId: u.queryParameters['c'],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LearnerRoute && other.toUri() == toUri();

  @override
  int get hashCode => toUri().hashCode;

  @override
  String toString() => toUri().toString();
}
