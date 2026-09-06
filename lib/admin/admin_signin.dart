import 'package:flutter/material.dart';
import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import '../testu/testu_widgets.dart';
import 'admin_session.dart';

/// Two-stage sign-in: email -> OTP code. Same eMe OTP flow as the mobile
/// TestU sign-in, restyled with the shared TestU tokens/widgets.
class AdminSignin extends StatefulWidget {
  const AdminSignin({super.key, required this.onSignedIn});
  final VoidCallback onSignedIn;
  @override
  State<AdminSignin> createState() => _AdminSigninState();
}

class _AdminSigninState extends State<AdminSignin> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  bool _codeStage = false, _busy = false;
  String? _error;

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = await AdminSession.sendCode(_email.text.trim());
    setState(() {
      _busy = false;
      _codeStage = s == 'ok';
      _error = s == 'ok'
          ? null
          : s == 'nouser'
              ? L('No account for that email. Ask your administrator.',
                  'No hay cuenta con ese correo. Habla con tu administrador.')
              : L('Could not send the code.', 'No se pudo enviar el código.');
    });
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AdminSession.login(_email.text.trim(), _code.text.trim());
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
                TestuEyebrow(
                    L('ADMIN CONSOLE', 'CONSOLA DE ADMINISTRACIÓN')),
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
                  Text(_error!, style: TextStyle(color: t.orange)),
                const SizedBox(height: 12),
                TestuButton(
                  _codeStage ? L('Enter', 'Entrar') : L('Send code', 'Enviar código'),
                  variant: TestuButtonVariant.primary,
                  onTap: _busy ? null : (_codeStage ? _verify : _send),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
