import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_auth.dart';
import 'testu_client.dart';
import 'testu_i18n.dart';
import 'testu_lock.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Client-neutral sign-in (spec: `testu-signin-flow` artifact). Two stages on
/// one screen — work email → 6-digit code — restyled from eme_app_package's
/// LoginScreen contract. No client branding, no Sully: the org isn't known
/// until the code verifies; the Vueling reveal plays after `onSignedIn`.
class TestuSignin extends StatefulWidget {
  const TestuSignin({super.key, required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  State<TestuSignin> createState() => _TestuSigninState();
}

class _TestuSigninState extends State<TestuSignin> {
  final _email = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();

  bool _otpStage = false;
  bool _registration = false;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _firstName.addListener(() => setState(() {}));
    _lastName.addListener(() => setState(() {}));
    _otp.addListener(_onOtpChanged);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _otp.dispose();
    _otpFocus.dispose();
    super.dispose();
  }

  bool get _emailValid =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_resendIn > 0) _resendIn--;
        if (_resendIn == 0) t.cancel();
      });
    });
  }

  Future<void> _sendCode({bool isResend = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final status = await TestuAuth.sendUserCode(
      _email.text.trim(),
      firstName: _registration ? _firstName.text.trim() : null,
      lastName: _registration ? _lastName.text.trim() : null,
    );
    if (!mounted) return;
    if (status == 'ok') {
      setState(() {
        _busy = false;
        _otpStage = true;
        _registration = false;
        _otp.clear();
      });
      _startResendTimer();
      // The OTP field mounts on the next frame; focus it once it exists.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _otpFocus.requestFocus();
      });
    } else if (status == 'nouser') {
      setState(() {
        _busy = false;
        _registration = true;
      });
    } else {
      setState(() {
        _busy = false;
        _error = L("We couldn't send the code. Try again.",
            'No pudimos enviar el código. Inténtalo de nuevo.');
      });
    }
  }

  void _onOtpChanged() {
    if (_otp.text.length == 6 && !_busy) {
      _verify();
    } else {
      setState(() {});
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await TestuAuth.loginWithOtp(_email.text.trim(), _otp.text);
    if (!mounted) return;
    if (ok) {
      _resendTimer?.cancel();
      // Offered here, before the handoff, so the Vueling reveal stays the
      // last beat of signing in. Once only — Settings owns it after that.
      if (TestuLock.available && !TestuLock.offered) {
        await TestuLock.markOffered();
        if (!mounted) return;
        await showTestuLockOffer(context);
        if (!mounted) return;
      }
      widget.onSignedIn();
    } else {
      setState(() {
        _busy = false;
        _error = L("That code didn't match. Try again.",
            'El código no coincide. Inténtalo de nuevo.');
        _otp.clear();
      });
      _otpFocus.requestFocus();
    }
  }

  void _backToEmail() {
    _resendTimer?.cancel();
    setState(() {
      _otpStage = false;
      _busy = false;
      _error = null;
      _otp.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 18, 26, 22),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: TestuTokens.curve,
            switchOutCurve: TestuTokens.curve,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.015),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: _otpStage
                ? _OtpStage(
                    key: const ValueKey('otp'),
                    state: this,
                    tokens: t,
                  )
                : _EmailStage(
                    key: const ValueKey('email'),
                    state: this,
                    tokens: t,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Shared field chrome: card fill, hairline border, ink focus ring.
InputDecoration _fieldDecoration(TestuTokens t, {String? hint}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Geist',
        fontSize: 15,
        color: t.faint,
      ),
      filled: true,
      fillColor: t.card,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.line2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.primaryAction),
      ),
    );

final _fieldStyle = TextStyle(
  fontFamily: 'Geist',
  fontSize: 15,
  color: TestuTokens.instance.ink,
);

class _EmailStage extends StatelessWidget {
  const _EmailStage({super.key, required this.state, required this.tokens});

  final _TestuSigninState state;
  final TestuTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final s = state;
    final canContinue = s._emailValid &&
        !s._busy &&
        (!s._registration ||
            (s._firstName.text.trim().isNotEmpty &&
                s._lastName.text.trim().isNotEmpty));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TestuEyebrow('TESTU LEARN'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 84),
                Text(L('Sign in', 'Inicia sesión'), style: kH1),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(
                    L("Use your work email. We'll send you a six-digit code — no password needed.",
                        'Usa tu correo de trabajo. Te enviaremos un código de seis dígitos: sin contraseña.'),
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 13.5,
                      height: 1.5,
                      color: t.mut,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                TestuEyebrow.h4(L('WORK EMAIL', 'CORREO DE TRABAJO')),
                const SizedBox(height: 8),
                TextField(
                  controller: s._email,
                  style: _fieldStyle,
                  decoration:
                      _fieldDecoration(t,
                          hint: 'ana.ruiz@${client.wordmark}.com'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    if (canContinue) s._sendCode();
                  },
                ),
                if (s._registration) ...[
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      L("You're new here — tell us your name and we'll set you up.",
                          'Eres ${G('nuevo', 'nueva')} aquí: dinos tu nombre y creamos tu cuenta.'),
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13,
                        height: 1.5,
                        color: t.mut,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TestuEyebrow.h4(L('FIRST NAME', 'NOMBRE')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: s._firstName,
                    style: _fieldStyle,
                    decoration: _fieldDecoration(t),
                  ),
                  const SizedBox(height: 14),
                  TestuEyebrow.h4(L('LAST NAME', 'APELLIDOS')),
                  const SizedBox(height: 8),
                  TextField(
                    controller: s._lastName,
                    style: _fieldStyle,
                    decoration: _fieldDecoration(t),
                  ),
                ],
                if (s._error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    s._error!,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12.5,
                      color: t.red,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        TestuButton(
          s._busy
              ? L('Sending…', 'Enviando…')
              : L('Continue', 'Continuar'),
          variant: TestuButtonVariant.primary,
          onTap: canContinue ? s._sendCode : null,
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            L('By continuing you accept the terms of your organisation.',
                'Al continuar aceptas los términos de tu organización.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 11,
              color: t.faint,
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpStage extends StatelessWidget {
  const _OtpStage({super.key, required this.state, required this.tokens});

  final _TestuSigninState state;
  final TestuTokens tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final s = state;
    final digits = s._otp.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TestuEyebrow('TESTU LEARN'),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 84),
                Text(L('Check your email', 'Revisa tu correo'), style: kH1),
                const SizedBox(height: 10),
                Text.rich(
                  TextSpan(
                    text: L('We sent a code to ', 'Enviamos un código a '),
                    children: [
                      TextSpan(
                        text: s._email.text.trim(),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: t.ink,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 13.5,
                    height: 1.5,
                    color: t.mut,
                  ),
                ),
                const SizedBox(height: 8),
                TestuPressable(
                  onTap: s._backToEmail,
                  child: Text(
                    L('Change email', 'Cambiar correo'),
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 13,
                      color: t.mut,
                      decoration: TextDecoration.underline,
                      decorationColor: t.faint,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                // Hidden input drives the six rendered boxes; tapping the row
                // refocuses it.
                GestureDetector(
                  onTap: s._otpFocus.requestFocus,
                  child: Stack(
                    children: [
                      Opacity(
                        opacity: 0,
                        child: TextField(
                          controller: s._otp,
                          focusNode: s._otpFocus,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          autofillHints: const [AutofillHints.oneTimeCode],
                          enableInteractiveSelection: false,
                          showCursor: false,
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < 6; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                height: 54,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: t.card,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: s._otpFocus.hasFocus &&
                                            i == digits.length
                                        ? t.primaryAction
                                        : t.line2,
                                  ),
                                ),
                                child: Text(
                                  i < digits.length ? digits[i] : '',
                                  style: TextStyle(
                                    fontFamily: 'GeistMono',
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: t.ink,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (s._error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    s._error!,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 12.5,
                      color: t.red,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (s._busy)
                  TestuEyebrow(L('VERIFYING…', 'VERIFICANDO…'), color: t.faint)
                else if (s._resendIn > 0)
                  TestuEyebrow(
                    L('RESEND CODE IN 0:${s._resendIn.toString().padLeft(2, '0')}',
                        'REENVIAR CÓDIGO EN 0:${s._resendIn.toString().padLeft(2, '0')}'),
                    color: t.faint,
                  )
                else
                  TestuPressable(
                    onTap: () => s._sendCode(isResend: true),
                    child: Text(
                      L('Resend code', 'Reenviar código'),
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 13,
                        color: t.ink,
                        decoration: TextDecoration.underline,
                        decorationColor: t.mut,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
