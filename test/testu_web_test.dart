import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_pdf.dart';
import 'package:genai_labs/testu/testu_resources.dart';
import 'package:genai_labs/testu/testu_schedule_sheet.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:genai_labs/testu/testu_widgets.dart';
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
}
