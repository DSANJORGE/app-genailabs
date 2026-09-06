import 'package:eme_app_package/eme_app_package.dart';
import 'package:flutter/foundation.dart';
import 'package:openinsitute_core/openinsitute_core.dart';

/// Web console session over eme_app_package. Same init as testu_live.dart,
/// minus the mobile-only pieces (lock screen, dart:io).
class AdminSession {
  /// Same-origin by default: the console is served from the plugin at
  /// /site/mediadb/admin/.
  static final String mediaDBRoot =
      const String.fromEnvironment('TESTU_MEDIADB').isNotEmpty
          ? const String.fromEnvironment('TESTU_MEDIADB')
          : kIsWeb
              ? '${Uri.base.origin}/site/mediadb'
              : 'http://localhost:8080/site/mediadb';

  static Future<void>? _ready;
  static Future<void> init() => _ready ??= () async {
        final ws = Workspace(
            id: 'primary', name: 'GenAILabs', mediaDBRoot: mediaDBRoot);
        await WorkspaceService.init(initialWorkspace: ws);
        // ponytail: WorkspaceService has no `select`; setActiveWorkspace is
        // the method that pins `activeWorkspace` (workspace_service.dart:158).
        // Forces this workspace even if a previous session left another one
        // selected -- one console per client, ignore any stored pick.
        await WorkspaceService.setActiveWorkspace(ws);
        await OpenI().initialize(workspaceData: ws.toJson());
        await AuthService.init();
      }();

  static Future<bool> restore() async {
    await init();
    return AuthService.isLoggedIn;
  }

  static Future<String> sendCode(String email) async {
    await init();
    try {
      return (await AuthService.sendUserCode(email: email))['status']
              ?.toString() ??
          'error';
    } catch (_) {
      return 'error';
    }
  }

  static Future<bool> login(String email, String code) async {
    await init();
    try {
      return await AuthService.loginWithOtp(email, code);
    } catch (_) {
      return false;
    }
  }

  static Future<void> signOut() => AuthService.logout();
}
