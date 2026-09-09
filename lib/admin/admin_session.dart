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

  /// Fires when a 401/403 kills the session mid-use (eMe one-session-per-user
  /// rule). Task 8's shell must set this to drop back to the sign-in screen.
  static VoidCallback? onSignedOut;

  static Future<void>? _ready;
  static Future<void> init() => _ready ??= _boot().catchError((e) {
    // ponytail: a failed boot (e.g. server unreachable) shouldn't wedge
    // every later init() call forever -- let the next call retry.
    _ready = null;
    throw e;
  });

  static Future<void> _boot() async {
    final ws = Workspace(
      id: 'primary',
      name: 'GenAILabs',
      mediaDBRoot: mediaDBRoot,
    );
    await WorkspaceService.init(initialWorkspace: ws);
    // ponytail: WorkspaceService has no `select`; setActiveWorkspace is
    // the method that pins `activeWorkspace` (workspace_service.dart:158).
    // Forces this workspace even if a previous session left another one
    // selected -- one console per client, ignore any stored pick.
    await WorkspaceService.setActiveWorkspace(ws);
    await OpenI().initialize(workspaceData: ws.toJson());
    await AuthService.init();
    // Mirrors testu_live.dart:59-61: eMe keeps one token per user, so a
    // login elsewhere 403s every call here from then on -- drop to sign-in
    // instead of leaving the screen stuck showing stale data.
    EmeHttp.onUnauthorized = (e) {
      if (signsOut(e) && AuthService.isLoggedIn) {
        AuthService.logout();
        onSignedOut?.call();
      }
    };
  }

  /// Whether a 401/403 means the session is gone.
  ///
  /// One endpoint answers 403 for a reason that has nothing to do with the
  /// token: analytics/person.json refuses a learner outside the viewer's
  /// teams (person.groovy). Signing the console out there would drop a
  /// manager to the login screen for clicking a name in their own team list,
  /// so Persona words that reply itself and the session survives it.
  static bool signsOut(EmeHttpException e) =>
      !(e.statusCode == 403 && e.uri.path.endsWith('analytics/person.json'));

  static Future<bool> restore() async {
    await init();
    return AuthService.isLoggedIn;
  }

  /// `init()` is inside the try, not before it: a boot that throws (server
  /// unreachable on the very first call) used to escape both of these, and
  /// [AdminSignin] has nothing to catch it with -- the button stayed disabled
  /// with no message until someone reloaded the page. A failed boot is just
  /// another failed send.
  static Future<String> sendCode(String email) async {
    try {
      await init();
      return (await AuthService.sendUserCode(
            email: email,
          ))['status']?.toString() ??
          'error';
    } catch (_) {
      return 'error';
    }
  }

  static Future<bool> login(String email, String code) async {
    try {
      await init();
      return await AuthService.loginWithOtp(email, code);
    } catch (_) {
      return false;
    }
  }

  static Future<void> signOut() => AuthService.logout();
}
