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

class _TestuAppState extends State<TestuApp> with WidgetsBindingObserver {
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

  /// When the app was last put away. Null while it's in the foreground.
  DateTime? _leftAt;
  final _nav = GlobalKey<NavigatorState>();

  /// Long enough that answering a message or picking a photo doesn't make you
  /// re-authenticate; short enough that the phone left on a crew-room table
  /// is closed by the time someone else picks it up.
  static const _grace = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TestuAuth.onSessionEnded = () {
      if (mounted) {
        // A session can end under a pushed screen (Topic Home, a session
        // sheet) when the server rejects the token; those must not stay
        // stacked over the sign-in screen.
        _nav.currentState?.popUntil((r) => r.isFirst);
        setState(() {
          _signedIn = false;
          _locked = false;
        });
      }
    };
    _restore();
  }

  /// "Every time they open the app" includes coming back to it, not just a
  /// cold start — a session left open on the home screen is the common case.
  /// Only `paused` counts: the Face ID prompt and the photo picker make the
  /// app `inactive`, and re-locking behind those would be a trap.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _leftAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _leftAt;
      _leftAt = null;
      if (away != null &&
          _signedIn &&
          TestuLock.enabled &&
          DateTime.now().difference(away) > _grace) {
        setState(() => _locked = true);
        // The lock screen is the app's root; anything pushed over it (a
        // session, Settings) would otherwise stay on top of it.
        _nav.currentState?.popUntil((r) => r.isFirst);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      navigatorKey: _nav,
      title: 'TestU Learn',
      debugShowCheckedModeBanner: false,
      theme: testuTheme(),
      home: home,
    );
  }
}
