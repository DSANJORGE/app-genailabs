import 'package:eme_app_package/utils/error_handler.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'testu/testu_auth.dart';
import 'testu/testu_lock.dart';
import 'testu/testu_notifications.dart';
import 'testu/testu_profile.dart';
import 'testu/testu_shell.dart';
import 'testu/testu_signin.dart';
import 'testu/testu_splash.dart';
import 'testu/testu_theme.dart';
import 'testu/testu_usage.dart';
import 'testu/testu_web.dart';
import 'testu/testu_widgets.dart';

/// TestU Learn entrypoint — run with `flutter run -t lib/main_testu.dart`.
/// Keeps the TestU surface separate from the catalog app in main.dart.
/// True once Firebase (project `testu-learn`) is up; Crashlytics hooks are
/// installed by [AppErrorHandler] and Analytics collects its automatic events.
/// The app never depends on it: a bad config or no network just leaves it off.
bool _firebaseReady = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // Web: no Firebase project for the browser yet. initialize(null) still
    // installs the Flutter and platform error hooks; Crashlytics and
    // Analytics stay off (spec: testu-learn-web).
    await AppErrorHandler.initialize(
        kIsWeb ? null : DefaultFirebaseOptions.currentPlatform);
    _firebaseReady = !kIsWeb;
  } catch (e) {
    debugPrint('Firebase off: $e');
  }
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
  final _modals = TestuModalWatch();

  /// Long enough that answering a message or picking a photo doesn't make you
  /// re-authenticate; short enough that the phone left on a crew-room table
  /// is closed by the time someone else picks it up.
  static const _grace = Duration(seconds: 15);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    TestuAuth.onSessionEnded = () {
      clearTestuNotices();
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
    // A browser tab never reports `paused`: `hidden` is what it sends when
    // the tab is hidden or closing, so that is where web pauses; if the POST
    // is cut off by unload the event is still queued and ships on the next
    // open(). Mobile keeps `paused` only (see the note above about
    // `inactive`). Resume is asymmetric on web: a visible but unfocused tab
    // sits in `inactive`, so the clock restarts on focus.
    if (state == AppLifecycleState.paused ||
        (kIsWeb && state == AppLifecycleState.hidden)) {
      testuUsage.pause();
      stopTestuNoticePolling();
      _leftAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      testuUsage.resume();
      if (_signedIn) startTestuNoticePolling();
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
    stopTestuNoticePolling();
    super.dispose();
  }

  Future<void> _restore() async {
    // Both before the first frame decides anything: the lock setting picks
    // between the shell and the lock screen.
    await TestuLock.restore();
    final restored = await TestuAuth.restoreSession();
    // Only a signed-in session can post: events recorded while signed out
    // are rejected and would sit in the queue for nothing.
    if (restored) testuUsage.open();
    if (restored) startTestuNoticePolling();
    if (!mounted) return;
    setState(() {
      _checked = true;
      _signedIn = restored;
      _locked = restored && TestuLock.enabled;
      _welcomeBack = true;
      _reveal = restored;
    });
    // First frame on a phone-sized browser: point at the app, once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _nav.currentContext;
      if (c != null) maybeShowTestuWebNudge(c);
    });
  }

  void _onSignedIn() {
    // The restore path never ran for a fresh sign-in, so this is where the
    // session (and its foreground stopwatch) starts for a new learner.
    testuUsage.open();
    startTestuNoticePolling();
    setState(() {
      _signedIn = true;
      _welcomeBack = false;
      _reveal = true;
    });
  }

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
      // Desktop frame (spec: testu-learn-web): rail + 720px column around
      // every route. No rail during sign-in, the lock, or the launch intro.
      builder: (context, child) => TestuFrame(
        rail: _signedIn && !_locked && !_reveal,
        onTab: (i) {
          // A rail tap from a pushed screen (Topic Home, a session) lands
          // on the tab, not under it.
          _nav.currentState?.popUntil((r) => r.isFirst);
          TestuShell.tabRequest.value = i;
        },
        modal: _modals.modal,
        child: child!,
      ),
      // Screen views for named routes; the automatic events (first_open,
      // session_start, app_update) need nothing from here.
      navigatorObservers: [
        if (_firebaseReady)
          FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
        _modals,
      ],
      title: 'TestU Learn',
      debugShowCheckedModeBanner: false,
      theme: testuTheme(),
      home: home,
    );
  }
}
