import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu/testu_auth.dart';
import 'testu/testu_lock.dart';
import 'testu/testu_profile.dart';
import 'testu/testu_shell.dart';
import 'testu/testu_signin.dart';
import 'testu/testu_splash.dart';
import 'testu/testu_theme.dart';
import 'testu/testu_widgets.dart';

/// TestU Learn entrypoint — run with `flutter run -t lib/main_testu.dart`.
/// Keeps the TestU surface separate from the catalog app in main.dart.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  restoreTestuAvatar();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
  ));
  runApp(const TestuApp());
}

class TestuApp extends StatefulWidget {
  const TestuApp({super.key});

  @override
  State<TestuApp> createState() => _TestuAppState();
}

class _TestuAppState extends State<TestuApp> {
  // Gate (spec: `testu-signin-flow` artifact): the app opens client-neutral;
  // the Vueling reveal plays only once the session says who the user is —
  // restored on launch, or fresh from the sign-in screen.
  bool _checked = false;
  bool _signedIn = false;
  bool _welcomeBack = true;
  bool _reveal = false;

  /// Session restored but the phone still has to recognise its owner
  /// (Settings › Security). Cleared by the lock screen.
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    TestuAuth.onSessionEnded = () {
      if (mounted) {
        setState(() {
          _signedIn = false;
          _locked = false;
        });
      }
    };
    _restore();
  }

  Future<void> _restore() async {
    // Both before the first frame decides anything: the lock setting picks
    // between the shell and the lock screen.
    await TestuLock.restore();
    final restored = await TestuAuth.restoreSession();
    if (!mounted) return;
    setState(() {
      _checked = true;
      _signedIn = restored;
      _locked = restored && TestuLock.enabled;
      _welcomeBack = true;
      _reveal = restored;
    });
  }

  void _onSignedIn() => setState(() {
        _signedIn = true;
        _welcomeBack = false;
        _reveal = true;
      });

  @override
  Widget build(BuildContext context) {
    final Widget home;
    if (!_checked) {
      // Sub-second session check — quiet TestU mark on black, no client brand.
      home = const Scaffold(
        backgroundColor: Color(0xFF0A0A0B),
        body: Center(child: TestuEyebrow('TESTU LEARN')),
      );
    } else if (!_signedIn) {
      home = TestuSignin(onSignedIn: _onSignedIn);
    } else if (_locked) {
      home = TestuLockScreen(onUnlocked: () => setState(() => _locked = false));
    } else {
      home = Stack(children: [
        const TestuShell(),
        if (_reveal)
          TestuSplash(
            welcomeBack: _welcomeBack,
            onDone: () => setState(() => _reveal = false),
          ),
      ]);
    }
    return MaterialApp(
      title: 'TestU Learn',
      debugShowCheckedModeBanner: false,
      theme: testuTheme(),
      home: home,
    );
  }
}
