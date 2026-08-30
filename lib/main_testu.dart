import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu/testu_shell.dart';
import 'testu/testu_splash.dart';
import 'testu/testu_theme.dart';

/// TestU Learn entrypoint — run with `flutter run -t lib/main_testu.dart`.
/// Keeps the TestU surface separate from the catalog app in main.dart.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  bool _intro = true;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TestU Learn',
      debugShowCheckedModeBanner: false,
      theme: testuTheme(),
      home: Stack(children: [
        const TestuShell(),
        if (_intro)
          TestuSplash(onDone: () => setState(() => _intro = false)),
      ]),
    );
  }
}
