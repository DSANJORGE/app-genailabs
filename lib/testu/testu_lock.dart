import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'testu_auth.dart';
import 'testu_i18n.dart';
import 'testu_icons.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Device unlock for an established session: once the email code has proved
/// who you are, Face ID / Touch ID reopens the app instead of a new code.
///
/// Not a WebAuthn passkey — that needs the backend to register a credential.
/// This is the on-device half, and it is what the UI promises: the biometric
/// never leaves the phone, and nothing about it is sent anywhere.
///
/// State is read once at startup so every screen can ask synchronously.
class TestuLock {
  static const _kOn = 'testu_lock_on';
  static const _kOffered = 'testu_lock_offered';

  static final _auth = LocalAuthentication();

  static bool _on = false;
  static bool _offered = false;
  static List<BiometricType> _kinds = const [];

  /// Unlock is switched on for this session.
  static bool get enabled => _on;

  /// The first-sign-in offer has already been shown (once per session, ever).
  static bool get offered => _offered;

  /// The device has an enrolled biometric this app may use.
  static bool get available => _kinds.isNotEmpty;

  /// What to call it on screen — Apple and Android name their own sensors,
  /// so the UI must too ("Unlock with biometrics" reads like a spec sheet).
  static String get name {
    if (_kinds.contains(BiometricType.face)) {
      return Platform.isIOS ? 'Face ID' : L('face unlock', 'desbloqueo facial');
    }
    if (_kinds.contains(BiometricType.fingerprint)) {
      return Platform.isIOS
          ? 'Touch ID'
          : L('your fingerprint', 'tu huella');
    }
    return L('your biometrics', 'tu biometría');
  }

  /// Reads the stored setting and asks the platform what it has enrolled.
  /// Call once at startup, before the app gate decides what to show.
  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    _on = prefs.getBool(_kOn) ?? false;
    _offered = prefs.getBool(_kOffered) ?? false;
    try {
      _kinds = await _auth.getAvailableBiometrics();
    } catch (_) {
      // No plugin (tests), no sensor, or permission refused — treat as
      // unavailable so the setting simply never offers itself.
      _kinds = const [];
    }
    // Enrolment can be removed after the fact (new phone, Face ID reset):
    // never leave the app locked behind a sensor that no longer exists.
    if (_on && _kinds.isEmpty) await setEnabled(false);
  }

  /// Runs the platform prompt. False = the user cancelled or didn't match;
  /// errors are swallowed the same way, since every caller treats "not
  /// authenticated" identically.
  static Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  /// Turning it ON verifies first — enabling a lock you can't open is the
  /// one way this feature can strand someone.
  static Future<bool> setEnabled(bool on) async {
    if (on &&
        !await authenticate(L('Confirm it\'s you to turn on ${TestuLock.name}',
            'Confirma que eres tú para activar ${TestuLock.name}'))) {
      return false;
    }
    _on = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOn, on);
    return true;
  }

  static Future<void> markOffered() async {
    _offered = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOffered, true);
  }

  /// Signing out hands the phone back to whoever signs in next: the setting
  /// belonged to the session that ended, and so does the offer.
  static Future<void> reset() async {
    _on = false;
    _offered = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kOn);
    await prefs.remove(_kOffered);
  }
}

/// Offered once, straight after the first successful code sign-in. Declining
/// is a real answer — the same switch waits in Settings.
Future<void> showTestuLockOffer(BuildContext context) {
  final t = TestuTokens.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    backgroundColor: t.card,
    barrierColor: const Color(0xA8000000),
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: t.line2),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      maxWidth: 640,
    ),
    builder: (_) => const _LockOfferSheet(),
  );
}

class _LockOfferSheet extends StatefulWidget {
  const _LockOfferSheet();

  @override
  State<_LockOfferSheet> createState() => _LockOfferSheetState();
}

class _LockOfferSheetState extends State<_LockOfferSheet> {
  bool _busy = false;
  bool _done = false;
  String? _error;

  Future<void> _turnOn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await TestuLock.setEnabled(true);
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = L(
            "${TestuLock.name} didn't confirm. You can try again, or set it "
                'up later in Settings.',
            '${TestuLock.name} no lo confirmó. Puedes intentarlo otra vez o '
                'configurarlo más tarde en Ajustes.');
      });
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _busy = false;
      _done = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: t.line2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (_done) ..._successChildren(t) else ..._offerChildren(t),
          ],
        ),
      ),
    );
  }

  List<Widget> _offerChildren(TestuTokens t) => [
        TestuEyebrow(L('SIGNED IN · ONE LAST THING',
            'SESIÓN INICIADA · UNA COSA MÁS')),
        const SizedBox(height: 14),
        TestuIcon(TestuGlyph.faceId, size: 34, color: t.ink),
        const SizedBox(height: 14),
        _Title(L('Open with ${TestuLock.name} next time?',
            '¿Abrir con ${TestuLock.name} la próxima vez?')),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            L('No six-digit code, no waiting for an email — TestU Learn '
                    'opens the moment it recognises you. ${TestuLock.name} '
                    'stays on this phone; TestU never sees it.',
                'Sin código de seis dígitos ni esperar un correo: TestU Learn '
                    'se abre en cuanto te reconoce. ${TestuLock.name} se queda '
                    'en este teléfono; TestU nunca lo ve.'),
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12.5,
              height: 1.65,
              color: t.mut,
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: t.red),
          ),
        ],
        const SizedBox(height: 18),
        TestuButton(
          _busy
              ? L('WAITING FOR ${TestuLock.name.toUpperCase()}…',
                  'ESPERANDO A ${TestuLock.name.toUpperCase()}…')
              : L('TURN ON ${TestuLock.name.toUpperCase()}',
                  'ACTIVAR ${TestuLock.name.toUpperCase()}'),
          variant: TestuButtonVariant.primary,
          onTap: _busy ? null : _turnOn,
        ),
        const SizedBox(height: 9),
        TestuButton(
          L('Not now', 'Ahora no'),
          onTap: _busy ? null : () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            L('You can turn this on or off any time in Settings.',
                'Puedes activarlo o desactivarlo cuando quieras en Ajustes.'),
            textAlign: TextAlign.center,
            style: kNote,
          ),
        ),
      ];

  List<Widget> _successChildren(TestuTokens t) => [
        SizedBox(
          width: double.infinity,
          child: Column(children: [
            const SizedBox(height: 8),
            const TestuCheckPulse(),
            const SizedBox(height: 16),
            _Title(L('${TestuLock.name} is on.', '${TestuLock.name} activado.')),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                L('Next time you open TestU Learn, it opens straight into '
                        'your day.',
                    'La próxima vez que abras TestU Learn, entrarás directo a '
                        'tu día.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12.5,
                  height: 1.65,
                  color: t.mut,
                ),
              ),
            ),
            const SizedBox(height: 18),
          ]),
        ),
      ];
}

/// App-open gate when unlock is on: client-neutral, like the sign-in screen —
/// the Vueling reveal is still the first branded beat, and it plays after.
class TestuLockScreen extends StatefulWidget {
  const TestuLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<TestuLockScreen> createState() => _TestuLockScreenState();
}

class _TestuLockScreenState extends State<TestuLockScreen> {
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Prompt on arrival: the whole point is that opening the app IS the
    // gesture. A failed or cancelled attempt falls back to the button.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await TestuLock.authenticate(
        L('Unlock TestU Learn', 'Desbloquea TestU Learn'));
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TestuEyebrow('TESTU LEARN'),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TestuIcon(TestuGlyph.faceId, size: 38, color: t.ink),
                        const SizedBox(height: 18),
                        Text(L('Welcome back', 'Bienvenida de nuevo'),
                            style: kH1),
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            _failed
                                ? L('${TestuLock.name} didn\'t match. Try '
                                        'again, or sign in with an emailed '
                                        'code.',
                                    '${TestuLock.name} no coincidió. '
                                        'Inténtalo otra vez o inicia sesión '
                                        'con un código por correo.')
                                : L('Look at your phone to open TestU Learn.',
                                    'Mira tu teléfono para abrir TestU Learn.'),
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 13.5,
                              height: 1.5,
                              color: _failed ? t.red : t.mut,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TestuButton(
                _busy
                    ? L('WAITING…', 'ESPERANDO…')
                    : L('UNLOCK WITH ${TestuLock.name.toUpperCase()}',
                        'DESBLOQUEAR CON ${TestuLock.name.toUpperCase()}'),
                variant: TestuButtonVariant.primary,
                onTap: _busy ? null : _unlock,
              ),
              const SizedBox(height: 12),
              Center(
                child: TestuPressable(
                  // The way out of a sensor that won't cooperate: end the
                  // session and go back to the email code.
                  onTap: _busy ? null : TestuAuth.signOut,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      L('Use an email code instead',
                          'Usar un código por correo'),
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13,
                        color: t.mut,
                        decoration: TextDecoration.underline,
                        decorationColor: t.faint,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sheet/screen title — Sora 700, matching the other sheets.
class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontFamily: 'Sora',
          fontWeight: FontWeight.w700,
          fontSize: 17,
          letterSpacing: -0.17,
          height: 1.3,
          color: TestuTokens.of(context).ink,
        ),
      );
}
