import 'package:flutter/material.dart';
import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import '../testu/testu_widgets.dart';
import 'admin_session.dart';
import 'admin_theme.dart';
import 'admin_ui.dart';

/// Two-stage sign-in: email -> OTP code. Same eMe OTP flow as the mobile
/// TestU sign-in, restyled with the shared TestU tokens/widgets.
///
/// There is deliberately no sign-up and no password reset: console accounts
/// are provisioned by an administrator (TestU is sold to the organisation,
/// never to the seat), so the only two things this screen can offer are a
/// code and a way back out of a typo.
class AdminSignin extends StatefulWidget {
  const AdminSignin({
    super.key,
    required this.onSignedIn,
    this.sendCode = AdminSession.sendCode,
    this.login = AdminSession.login,
  });

  final VoidCallback onSignedIn;

  /// The two eMe calls, injectable so the screen's own states are testable
  /// without a workspace, a token and a live server behind them.
  final Future<String> Function(String email) sendCode;
  final Future<bool> Function(String email, String code) login;

  @override
  State<AdminSignin> createState() => _AdminSigninState();
}

class _AdminSigninState extends State<AdminSignin> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeStage = false, _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final resend = _codeStage;
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = await widget.sendCode(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      // A failed resend keeps the reader on the code stage: the code they
      // already have may still work, and dropping them back to the email
      // field would throw away the one they typed.
      _codeStage = s == 'ok' || resend;
      _error = s == 'ok'
          ? null
          : s == 'nouser'
              ? L('No account for that email. Ask your administrator.',
                  'No hay cuenta con ese correo. Habla con tu administrador.')
              : L('Could not send the code.', 'No se pudo enviar el código.');
    });
    // Nothing on screen changes when a second code is sent, so the screen
    // says it out loud -- a toast, not a SnackBar, which docks to the bottom
    // of the window and covers the form on a laptop.
    if (s == 'ok' && resend && mounted) {
      showToast(context, L('Code sent again.', 'Código reenviado.'));
    }
  }

  /// Back to the email stage — a typo in the address is otherwise a dead end
  /// that only a page reload gets out of.
  void _backToEmail() {
    setState(() {
      _codeStage = false;
      _error = null;
      _code.clear();
    });
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.login(_email.text.trim(), _code.text.trim());
    if (!mounted) return;
    if (ok) {
      widget.onSignedIn();
      return;
    }
    setState(() {
      _busy = false;
      _error = L('Wrong or expired code.', 'Código incorrecto o vencido.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The organisation cannot be named before sign-in (it comes
                // off the tutor persona in me.json), so the product names
                // itself instead.
                TestuEyebrow(
                    L('ADMIN CONSOLE', 'CONSOLA DE ADMINISTRACIÓN')),
                const SizedBox(height: 5),
                // kCaption's size and family; `mut` rather than its `faint`,
                // which lands at 3.9:1 on `bg`.
                Text('TestU Learn', style: kCaption.copyWith(color: t.mut)),
                const SizedBox(height: 16),
                if (!_codeStage)
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                        hintText: L('Work email', 'Correo de trabajo')),
                  )
                else
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    onSubmitted: (_) => _verify(),
                    decoration: InputDecoration(
                        hintText: L('6-digit code', 'Código de 6 dígitos')),
                  ),
                const SizedBox(height: 12),
                if (_error != null)
                  // Red, not the brand orange: orange means progress
                  // everywhere else in TestU. `AdminTokens.redText` is the
                  // app's text red -- the fill red misses 4.5:1 at this size.
                  Text(_error!,
                      style: TextStyle(color: AdminTokens.redText)),
                const SizedBox(height: 12),
                TestuButton(
                  _codeStage ? L('Enter', 'Entrar') : L('Send code', 'Enviar código'),
                  variant: TestuButtonVariant.primary,
                  onTap: _busy ? null : (_codeStage ? _verify : _send),
                ),
                if (_codeStage) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _quiet(L('Change email', 'Cambiar correo'),
                          _busy ? null : _backToEmail),
                      _quiet(L('Resend code', 'Reenviar código'),
                          _busy ? null : _send),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The two ways out of the code stage: quiet text, never a second CTA --
  /// the white button above is the only action this screen advertises.
  Widget _quiet(String label, VoidCallback? onTap) {
    final t = TestuTokens.of(context);
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: t.mut,
        disabledForegroundColor: t.faint,
        textStyle: const TextStyle(
            fontFamily: 'Geist', fontSize: 12, height: 1.2),
      ),
      child: Text(label),
    );
  }
}
