import 'dart:convert';

import 'package:eme_app_package/eme_http.dart';

import 'testu_i18n.dart';

/// Social threads and question reports: the plugin's services/testu/social/*
/// endpoints, one typed method each. Shared by the learner app (TestuThread)
/// and the console (Conversaciones); the console hands it its own http.
/// The server takes the user from the session, so nothing here says who.

/// App-wide reaction vocabulary (replaced TestuVote 2026-09-01). The names
/// are the wire format: react.json takes `name`, thread.json returns them.
enum TestuReaction { like, applause, support, love, idea, laugh }

TestuReaction? reactionOf(String name) =>
    TestuReaction.values.where((r) => r.name == name).firstOrNull;

/// Reaction counts from a wire `reacts` map; unknown names are dropped
/// rather than crashing the parse. Shared by [TestuComment.fromJson] and
/// [TestuSocialApi.react] so both follow the same rule.
Map<TestuReaction, int> _parseReacts(Map? j) {
  final reacts = <TestuReaction, int>{};
  for (final e in (j ?? const {}).entries) {
    final r = reactionOf('${e.key}');
    if (r != null) reacts[r] = (e.value as num?)?.toInt() ?? 0;
  }
  return reacts;
}

/// react.json's response: the server's resulting state for that reaction,
/// which may differ from the optimistic local guess (another reactor's
/// write can race this one).
typedef TestuReactResult = ({TestuReaction? mine, Map<TestuReaction, int> reacts});

/// The badge a `userprofile.settingsgroup` earns in a thread; learners wear
/// none. IRIS never posts in threads (out of scope), so there is no tutor badge live.
String? roleBadge(String role) => switch (role) {
      'training' => L('INSTRUCTOR', 'INSTRUCTOR'),
      'manager' => 'MANAGER',
      'orgadmin' => L('ADMIN', 'ADMIN'),
      _ => null,
    };

/// `questionflagreason` ids, in the order the report sheet lists them.
const testuFlagReasons = ['wrong', 'unclear', 'outdated', 'other'];

String flagReasonLabel(String id) => switch (id) {
      'wrong' => L('Incorrect', 'Incorrecta'),
      'unclear' => L('Confusing or badly worded', 'Confusa o mal redactada'),
      'outdated' => L('Outdated', 'Desactualizada'),
      _ => L('Other', 'Otro'),
    };

class TestuComment {
  TestuComment(this.who, this.role, this.avatar, this.text,
      {Map<TestuReaction, int>? reacts, this.id = '', this.userId = '', this.date})
      : reacts = reacts ?? {};

  /// Server id, author id and time; empty/null on the demo's mock rows.
  final String id;
  final String userId;
  final DateTime? date;
  final String who;
  final String? role; // badge, null = learner

  /// Asset path of a demo avatar; null draws initials (live has no photos).
  final String? avatar;
  final String text;
  final List<TestuComment> replies = [];
  final Map<TestuReaction, int> reacts;
  TestuReaction? myReact;
  bool reported = false;

  /// One `comments[]` row of thread.json, replies included. Unknown reaction
  /// names are dropped rather than crashing the parse.
  factory TestuComment.fromJson(Map j) {
    final reacts = _parseReacts(j['reacts'] as Map?);
    final c = TestuComment(
      '${j['name'] ?? j['userId'] ?? ''}',
      roleBadge('${j['role'] ?? 'users'}'),
      null,
      '${j['text'] ?? ''}',
      reacts: reacts,
      id: '${j['id'] ?? ''}',
      userId: '${j['userId'] ?? ''}',
      date: DateTime.tryParse('${j['date'] ?? ''}'),
    )..myReact = reactionOf('${j['mine'] ?? ''}');
    for (final r in (j['replies'] as List? ?? const [])) {
      c.replies.add(TestuComment.fromJson(r as Map));
    }
    return c;
  }
}

/// One entry of the `@` picker.
class Mentionable {
  Mentionable(this.id, this.name, this.role);
  final String id, name, role;

  factory Mentionable.fromJson(Map j) => Mentionable(
      '${j['id'] ?? ''}', '${j['name'] ?? j['id'] ?? ''}', '${j['role'] ?? 'users'}');
}

/// One row of the console's recent list (thread.json without a channel).
class RecentComment {
  RecentComment({
    required this.id,
    required this.channel,
    required this.label,
    required this.who,
    required this.role,
    required this.text,
    this.date,
    this.replyToId,
  });
  final String id, channel, label, who, role, text;
  final DateTime? date;
  final String? replyToId;

  factory RecentComment.fromJson(Map j) => RecentComment(
        id: '${j['id'] ?? ''}',
        channel: '${j['channel'] ?? ''}',
        label: '${j['label'] ?? j['entityid'] ?? ''}',
        who: '${j['name'] ?? j['userId'] ?? ''}',
        role: '${j['role'] ?? 'users'}',
        text: '${j['text'] ?? ''}',
        date: DateTime.tryParse('${j['date'] ?? ''}'),
        replyToId: j['replytoid']?.toString(),
      );
}

/// One open question report, for the console.
class QuestionFlagRow {
  QuestionFlagRow({
    required this.id,
    required this.questionId,
    required this.label,
    required this.reason,
    required this.note,
    required this.who,
    this.date,
  });
  final String id, questionId, label, reason, note, who;
  final DateTime? date;

  factory QuestionFlagRow.fromJson(Map j) => QuestionFlagRow(
        id: '${j['id'] ?? ''}',
        questionId: '${j['entityquestion'] ?? ''}',
        label: '${j['label'] ?? j['entityquestion'] ?? ''}',
        reason: '${j['reason'] ?? 'other'}',
        note: '${j['note'] ?? ''}',
        who: '${j['name'] ?? j['userId'] ?? ''}',
        date: DateTime.tryParse('${j['date'] ?? ''}'),
      );
}

class SocialRecent {
  SocialRecent(this.comments, this.flags);
  final List<RecentComment> comments;
  final List<QuestionFlagRow> flags;
}

class TestuSocialApi {
  TestuSocialApi({EmeHttp? http}) : _http = http ?? DioEmeHttp();
  final EmeHttp _http;
  static const _base = 'services/testu/social/';

  /// Every endpoint answers `{ok:true,...}` or `{ok:false,error}` with a
  /// non-2xx status; the transport already throws on the status, this
  /// catches a 2xx that still says no.
  Map<String, dynamic> _ok(Map<String, dynamic> j) {
    if (j['ok'] != true) throw Exception('${j['error'] ?? 'error'}');
    return j;
  }

  Future<List<TestuComment>> thread(String channel) async {
    final j = _ok(await _http.getJson('${_base}thread.json', query: {'channel': channel}));
    return [for (final c in j['comments'] as List? ?? const []) TestuComment.fromJson(c as Map)];
  }

  /// Returns the new comment's id. [mentions] are user ids from
  /// [mentionables]; the server parses nothing out of [text].
  Future<String> comment({
    required String channel,
    required String text,
    String? replyToId,
    List<String> mentions = const [],
  }) async {
    final j = _ok(await _http.postForm('${_base}comment.json', [
      MapEntry('channel', channel),
      MapEntry('message', text),
      if (replyToId != null) MapEntry('replytoid', replyToId),
      MapEntry('mentions', jsonEncode(mentions)),
    ]));
    return '${j['id'] ?? ''}';
  }

  /// Sets my reaction on [messageId]; null clears it. Returns the server's
  /// resulting mine/reacts so the caller can resync instead of trusting the
  /// optimistic local update.
  Future<TestuReactResult> react(String messageId, TestuReaction? r) async {
    final j = _ok(await _http.postForm('${_base}react.json', [
      MapEntry('messageid', messageId),
      MapEntry('name', r?.name ?? ''),
    ]));
    return (mine: reactionOf('${j['mine'] ?? ''}'), reacts: _parseReacts(j['reacts'] as Map?));
  }

  Future<List<Mentionable>> mentionables() async {
    final j = _ok(await _http.getJson('${_base}mentionables.json'));
    return [for (final p in j['people'] as List? ?? const []) Mentionable.fromJson(p as Map)];
  }

  /// The console's listing: newest comments and open flags in my scope.
  Future<SocialRecent> recent() async {
    final j = _ok(await _http.getJson('${_base}thread.json'));
    return SocialRecent(
      [for (final c in j['recent'] as List? ?? const []) RecentComment.fromJson(c as Map)],
      [for (final f in j['flags'] as List? ?? const []) QuestionFlagRow.fromJson(f as Map)],
    );
  }

  Future<void> flag({
    required String questionId,
    String? tutorialId,
    required String reason,
    String? note,
  }) async {
    _ok(await _http.postForm('${_base}flag.json', [
      MapEntry('entityquestion', questionId),
      if (tutorialId != null) MapEntry('entitytutorial', tutorialId),
      MapEntry('reason', reason),
      if (note != null) MapEntry('note', note),
    ]));
  }
}

/// The app's single social client. Lazily built (top-level finals are), so
/// it never runs before Dio is up -- same rule as [testuUsage].
final testuSocial = TestuSocialApi();
