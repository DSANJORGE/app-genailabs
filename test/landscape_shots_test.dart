@Tags(['shots'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_i18n.dart';
import 'package:genai_labs/testu/testu_lock.dart';
import 'package:genai_labs/testu/testu_notifications.dart';
import 'package:genai_labs/testu/testu_pdf.dart';
import 'package:genai_labs/testu/testu_profile.dart';
import 'package:genai_labs/testu/testu_question_source.dart';
import 'package:genai_labs/testu/testu_report_sheet.dart';
import 'package:genai_labs/testu/testu_resources.dart';
import 'package:genai_labs/testu/testu_schedule_sheet.dart';
import 'package:genai_labs/testu/testu_session.dart';
import 'package:genai_labs/testu/testu_session_engine.dart';
import 'package:genai_labs/testu/testu_shell.dart';
import 'package:genai_labs/testu/testu_signin.dart';
import 'package:genai_labs/testu/testu_social.dart';
import 'package:genai_labs/testu/testu_splash.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:genai_labs/testu/testu_topics.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Screenshot rig, not a regression suite: renders every TestU surface at
/// landscape 874×402 with the real fonts/assets and writes PNGs to
/// test/landscape_shots/. Simulators can't be rotated headlessly, so this is
/// how landscape gets eyeballed. Skipped in normal runs (dart_test.yaml tag);
/// capture with:
///   flutter test --update-goldens --run-skipped test/landscape_shots_test.dart
/// The `session` test reports a pending-timer failure AFTER its shot is
/// written (a long-lived Sully timer) — harmless here.

/// Reports a face-enrolled device so the lock surfaces render their real copy.
class _FakeLocalAuth extends LocalAuthPlatform {
  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      false; // never auto-dismiss the screen mid-shot
  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async =>
      const [BiometricType.face];
  @override
  Future<bool> deviceSupportsBiometrics() async => true;
  @override
  Future<bool> isDeviceSupported() async => true;
}

class _FakeVideoPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<int?> create(DataSource dataSource) async => 1;
  @override
  Future<void> dispose(int textureId) async {}
  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream.empty();
  @override
  Future<void> setLooping(int textureId, bool looping) async {}
  @override
  Future<void> setVolume(int textureId, double volume) async {}
}

Future<void> _loadFonts() async {
  const fonts = {
    'Sora': ['Sora-Regular.ttf', 'Sora-Bold.ttf', 'Sora-ExtraBold.ttf'],
    'Geist': [
      'Geist-Regular.ttf',
      'Geist-Medium.ttf',
      'Geist-SemiBold.ttf',
      'Geist-Bold.ttf'
    ],
    'GeistMono': ['GeistMono-Regular.ttf', 'GeistMono-Medium.ttf'],
  };
  for (final e in fonts.entries) {
    final loader = FontLoader(e.key);
    for (final f in e.value) {
      loader.addFont(rootBundle.load('assets/fonts/$f'));
    }
    await loader.load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  VideoPlayerPlatform.instance = _FakeVideoPlatform();
  SharedPreferences.setMockInitialValues({});
  setUpAll(_loadFonts);

  void landscape(WidgetTester tester) {
    tester.view.physicalSize = const Size(874, 402);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  void portrait(WidgetTester tester) {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> settleAndPrecache(WidgetTester tester,
      {int seconds = 4}) async {
    for (var i = 0; i < seconds * 2; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate().toList()) {
        try {
          await precacheImage((e.widget as Image).image, e);
        } catch (_) {}
      }
    });
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> shot(WidgetTester tester, String name) => expectLater(
      find.byType(MaterialApp).first,
      matchesGoldenFile('landscape_shots/$name.png'));

  Future<void> pumpApp(WidgetTester tester, Widget home) => tester.pumpWidget(
      MaterialApp(
          debugShowCheckedModeBanner: false, theme: testuTheme(), home: home));

  Future<void> openSheet(
      WidgetTester tester, void Function(BuildContext) open) async {
    await pumpApp(
        tester,
        Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => open(context),
                    child: const Text('go')))));
    await tester.tap(find.text('go'));
    await settleAndPrecache(tester);
  }

  testWidgets('splash', (tester) async {
    landscape(tester);
    await pumpApp(tester, TestuSplash(onDone: () {}));
    await tester.pump(const Duration(milliseconds: 1500));
    await shot(tester, 'splash');
    await tester.pump(const Duration(seconds: 6)); // let the timeline finish
  });

  testWidgets('shell today', (tester) async {
    landscape(tester);
    await pumpApp(tester, const TestuShell());
    await settleAndPrecache(tester);
    await shot(tester, 'shell_today');
  });

  testWidgets('shell topics', (tester) async {
    landscape(tester);
    await pumpApp(tester, const TestuShell());
    await tester.tap(find.text('TOPICS'));
    await settleAndPrecache(tester);
    await shot(tester, 'shell_topics');
  });

  testWidgets('shell sully', (tester) async {
    landscape(tester);
    await pumpApp(tester, const TestuShell());
    await tester.tap(find.text('SULLY'));
    await settleAndPrecache(tester, seconds: 6);
    await shot(tester, 'shell_sully');
  });

  testWidgets('shell dashboard', (tester) async {
    landscape(tester);
    await pumpApp(tester, const TestuShell());
    await tester.tap(find.text('DASHBOARD'));
    await settleAndPrecache(tester);
    await shot(tester, 'shell_dashboard');
  });

  testWidgets('topic home', (tester) async {
    landscape(tester);
    await pumpApp(tester, const TestuTopicHomeScreen());
    await settleAndPrecache(tester);
    await shot(tester, 'topic_home');
  });

  testWidgets('session', (tester) async {
    landscape(tester);
    await pumpApp(tester, TestuSessionScreen(source: LocalQuestionSource()));
    await settleAndPrecache(tester, seconds: 8);
    await shot(tester, 'session');
    await tester.pump(const Duration(seconds: 8));
  });

  testWidgets('debrief', (tester) async {
    landscape(tester);
    final qs = await LocalQuestionSource().load();
    await pumpApp(
        tester,
        TestuDebriefScreen(
          questions: qs,
          topic: LocalQuestionSource().topic,
          outcome: const SessionOutcome(completed: true, attempts: [
            Attempt(
                qi: 0, chosen: 1, confidence: 3, correct: true, assisted: false),
            Attempt(
                qi: 1, chosen: 0, confidence: 1, correct: true, assisted: true),
            Attempt(
                qi: 2, chosen: 2, confidence: 3, correct: false, assisted: false),
          ]),
        ));
    await settleAndPrecache(tester);
    await shot(tester, 'debrief');
  });

  testWidgets('notifications', (tester) async {
    landscape(tester);
    await pumpApp(tester, const TestuNotificationsScreen());
    await settleAndPrecache(tester);
    await shot(tester, 'notifications');
  });

  testWidgets('profile', (tester) async {
    landscape(tester);
    await pumpApp(tester, const TestuProfileScreen());
    await settleAndPrecache(tester);
    await shot(tester, 'profile');
  });

  testWidgets('sheet video', (tester) async {
    landscape(tester);
    await openSheet(tester, (c) => showTestuResource(c, 'vid'));
    await shot(tester, 'sheet_video');
  });

  testWidgets('sheet pdf', (tester) async {
    landscape(tester);
    await openSheet(tester, (c) => showTestuPdf(c, page: 6));
    await shot(tester, 'sheet_pdf');
  });

  testWidgets('sheet schedule', (tester) async {
    landscape(tester);
    await openSheet(tester, (c) => showTestuScheduleSheet(c, onScheduled: (_) {}));
    await shot(tester, 'sheet_schedule');
  });

  testWidgets('sheet report', (tester) async {
    landscape(tester);
    await openSheet(
        tester,
        (c) => showTestuReportSheet(c,
            eyebrow: 'REPORT',
            title: 'Report this question',
            subtitle: 'Ramp Safety · Q4',
            reasons: const ['Wrong answer marked', 'Outdated', 'Confusing'],
            onSend: (reason, note) {}));
    await shot(tester, 'sheet_report');
  });

  testWidgets('lock screen', (tester) async {
    landscape(tester);
    LocalAuthPlatform.instance = _FakeLocalAuth();
    await TestuLock.restore();
    await pumpApp(tester, TestuLockScreen(onUnlocked: () {}));
    await settleAndPrecache(tester);
    await shot(tester, 'lock_screen');
  });

  testWidgets('sheet lock offer', (tester) async {
    landscape(tester);
    LocalAuthPlatform.instance = _FakeLocalAuth();
    await TestuLock.restore();
    await openSheet(tester, showTestuLockOffer);
    await shot(tester, 'sheet_lock_offer');
  });

  // Portrait shots for the surfaces the phone is actually held for.
  testWidgets('portrait profile', (tester) async {
    portrait(tester);
    LocalAuthPlatform.instance = _FakeLocalAuth();
    await TestuLock.restore();
    await pumpApp(tester, const TestuProfileScreen());
    await settleAndPrecache(tester);
    await shot(tester, 'portrait_profile');
  });

  testWidgets('portrait profile with added photos', (tester) async {
    portrait(tester);
    LocalAuthPlatform.instance = _FakeLocalAuth();
    await TestuLock.restore();
    // The state where remove badges show. Asset paths stand in for picked
    // files: the tile renders whatever the library holds, and precaching a
    // real FileImage inside runAsync never returns under the test binding.
    testuAvatarLibrary.value = const [
      'assets/img/p_jordi.jpg',
      'assets/img/p_karsten.jpg',
    ];
    addTearDown(() => testuAvatarLibrary.value = const []);
    await pumpApp(tester, const TestuProfileScreen());
    await settleAndPrecache(tester);
    await shot(tester, 'portrait_profile_photos');
  });

  testWidgets('portrait lock screen', (tester) async {
    portrait(tester);
    LocalAuthPlatform.instance = _FakeLocalAuth();
    await TestuLock.restore();
    await pumpApp(tester, TestuLockScreen(onUnlocked: () {}));
    await settleAndPrecache(tester);
    await shot(tester, 'portrait_lock_screen');
  });

  testWidgets('portrait lock offer', (tester) async {
    portrait(tester);
    LocalAuthPlatform.instance = _FakeLocalAuth();
    await TestuLock.restore();
    await openSheet(tester, showTestuLockOffer);
    await shot(tester, 'portrait_sheet_lock_offer');
  });

  testWidgets('sheet reactions', (tester) async {
    landscape(tester);
    await openSheet(
        tester,
        (c) => showTestuReactionsSheet(c, reacts: const {
              TestuReaction.like: 4,
              TestuReaction.applause: 2,
              TestuReaction.love: 1,
            }));
    await shot(tester, 'sheet_reactions');
  });

  // Every surface in portrait, in Spanish — the phone as the demo holds it.
  // Added for the 2026-09-07 homogenisation pass; PNGs land as p_*.png.
  group('portrait es', () {
    setUp(() {
      testuLang.value = 'es';
      LocalAuthPlatform.instance = _FakeLocalAuth();
    });
    tearDownAll(() => testuLang.value = 'en');

    Future<void> tab(WidgetTester tester, String label, String name,
        {int seconds = 4}) async {
      portrait(tester);
      await pumpApp(tester, const TestuShell());
      if (label.isNotEmpty) await tester.tap(find.text(label));
      await settleAndPrecache(tester, seconds: seconds);
      await shot(tester, name);
    }

    testWidgets('today', (t) => tab(t, '', 'p_today'));
    testWidgets('topics', (t) => tab(t, 'TEMAS', 'p_topics'));
    testWidgets('tutor', (t) => tab(t, 'IRIS', 'p_tutor', seconds: 6));
    testWidgets('dashboard', (t) => tab(t, 'DASHBOARD', 'p_dashboard'));

    testWidgets('signin', (tester) async {
      portrait(tester);
      await pumpApp(tester, TestuSignin(onSignedIn: () {}));
      await settleAndPrecache(tester);
      await shot(tester, 'p_signin');
    });

    testWidgets('topic home', (tester) async {
      portrait(tester);
      await pumpApp(tester, const TestuTopicHomeScreen());
      await settleAndPrecache(tester);
      await shot(tester, 'p_topic_home');
      await tester.tap(find.text('Subtemas'));
      await settleAndPrecache(tester, seconds: 1);
      await shot(tester, 'p_topic_subtopics');
      await tester.tap(find.text('Recursos'));
      await settleAndPrecache(tester, seconds: 1);
      await shot(tester, 'p_topic_resources');
      await tester.tap(find.text('Reseñas'));
      await settleAndPrecache(tester, seconds: 1);
      await shot(tester, 'p_topic_review');
    });

    testWidgets('session', (tester) async {
      portrait(tester);
      await pumpApp(tester, TestuSessionScreen(source: LocalQuestionSource()));
      await settleAndPrecache(tester, seconds: 8);
      await shot(tester, 'p_session');
      await tester.pump(const Duration(seconds: 8));
    });

    testWidgets('debrief', (tester) async {
      portrait(tester);
      final qs = await LocalQuestionSource().load();
      await pumpApp(
          tester,
          TestuDebriefScreen(
            questions: qs,
            topic: LocalQuestionSource().topic,
            outcome: const SessionOutcome(completed: true, attempts: [
              Attempt(
                  qi: 0, chosen: 1, confidence: 3, correct: true, assisted: false),
              Attempt(
                  qi: 1, chosen: 0, confidence: 1, correct: true, assisted: true),
              Attempt(
                  qi: 2, chosen: 2, confidence: 3, correct: false, assisted: false),
            ]),
          ));
      await settleAndPrecache(tester);
      await shot(tester, 'p_debrief');
    });

    testWidgets('notifications', (tester) async {
      portrait(tester);
      await pumpApp(tester, const TestuNotificationsScreen());
      await settleAndPrecache(tester);
      await shot(tester, 'p_notifications');
    });

    testWidgets('profile', (tester) async {
      portrait(tester);
      await TestuLock.restore();
      await pumpApp(tester, const TestuProfileScreen());
      await settleAndPrecache(tester);
      await shot(tester, 'p_profile');
      // The language picker sheet (was a Material dropdown).
      await tester.tap(find.text('Español'));
      await settleAndPrecache(tester, seconds: 1);
      await shot(tester, 'p_profile_language');
    });

    testWidgets('sheets', (tester) async {
      portrait(tester);
      await openSheet(tester, (c) => showTestuResource(c, 'vid'));
      await shot(tester, 'p_sheet_video');
    });
    testWidgets('sheet pdf', (tester) async {
      portrait(tester);
      await openSheet(tester, (c) => showTestuPdf(c, page: 6));
      await shot(tester, 'p_sheet_pdf');
    });
    testWidgets('sheet schedule', (tester) async {
      portrait(tester);
      await openSheet(
          tester, (c) => showTestuScheduleSheet(c, onScheduled: (_) {}));
      await shot(tester, 'p_sheet_schedule');
    });
    testWidgets('sheet report', (tester) async {
      portrait(tester);
      await openSheet(
          tester,
          (c) => showTestuReportSheet(c,
              eyebrow: 'PREGUNTA · REPORTAR',
              title: 'Reportar esta pregunta',
              subtitle: 'Llega al equipo de contenido para su revisión.',
              reasons: const ['Incorrecta', 'Confusa', 'Errata', 'Otro'],
              onSend: (reason, note) {}));
      await shot(tester, 'p_sheet_report');
    });
    testWidgets('sheet reactions', (tester) async {
      portrait(tester);
      await openSheet(
          tester,
          (c) => showTestuReactionsSheet(c, reacts: const {
                TestuReaction.like: 4,
                TestuReaction.applause: 2,
                TestuReaction.love: 1,
              }));
      await shot(tester, 'p_sheet_reactions');
    });
    testWidgets('sheet lock offer', (tester) async {
      portrait(tester);
      await TestuLock.restore();
      await openSheet(tester, showTestuLockOffer);
      await shot(tester, 'p_sheet_lock_offer');
    });
  });
}
