import 'package:eme_app_package/eme_http.dart' show EmeHttpException;
import 'package:flutter/material.dart';
import 'admin/admin_api.dart';
import 'admin/admin_models.dart';
import 'admin/admin_session.dart';
import 'admin/admin_shell.dart';
import 'admin/admin_signin.dart';
import 'testu/testu_i18n.dart';
import 'testu/testu_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});
  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  bool? _signedIn;

  @override
  void initState() {
    super.initState();
    AdminSession.onSignedOut = () {
      if (mounted) setState(() => _signedIn = false);
    };
    AdminSession.restore().then((v) {
      if (mounted) setState(() => _signedIn = v);
    }, onError: (_) {
      if (mounted) setState(() => _signedIn = false);
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GenAI Labs',
        theme: testuTheme(),
        debugShowCheckedModeBanner: false,
        home: _signedIn == null
            ? const Scaffold(body: SizedBox())
            : !_signedIn!
                ? AdminSignin(onSignedIn: () => setState(() => _signedIn = true))
                : _AdminHome(onSignOut: () async {
                    await AdminSession.signOut();
                    if (mounted) setState(() => _signedIn = false);
                  }),
      );
}

/// Loads [AdminMe] once signed in, then hands off to [AdminShell]. A 401/403
/// here throws [EmeHttpException] and also fires [AdminSession.onSignedOut]
/// (wired in [_AdminAppState.initState]) which already swaps the app back to
/// [AdminSignin] -- so that case renders nothing further itself. Any other
/// failure (network down, bad reply) shows a short message with a retry.
class _AdminHome extends StatefulWidget {
  const _AdminHome({required this.onSignOut});
  final VoidCallback onSignOut;
  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome> {
  final _api = AdminApi();
  late Future<AdminMe> _me;

  @override
  void initState() {
    super.initState();
    _me = _api.me();
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return FutureBuilder<AdminMe>(
      future: _me,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(backgroundColor: t.bg, body: const SizedBox());
        }
        if (snap.hasError) {
          if (snap.error is EmeHttpException) {
            // onSignedOut already fired; AdminApp is on its way back to
            // AdminSignin. Nothing useful to show in the meantime.
            return Scaffold(backgroundColor: t.bg, body: const SizedBox());
          }
          return Scaffold(
            backgroundColor: t.bg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    L('Could not load your account.', 'No se pudo cargar tu cuenta.'),
                    style: TextStyle(color: t.mut),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => _me = _api.me()),
                    child: Text(L('Retry', 'Reintentar')),
                  ),
                ],
              ),
            ),
          );
        }
        return AdminShell(me: snap.data!, api: _api, onSignOut: widget.onSignOut);
      },
    );
  }
}
