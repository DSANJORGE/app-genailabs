import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'testu_live.dart';
import 'testu_lock.dart';

/// The app's one auth seam. Two bodies behind the same four calls: the
/// offline demo (any email works, code 666666, emails starting with "new"
/// exercise the guest-registration branch) or, under `TESTU_LIVE`,
/// eme_app_package's AuthService via testu_live.dart. The sign-in screen
/// and the app gate never know which.
class TestuAuth {
  static const _kEmail = 'testu_session_email';

  /// Set by the app gate; fired after signOut so the UI returns to sign-in.
  static VoidCallback? onSessionEnded;

  static Future<bool> restoreSession() async {
    if (testuLive) return liveRestoreSession();
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString(_kEmail) ?? '').isNotEmpty;
  }

  /// 'ok' (code sent), 'nouser' (unknown email, guest registration allowed —
  /// resend with names) or 'error'.
  static Future<String> sendUserCode(
    String email, {
    String? firstName,
    String? lastName,
  }) async {
    if (testuLive) {
      return liveSendUserCode(email, firstName: firstName, lastName: lastName);
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final unknown = email.split('@').first.toLowerCase().startsWith('new');
    return unknown && firstName == null ? 'nouser' : 'ok';
  }

  static Future<bool> loginWithOtp(String email, String code) async {
    if (testuLive) return liveLoginWithOtp(email, code);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (code != '666666') return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmail, email);
    return true;
  }

  static Future<void> signOut() async {
    if (testuLive) {
      await liveSignOut();
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kEmail);
    }
    // Biometric unlock belonged to the session that just ended — the next
    // person to sign in on this phone gets asked fresh.
    await TestuLock.reset();
    onSessionEnded?.call();
  }
}
