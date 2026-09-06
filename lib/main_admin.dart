import 'package:flutter/material.dart';
import 'admin/admin_session.dart';
import 'admin/admin_signin.dart';
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
    AdminSession.restore().then((v) => setState(() => _signedIn = v));
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
                : Scaffold(
                    body: Center(
                      child: TextButton(
                        onPressed: () async {
                          await AdminSession.signOut();
                          setState(() => _signedIn = false);
                        },
                        // Task 8 replaces this with AdminShell.
                        child: const Text('Signed in — shell comes in Task 8'),
                      ),
                    ),
                  ),
      );
}
