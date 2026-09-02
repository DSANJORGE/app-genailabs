import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'testu_lock.dart';

/// Stub of eme_app_package's AuthService, mirroring its contract exactly so
/// the backend wiring session is a body swap:
///   sendUserCode  → AuthService.sendUserCode (status 'ok' | 'nouser')
///   loginWithOtp  → AuthService.loginWithOtp + loadWorkspaces
///   restoreSession → AuthService.init + isLoggedIn
/// ponytail: stub until the EME wiring lands — any email works, code 666666
/// (the fixed test OTP), emails starting with "new" exercise the
/// guest-registration branch.
class TestuAuth {
  static const _kEmail = 'testu_session_email';

  static String? email;

  /// Set by the app gate; fired after signOut so the UI returns to sign-in.
  static VoidCallback? onSessionEnded;

  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    email = prefs.getString(_kEmail);
    return email != null && email!.isNotEmpty;
  }

  /// Returns 'ok' (code sent) or 'nouser' (unknown email, guest
  /// registration allowed — resend with names).
  static Future<String> sendUserCode(
    String email, {
    String? firstName,
    String? lastName,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final unknown = email.split('@').first.toLowerCase().startsWith('new');
    return unknown && firstName == null ? 'nouser' : 'ok';
  }

  static Future<bool> loginWithOtp(String email, String code) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (code != '666666') return false;
    TestuAuth.email = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmail, email);
    return true;
  }

  static Future<void> signOut() async {
    email = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kEmail);
    // Biometric unlock belonged to the session that just ended — the next
    // person to sign in on this phone gets asked fresh.
    await TestuLock.reset();
    onSessionEnded?.call();
  }
}
