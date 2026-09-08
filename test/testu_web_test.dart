import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_notifications.dart';
import 'package:genai_labs/testu/testu_pdf.dart';
import 'package:genai_labs/testu/testu_route.dart';
import 'package:genai_labs/testu/testu_resources.dart';
import 'package:genai_labs/testu/testu_schedule_sheet.dart';
import 'package:genai_labs/testu/testu_shell.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:genai_labs/testu/testu_web.dart';
import 'package:genai_labs/testu/testu_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// The browser build's desktop frame (spec: testu-learn-web). A desktop
/// window (1280×800) gets sheets as centred dialogs; a phone window
/// (390×844) stays the phone app. flutter_test fails on any RenderFlex
/// overflow, so pumping each real sheet at desktop size IS the assertion.

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

const desktop = Size(1280, 800);
const phone = Size(390, 844);

void window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> openAt(WidgetTester tester, Size size,
    void Function(BuildContext) open) async {
  window(tester, size);
  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: Scaffold(
      body: Builder(
        builder: (context) =>
            TextButton(onPressed: () => open(context), child: const Text('go')),
      ),
    ),
  ));
  await tester.tap(find.text('go'));
  await tester.pump(const Duration(seconds: 1)); // open animation
  await tester.pump(const Duration(seconds: 2)); // Sully typing settles
}

void main() {
  VideoPlayerPlatform.instance = _FakeVideoPlatform();
  // The frame only exists in the browser build; the VM pretends to be one.
  setUp(() => testuDesktop = true);
  tearDown(() => testuDesktop = false);

  Widget body(BuildContext _) => const Column(
        mainAxisSize: MainAxisSize.min,
        children: [TestuGrabber(), Text('body')],
      );

  group('sheets', () {
    testWidgets('a desktop window shows a sheet as a centred dialog',
        (tester) async {
      await openAt(tester, desktop, (c) => showTestuSheet<void>(c, builder: body));
      expect(find.byType(Dialog), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('body'), findsOneWidget);
      // The grabber is a bottom-sheet affordance: on wide it is just the
      // sheet's top padding.
      expect(tester.getSize(find.byType(TestuGrabber)).height, 16);
    });

    testWidgets('a phone window keeps the bottom sheet', (tester) async {
      await openAt(tester, phone, (c) => showTestuSheet<void>(c, builder: body));
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.getSize(find.byType(TestuGrabber)).height, 32);
    });

    testWidgets('the real sheets fit the dialog', (tester) async {
      await openAt(tester, desktop, (c) => showTestuPdf(c, page: 6));
      await openAt(tester, desktop, (c) => showTestuResource(c, 'vid'));
      await openAt(tester, desktop,
          (c) => showTestuScheduleSheet(c, onScheduled: (_) {}));
      await openAt(
          tester,
          desktop,
          (c) => showTestuListSheet(c, title: 'SOURCES', rows: [
                (tag: 'PDF', label: 'Manual', trailing: 'p. 12',
                 selected: true, indent: false, onTap: () {}),
              ]));
    });
  });

  group('frame', () {
    Future<void> pumpShell(WidgetTester tester, Size size,
        {ValueChanged<int>? onTab}) async {
      window(tester, size);
      final modalWatch = TestuModalWatch();
      await tester.pumpWidget(MaterialApp(
        theme: testuTheme(),
        navigatorObservers: [modalWatch],
        builder: (context, child) => TestuFrame(
            rail: true,
            onTab: onTab ?? (_) {},
            modal: modalWatch.modal,
            child: child!),
        home: const TestuShell(),
      ));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('desktop window: rail in, bottom nav out, 720 column',
        (tester) async {
      await pumpShell(tester, desktop);
      expect(find.byType(TestuRail), findsOneWidget);
      expect(find.byType(TestuNav), findsNothing);
      expect(tester.getSize(find.byType(TestuShell)).width, 720);
    });

    testWidgets('phone window: the phone app, untouched', (tester) async {
      await pumpShell(tester, phone);
      expect(find.byType(TestuRail), findsNothing);
      expect(find.byType(TestuNav), findsOneWidget);
      expect(tester.getSize(find.byType(TestuShell)).width, 390);
    });

    testWidgets("desktop window: the frame's screen padding, not the phone's",
        (tester) async {
      await pumpShell(tester, desktop);
      TestuShell.tabRequest.value = 3;
      await tester.pump();
      // Title lines up with the rail's logo; no bottom-nav reserve.
      expect(tester.getTopLeft(find.text('Your readiness')).dy, 26);
      final list = tester.widget<ListView>(find.ancestor(
          of: find.text('Your readiness'), matching: find.byType(ListView)));
      expect((list.padding! as EdgeInsets).bottom, 32);
      // The tutor thread sinks to the composer instead of hanging under the
      // header: its last line ends where the ask bar's room begins.
      TestuShell.tabRequest.value = 2;
      await tester.pump(const Duration(seconds: 2));
      expect(tester.getBottomLeft(find.textContaining('Private to you')).dy,
          800 - 100);
    });

    testWidgets('phone window: screen padding untouched', (tester) async {
      await pumpShell(tester, phone);
      // Today, not Dashboard: in the test font the prototype Dashboard
      // overflows a 390 column, which fails the test when it is painted.
      expect(tester.getTopLeft(find.byType(TestuBell)).dy, 14);
      final list = tester.widget<ListView>(find.descendant(
          of: find.byType(TestuTodayScreen), matching: find.byType(ListView)));
      expect((list.padding! as EdgeInsets).bottom, 110);
      TestuShell.tabRequest.value = 2;
      await tester.pump();
      expect(tester.getBottomLeft(find.textContaining('Private to you')).dy,
          lessThan(844 - 130));
    });

    testWidgets('a rail tap reports the tab; the shell publishes its tab',
        (tester) async {
      addTearDown(() => TestuShell.currentTab.value = 0);
      int? tapped;
      await pumpShell(tester, desktop, onTab: (i) => tapped = i);
      await tester.tap(find.text('TOPICS'));
      expect(tapped, 1);
      TestuShell.tabRequest.value = 3;
      await tester.pump();
      expect(TestuShell.currentTab.value, 3);
    });

    testWidgets('a dialog dims the rail and blocks its taps', (tester) async {
      int? tapped;
      await pumpShell(tester, desktop, onTab: (i) => tapped = i);
      final ctx = tester.element(find.byType(TestuShell));
      showTestuSheet<void>(ctx, builder: (_) => const Text('modal'));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('modal'), findsOneWidget);
      await tester.tap(find.text('TOPICS'), warnIfMissed: false);
      await tester.pump();
      expect(tapped, isNull, reason: 'the rail is behind the barrier');
      Navigator.of(ctx).pop();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.text('TOPICS'));
      expect(tapped, 1, reason: 'the rail is live again');
    });

    testWidgets('TestuShell.currentTab resets to 0 for a fresh shell',
        (tester) async {
      addTearDown(() => TestuShell.currentTab.value = 0);
      TestuShell.currentTab.value = 3;
      await pumpShell(tester, desktop);
      expect(TestuShell.currentTab.value, 0);
    });

    testWidgets('openLearnerRoute lands on the tab the address names',
        (tester) async {
      addTearDown(() => TestuShell.currentTab.value = 0);
      await pumpShell(tester, desktop);
      openLearnerRoute(const LearnerRoute(3));
      await tester.pump();
      expect(TestuShell.currentTab.value, 3);
      expect(find.text('Your readiness'), findsOneWidget);
    });

    testWidgets('pushLearnerScreen stacks a screen over the shell and pops back',
        (tester) async {
      await pumpShell(tester, desktop);
      final ctx = tester.element(find.byType(TestuShell));
      final popped = pushLearnerScreen<void>(
          ctx,
          const LearnerRoute(1, topicId: 't1'),
          const Scaffold(body: Text('topic t1')));
      // Two pumps: the incoming route spends its first frame offstage.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('topic t1'), findsOneWidget);
      Navigator.of(ctx).pop();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await popped;
      expect(find.text('topic t1'), findsNothing);
      expect(find.byType(TestuShell), findsOneWidget);
    });
  });

  group('phone-browser nudge', () {
    Future<void> pumpNudge(WidgetTester tester, Size size) async {
      window(tester, size);
      await tester.pumpWidget(MaterialApp(
        theme: testuTheme(),
        home: Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => maybeShowTestuWebNudge(context, web: true));
          return const Scaffold();
        }),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a phone-sized browser is told once', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpNudge(tester, phone);
      expect(find.text('CONTINUE ON THE WEB'), findsOneWidget);
      await tester.tap(find.text('CONTINUE ON THE WEB'));
      await tester.pumpAndSettle();
      expect(find.text('CONTINUE ON THE WEB'), findsNothing);
      await pumpNudge(tester, phone);
      expect(find.text('CONTINUE ON THE WEB'), findsNothing,
          reason: 'dismissal is remembered per browser');
    });

    testWidgets('a desktop window never sees it', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpNudge(tester, desktop);
      expect(find.text('CONTINUE ON THE WEB'), findsNothing);
    });

    testWidgets('the app build never sees it', (tester) async {
      SharedPreferences.setMockInitialValues({});
      window(tester, phone);
      await tester.pumpWidget(MaterialApp(
        theme: testuTheme(),
        home: Builder(builder: (context) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => maybeShowTestuWebNudge(context, web: false));
          return const Scaffold();
        }),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('CONTINUE ON THE WEB'), findsNothing);
    });
  });
}
