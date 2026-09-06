import 'package:dio/dio.dart' show MultipartFile;
import 'package:eme_app_package/eme_http.dart';

import 'admin_models.dart';

/// Typed client for the plugin's services/testu/* endpoints (admin console
/// only). Every call rides [EmeHttp] with the default [EmeAuth.token]
/// (Authorization: Bearer); 401/403 propagate as [EmeHttpException] and are
/// handled upstream by [AdminSession] (signs the console out), not here.
/// Every read is scoped server-side to what the signed-in user may see.
class AdminApi {
  AdminApi({EmeHttp? http}) : _http = http ?? DioEmeHttp();
  final EmeHttp _http;

  Future<AdminMe> me() async =>
      AdminMe.fromJson(await _http.getJson('services/testu/personas/me.json'));

  Future<List<AdminUser>> users() async => [
        for (final u
            in (await _http.getJson('services/testu/personas/users.json'))['users']
                as List)
          AdminUser.fromJson(u),
      ];

  Future<List<AdminTeam>> teams() async => [
        for (final t
            in (await _http.getJson('services/testu/personas/teams.json'))['teams']
                as List)
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
      [for (final r in j['rows'] as List) MasteryRow(r)],
      ReportSummary.fromJson(j['summary'] as Map? ?? {}),
      {for (final t in (j['topics'] as List? ?? [])) '${t['id']}': '${t['name']}'},
    );
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
