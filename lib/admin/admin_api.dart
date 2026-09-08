import 'dart:convert';

import 'package:dio/dio.dart' show MultipartFile;
import 'package:eme_app_package/eme_http.dart';

import '../testu/testu_social_api.dart';
import 'admin_models.dart';

/// AdminApi's mutators throw a bare Exception('msg'); strip the toString()
/// prefix before showing it. EmeHttpException never reaches callers of this
/// (they rethrow it before calling errText), so this only ever unwraps the
/// plain-Exception case.
String errText(Object e) {
  final s = e.toString();
  const prefix = 'Exception: ';
  return s.startsWith(prefix) ? s.substring(prefix.length) : s;
}

/// Thrown by [AdminApi.ask] when the tutor LLM is unavailable: either the
/// server answered non-2xx (surfaced as [EmeHttpException]) or answered 2xx
/// with `{ok:false}` (LLM failure, server-reported).
class AskUnavailable implements Exception {
  @override
  String toString() => 'AskUnavailable';
}

/// Typed client for the plugin's services/testu/* endpoints (admin console
/// only). Every call rides [EmeHttp] with the default [EmeAuth.token]
/// (Authorization: Bearer); 401/403 propagate as [EmeHttpException] and are
/// handled upstream by [AdminSession] (signs the console out), not here.
/// Every read is scoped server-side to what the signed-in user may see.
class AdminApi {
  AdminApi({EmeHttp? http}) : this._(http ?? DioEmeHttp());
  AdminApi._(this._http) : social = TestuSocialApi(http: _http);
  final EmeHttp _http;

  /// Threads and question reports on the same transport (Conversaciones).
  final TestuSocialApi social;

  Future<AdminMe> me() async =>
      AdminMe.fromJson(await _http.getJson('services/testu/personas/me.json'));

  /// The list key is read the way every model reads one (plan ruling R6): an
  /// endpoint with nothing to report answers `{ok:true}` and no list at all,
  /// and that is an empty roster, not a failed read.
  Future<List<AdminUser>> users() async => [
        for (final u in (await _http.getJson(
                'services/testu/personas/users.json'))['users'] as List? ??
            const [])
          AdminUser.fromJson(u),
      ];

  Future<List<AdminTeam>> teams() async => [
        for (final t in (await _http.getJson(
                'services/testu/personas/teams.json'))['teams'] as List? ??
            const [])
          AdminTeam.fromJson(t),
      ];

  Future<AdminReport> report({String? topic, String? team}) async {
    final j = await _http.getJson(
      'services/testu/analytics/report.json',
      query: {
        'entitytopic': ?topic,
        'team': ?team,
      },
    );
    return AdminReport(
      [for (final r in j['rows'] as List? ?? const []) MasteryRow(r)],
      ReportSummary.fromJson(j['summary'] as Map? ?? {}),
      {for (final t in (j['topics'] as List? ?? [])) '${t['id']}': '${t['name']}'},
    );
  }

  Future<Overview> overview(Map<String, String> q) async => Overview.fromJson(
      await _http.getJson('services/testu/analytics/overview.json', query: q));

  Future<Activity> activity(Map<String, String> q) async => Activity.fromJson(
      await _http.getJson('services/testu/analytics/activity.json', query: q));

  Future<PersonReport> person(String user, Map<String, String> q) async =>
      PersonReport.fromJson(await _http.getJson(
        'services/testu/analytics/person.json',
        query: {...q, 'user': user},
      ));

  /// Posts a tutor question for the ask panel. Throws [AskUnavailable] when
  /// the LLM is down, whether that surfaces as a non-2xx transport error or
  /// as a 2xx body with `ok != true`.
  Future<AskReply> ask({
    required String question,
    required String screen,
    String? user,
    List<Map<String, String>> history = const [],
    Map<String, String> q = const {},
  }) async {
    Map<String, dynamic> j;
    try {
      j = await _http.postForm('services/testu/analytics/ask.json', [
        ...q.entries,
        MapEntry('question', question),
        MapEntry('screen', screen),
        if (user != null) MapEntry('user', user),
        MapEntry('history', jsonEncode(history)),
      ]);
    } on EmeHttpException {
      throw AskUnavailable();
    }
    if (j['ok'] != true) throw AskUnavailable();
    return AskReply.fromJson(j);
  }

  Future<void> _post(String path, Map<String, String> fields) async {
    final j = await _http.postForm(path, fields.entries);
    if (j['ok'] != true) throw Exception('${j['error'] ?? 'error'}');
  }

  Future<void> createUser({
    required String email,
    required String firstName,
    required String lastName,
    String? team,
    String role = 'users',
  }) =>
      _post('services/testu/personas/createuser.json', {
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'team': team ?? '',
        'role': role,
      });

  Future<void> setRole(String userid, String role) =>
      _post('services/testu/personas/setrole.json', {'userid': userid, 'role': role});

  Future<void> setTeam(String userid, String? team) => _post(
      'services/testu/personas/setteam.json', {'userid': userid, 'team': team ?? ''});

  Future<void> disableUser(String userid) =>
      _post('services/testu/personas/disableuser.json', {'userid': userid});

  Future<void> saveTeam(AdminTeam t) => _post('services/testu/personas/saveteam.json', {
        'id': t.id,
        'name': t.name,
        'parent': t.parent ?? '',
        'manager': t.manager ?? '',
        'location': t.location ?? '',
        'costcenter': t.costcenter ?? '',
      });

  Future<void> recompute() => _post('services/testu/analytics/recompute.json', {});

  /// Multipart CSV upload; server field name is `file` (this plugin
  /// endpoint, not the generic EME asset-upload convention). Returns the
  /// imported row count.
  Future<int> importUsers(List<int> csvBytes) async {
    final j = await _http.post(
      'services/testu/personas/importusers.json',
      files: [
        MapEntry('file', MultipartFile.fromBytes(csvBytes, filename: 'users.csv')),
      ],
    );
    if (j['ok'] != true) throw Exception('${j['error'] ?? 'import failed'}');
    return (j['imported'] as num?)?.toInt() ?? 0;
  }
}
