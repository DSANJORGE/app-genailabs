import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_pdf.dart';
import 'package:genai_labs/testu/testu_resources.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:genai_labs/testu/testu_topics.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// Landscape (iPhone on its side, ~874×402 pt) must not overflow: the topic
/// hero shrinks, the video sheet splits player|chat, the PDF sheet splits
/// pages|chat. flutter_test fails a test on any RenderFlex overflow, so
/// pumping each surface at landscape size IS the assertion.

/// Never signals `initialized`, so the player stays in its 16:9 not-ready
/// state — exactly the geometry the layout is built around.
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

void main() {
  VideoPlayerPlatform.instance = _FakeVideoPlatform();

  void landscape(WidgetTester tester) {
    tester.view.physicalSize = const Size(874, 402);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> openSheet(
      WidgetTester tester, void Function(BuildContext) open) async {
    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
              onPressed: () => open(context), child: const Text('go')),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump(const Duration(seconds: 1)); // sheet animation
    await tester.pump(const Duration(seconds: 2)); // Sully typing settles
  }

  testWidgets('topic home fits landscape', (tester) async {
    landscape(tester);
    await tester.pumpWidget(MaterialApp(
        theme: testuTheme(), home: const TestuTopicHomeScreen()));
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('video resource sheet fits landscape', (tester) async {
    landscape(tester);
    await openSheet(tester, (c) => showTestuResource(c, 'vid'));
  });

  testWidgets('video resource sheet still fits portrait', (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await openSheet(tester, (c) => showTestuResource(c, 'vid'));
  });

  testWidgets('PDF sheet fits landscape', (tester) async {
    landscape(tester);
    await openSheet(tester, (c) => showTestuPdf(c, page: 6));
  });
}
