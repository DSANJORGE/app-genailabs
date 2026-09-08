# TestU Learn Web Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the learner app (`lib/main_testu.dart`) as a Flutter web build served same-origin by the eMe plugin, adaptive between the untouched phone UI and a desktop frame (left rail, centred column, sheets as dialogs).

**Architecture:** Two compile blockers (`dart:io` in the lock and avatar code) go behind a foundation-level platform check and a conditional-import avatar store. The server root becomes same-origin on web (the admin console's rule), which also fixes asset URLs and the tutor WebSocket. The responsive behaviour lives in exactly three shared places: `TestuFrame` in `MaterialApp.builder` (rail + 720 column), `showTestuSheet` (dialog on wide), and `TestuShell` (no bottom nav on wide). A once-per-browser dialog nudges phone-sized browsers toward the app.

**Tech Stack:** Flutter 3.44 stable, Dart 3.12; `shared_preferences`, `image_picker` (web impl bundled), `local_auth`; eMe plugin static hosting (`eme-plugin-testu/html/`); `flutter_test` on the Dart VM; agent-browser for the manual pass.

**Spec:** Traycer artifact `/Users/DSANJORGE/.traycer/epics/016e93d6-be42-47c3-ba0a-e36434a5132e/artifacts/testu-learn-web/index.md`

## Global Constraints

- Repo: `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs` (app) and `/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu` (plugin). Both are git repos. Work on branch `learn-web` in each.
- The working tree already has **uncommitted, unrelated changes under `lib/admin/`**. Never `git add -A` or `git add .`; add only the files named in each task's commit step.
- `ios/Runner.xcodeproj/project.pbxproj` must keep `objectVersion = 60`. Never commit that file in this plan.
- The desktop frame exists only in the web build (`kIsWeb`) and only at or above **700 px** window width. The iOS/Android app, including phone landscape, is byte-for-byte unchanged. The phone-browser nudge fires below **600 px** at first frame only.
- Column max width on wide: **720 px**. Rail width: **200 px**. Dialog max width: **640 px**, max height **88%** of the window (the sheet's cap).
- Hosting path: `eme-plugin-testu/html/learn/`, served at `/site/mediadb/learn/`. Not `html/testu/` (already holds images).
- Firebase stays off on web. Crashlytics and the Analytics observer are not initialised on web.
- Copy is bilingual through `L(en, es)` from `lib/testu/testu_i18n.dart`; widget tests run in English (`test/flutter_test_config.dart`).
- Widget tests run on the Dart VM: `flutter test <file>`. Overflow = test failure. The web compile check is `flutter build web -t lib/main_testu.dart --release` (2 to 4 minutes; run it where the plan says, not after every step).
- Every code step includes a `// ponytail:` comment only where a deliberate ceiling is left; otherwise plain doc comments in the existing voice.

---

### Task 0: Branch

**Files:** none

- [ ] **Step 1: Create the branch in the app repo**

```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs"
git status --short          # expect only lib/admin/*.dart modified — leave them alone
git checkout -b learn-web
```

- [ ] **Step 2: Create the branch in the plugin repo**

```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu"
git status --short
git checkout -b learn-web
```

- [ ] **Step 3: Confirm the toolchain**

```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs"
flutter --version | head -1     # Flutter 3.44.x
flutter devices | grep -i chrome # Chrome must be listed for Task 8
```

---

### Task 1: Device lock compiles without `dart:io`

**Files:**
- Modify: `lib/testu/testu_lock.dart:1-55`
- Modify: `lib/testu/testu_profile.dart:174-200` (the SECURITY card)
- Test: `test/testu_lock_test.dart` (existing, must keep passing)

**Interfaces:**
- Consumes: `defaultTargetPlatform`, `TargetPlatform`, `kIsWeb` from `package:flutter/foundation.dart`.
- Produces: `TestuLock.name` unchanged in behaviour on iOS/Android; `dart:io` gone from the file.

- [ ] **Step 1: Run the existing lock tests to see them green before touching anything**

Run: `flutter test test/testu_lock_test.dart`
Expected: all pass.

- [ ] **Step 2: Replace the `dart:io` import and the two `Platform.isIOS` reads**

In `lib/testu/testu_lock.dart`, line 1: delete `import 'dart:io';` and add, among the package imports:

```dart
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
```

Replace the `name` getter (lines 45-55) with:

```dart
  /// What to call it on screen — Apple and Android name their own sensors,
  /// so the UI must too ("Unlock with biometrics" reads like a spec sheet).
  /// Each label is the platform's own name for the sensor, so it reads
  /// correctly wherever it is dropped into a sentence. Foundation's target
  /// platform, not dart:io — the browser build compiles this file too.
  static String get name {
    final apple = defaultTargetPlatform == TargetPlatform.iOS;
    if (_kinds.contains(BiometricType.face)) {
      return apple ? 'Face ID' : L('Face Unlock', 'Desbloqueo facial');
    }
    if (_kinds.contains(BiometricType.fingerprint)) {
      return apple ? 'Touch ID' : L('Fingerprint', 'Huella');
    }
    return L('Biometrics', 'Biometría');
  }
```

- [ ] **Step 3: Hide the SECURITY card on web**

In `lib/testu/testu_profile.dart`, add `import 'package:flutter/foundation.dart' show kIsWeb;` to the imports. Then find the `_ProfCard(children: [ _H4(L('SECURITY', 'SEGURIDAD')), ...` element (starts at line 174) and prefix the whole `_ProfCard(...)` element with `if (!kIsWeb)` so it reads:

```dart
            // No sensor in a browser tab; the card would only ever say
            // "set up Face ID first".
            if (!kIsWeb)
              _ProfCard(children: [
                _H4(L('SECURITY', 'SEGURIDAD')),
                ...unchanged...
              ]),
```

(Re-indent the card body by two spaces; nothing inside it changes.)

- [ ] **Step 4: Analyze and re-run the lock tests**

Run: `flutter analyze lib/testu/testu_lock.dart lib/testu/testu_profile.dart && flutter test test/testu_lock_test.dart`
Expected: no analyzer issues; all lock tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/testu/testu_lock.dart lib/testu/testu_profile.dart
git commit -m "learn-web: device lock names the sensor without dart:io; no Security card on web"
```

---

### Task 2: Avatar store behind a conditional import

**Files:**
- Create: `lib/testu/testu_avatar_io.dart`
- Create: `lib/testu/testu_avatar_web.dart`
- Modify: `lib/testu/testu_profile.dart:1-99`
- Test: `test/testu_avatar_web_test.dart` (new), `test/testu_lock_test.dart` (existing, uses the io store via `testuAvatarLibrary`)

**Interfaces:**
- Produces (identical top-level API in both files):
  - `Future<List<String>> avatarRestoreLibrary()` — stored photo keys, oldest first
  - `bool avatarExists(String src)` — the key still resolves
  - `Future<String> avatarAdd(XFile picked)` — stores the pick, returns its key
  - `Future<void> avatarRemove(String src)`
  - `ImageProvider avatarImage(String src)`
- Consumed by `testu_profile.dart` only. Keys are file paths on device, `data:` URLs in the browser.

- [ ] **Step 1: Write the failing test for the web store**

Create `test/testu_avatar_web_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_avatar_web.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The browser has no filesystem: a picked photo must survive as a data
/// URL in prefs, resolve to an image, and leave cleanly when removed.
/// (The file has no web-only imports, so the VM can test it directly.)
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a picked photo round-trips through prefs as a data URL', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final src = await avatarAdd(XFile.fromData(bytes, mimeType: 'image/png'));
    expect(src, 'data:image/png;base64,${base64Encode(bytes)}');
    expect(avatarExists(src), isTrue);
    expect(await avatarRestoreLibrary(), [src]);
    expect((avatarImage(src) as MemoryImage).bytes, bytes);
    expect(identical(avatarImage(src), avatarImage(src)), isTrue,
        reason: 'one provider per key, so the image cache hits');
    await avatarRemove(src);
    expect(await avatarRestoreLibrary(), isEmpty);
  });

  test('a key that is not a data URL does not exist here', () {
    expect(avatarExists('/var/mobile/avatars/1.jpg'), isFalse);
  });
}
```

- [ ] **Step 2: Run it to see it fail**

Run: `flutter test test/testu_avatar_web_test.dart`
Expected: FAIL — `testu_avatar_web.dart` does not exist.

- [ ] **Step 3: Create the web store**

Create `lib/testu/testu_avatar_web.dart`:

```dart
import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Browser avatar store (spec: `testu-learn-web`): picked photos live as
/// data URLs in shared_preferences (localStorage). A 512px JPEG is ~60 KB;
/// the 5 MB quota is nowhere near. Same API as testu_avatar_io.dart.
const _kLib = 'testu_avatar_library';

Future<List<String>> avatarRestoreLibrary() async =>
    (await SharedPreferences.getInstance()).getStringList(_kLib) ?? const [];

bool avatarExists(String src) => src.startsWith('data:');

Future<String> avatarAdd(XFile picked) async {
  final src = 'data:${picked.mimeType ?? 'image/jpeg'};base64,'
      '${base64Encode(await picked.readAsBytes())}';
  final p = await SharedPreferences.getInstance();
  await p.setStringList(_kLib, [...await avatarRestoreLibrary(), src]);
  return src;
}

Future<void> avatarRemove(String src) async {
  final p = await SharedPreferences.getInstance();
  await p.setStringList(
      _kLib, (await avatarRestoreLibrary()).where((s) => s != src).toList());
  _images.remove(src);
}

// One provider per key, so Flutter's image cache hits instead of decoding
// the same photo on every rebuild (MemoryImage compares bytes by identity).
final _images = <String, MemoryImage>{};

ImageProvider avatarImage(String src) => _images[src] ??=
    MemoryImage(base64Decode(src.substring(src.indexOf(',') + 1)));
```

- [ ] **Step 4: Run the test to see it pass**

Run: `flutter test test/testu_avatar_web_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Create the device store (the code moved out of testu_profile.dart)**

Create `lib/testu/testu_avatar_io.dart`:

```dart
import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// On-device avatar store: photos under <documents>/avatars, keyed by
/// path. Same API as testu_avatar_web.dart; testu_profile.dart picks one
/// with a conditional import.
Future<Directory> _dir() async {
  final d =
      Directory('${(await getApplicationDocumentsDirectory()).path}/avatars');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

Future<List<String>> avatarRestoreLibrary() async {
  final dir = await _dir();
  // Carried over from the single-photo cut, which saved one fixed avatar.jpg.
  final legacy = File('${dir.parent.path}/avatar.jpg');
  if (legacy.existsSync()) {
    legacy.renameSync(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
  }
  return dir.listSync().whereType<File>().map((f) => f.path).toList()..sort();
}

bool avatarExists(String src) => File(src).existsSync();

/// Copies the pick under a unique name — FileImage caches by path, so
/// reusing one filename would keep serving the previous photo.
Future<String> avatarAdd(XFile picked) async {
  final dest =
      '${(await _dir()).path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(picked.path).copy(dest);
  return dest;
}

Future<void> avatarRemove(String src) async {
  final f = File(src);
  if (f.existsSync()) f.deleteSync();
  await FileImage(f).evict();
}

ImageProvider avatarImage(String src) => FileImage(File(src));
```

- [ ] **Step 6: Point testu_profile.dart at the store**

In `lib/testu/testu_profile.dart`:

Imports: delete `import 'dart:io';` and `import 'package:path_provider/path_provider.dart';`. Keep `image_picker` and `shared_preferences`. Add, after the package imports:

```dart
import 'testu_avatar_io.dart'
    if (dart.library.js_interop) 'testu_avatar_web.dart';
```

Replace lines 34-99 (from `const _kAvatarPref = 'testu_avatar';` through `testuAvatarImage`) with:

```dart
const _kAvatarPref = 'testu_avatar';

/// Restores the library and the selection; call once at startup.
Future<void> restoreTestuAvatar() async {
  testuAvatarLibrary.value = await avatarRestoreLibrary();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kAvatarPref);
  if (saved != null && (saved.startsWith('assets/') || avatarExists(saved))) {
    testuAvatar.value = saved;
  }
}

Future<void> _selectAvatar(String src) async {
  testuAvatar.value = src;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kAvatarPref, src);
}

Future<void> _addAvatar() async {
  final picked = await ImagePicker()
      .pickImage(source: ImageSource.gallery, maxWidth: 512);
  if (picked == null) return;
  final src = await avatarAdd(picked);
  testuAvatarLibrary.value = [...testuAvatarLibrary.value, src];
  await _selectAvatar(src);
}

/// Removes a photo from TestU (not from the phone's own library). If it was
/// the one in use, the profile falls back to the first preset rather than
/// leaving the header with a missing file.
Future<void> _removeAvatar(String src) async {
  await avatarRemove(src);
  testuAvatarLibrary.value =
      testuAvatarLibrary.value.where((p) => p != src).toList();
  if (testuAvatar.value == src) await _selectAvatar(_presetAvatars.first);
}

/// [testuAvatar] holds a bundled asset key or a store key (a file path on
/// device, a data URL in the browser).
ImageProvider testuAvatarImage(String src) =>
    src.startsWith('assets/') ? AssetImage(src) : avatarImage(src);
```

- [ ] **Step 7: Analyze, run the lock tests (they drive the io store), then the web compile check**

Run: `flutter analyze lib/testu && flutter test test/testu_lock_test.dart test/testu_avatar_web_test.dart`
Expected: clean; all pass.

Run: `flutter build web -t lib/main_testu.dart --release 2>&1 | tail -5`
Expected: ends with `✓ Built build/web`. If it fails on a `dart:io` import, the error names the file: it must be one of the two seams above or a new import, not `eme_app_package`.

- [ ] **Step 8: Commit**

```bash
git add lib/testu/testu_avatar_io.dart lib/testu/testu_avatar_web.dart lib/testu/testu_profile.dart test/testu_avatar_web_test.dart
git commit -m "learn-web: avatar store behind a conditional import; the learner app compiles for web"
```

---

### Task 3: Same-origin server root, error hooks without Firebase, usage on web

**Files:**
- Modify: `lib/testu/testu_live.dart:29-42`
- Modify: `lib/main_testu.dart:24-41` and `:95-114`
- Modify: `lib/testu/testu_usage.dart:14-17`
- Test: `test/testu_usage_test.dart` (existing, must keep passing)

**Interfaces:**
- Consumes: `AppErrorHandler.initialize([FirebaseOptions? options])` from `eme_app_package/utils/error_handler.dart` (installs `FlutterError.onError` and `PlatformDispatcher.onError` even when `options` is null).
- Produces: `_mediaDBRoot` in `testu_live.dart` becomes a `final String` (same name, no longer `const`).

- [ ] **Step 1: Server root follows the page origin on web**

In `lib/testu/testu_live.dart`, make sure `package:flutter/foundation.dart` is imported (add `import 'package:flutter/foundation.dart' show kIsWeb;` if it is not). Replace lines 29-33 with:

```dart
/// The eMe server live mode talks to. `--dart-define=TESTU_MEDIADB=...`
/// wins; else the browser build talks to its own origin (the plugin serves
/// it at /site/mediadb/learn/, same rule as the console); else the local
/// eme-server-minsur checkout (Tomcat on :8080). Asset URLs and the tutor
/// WebSocket (siteroot + scheme come from this in Workspace.toJson) follow.
final String _mediaDBRoot =
    const String.fromEnvironment('TESTU_MEDIADB').isNotEmpty
        ? const String.fromEnvironment('TESTU_MEDIADB')
        : kIsWeb
            ? '${Uri.base.origin}/site/mediadb'
            : 'http://localhost:8080/site/mediadb';
```

`liveAssetUrl` (line 37) and `_workspace` (line 41) read `_mediaDBRoot` and need no change.

- [ ] **Step 2: Error hooks on web, Firebase off**

In `lib/main_testu.dart`, add `import 'package:flutter/foundation.dart' show kIsWeb;` and replace lines 26-31 with:

```dart
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
```

- [ ] **Step 3: A hidden browser tab counts as paused**

In `lib/main_testu.dart`, replace the `didChangeAppLifecycleState` condition (line 97) so the method starts:

```dart
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A browser tab never reports `paused`: `hidden` is what it sends when
    // the tab is hidden or closing, so that is the flush point on web.
    // Mobile keeps `paused` only (see the note above about `inactive`).
    if (state == AppLifecycleState.paused ||
        (kIsWeb && state == AppLifecycleState.hidden)) {
```

The body of the branch is unchanged.

- [ ] **Step 4: Usage events say `web`**

In `lib/testu/testu_usage.dart` (foundation is already imported), replace lines 14-17 with:

```dart
final testuUsage = TestuUsage(
  // A browser reports the emulated platform (iOS under Safari); the console
  // wants to tell web sessions apart.
  platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
  appVersion: kTestuAppVersion,
);
```

- [ ] **Step 5: Analyze and run the usage tests**

Run: `flutter analyze lib/main_testu.dart lib/testu/testu_live.dart lib/testu/testu_usage.dart && flutter test test/testu_usage_test.dart test/testu_tutor_channel_test.dart`
Expected: clean; all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/main_testu.dart lib/testu/testu_live.dart lib/testu/testu_usage.dart
git commit -m "learn-web: same-origin server root, error hooks without Firebase, web usage label"
```

---

### Task 4: Breakpoint, sheets as dialogs, hover cursor

**Files:**
- Modify: `lib/testu/testu_widgets.dart:21-60` (TestuPressable), `:748-767` (TestuGrabber), `:769-796` (showTestuSheet)
- Test: `test/testu_web_test.dart` (new)

**Interfaces:**
- Produces: `const double kTestuWide = 700;` and `bool testuWide(BuildContext context)` in `testu_widgets.dart`. Tasks 5 and 6 use them.
- `showTestuSheet` keeps its signature; on wide it returns `showDialog`'s future.

- [ ] **Step 1: Write the failing tests**

Create `test/testu_web_test.dart`:

```dart
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
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/testu_web_test.dart`
Expected: FAIL — the first test finds a `BottomSheet`, not a `Dialog`; grabber height is 32.

- [ ] **Step 3: Add the breakpoint and the cursor**

In `lib/testu/testu_widgets.dart`, after `testuBigText` (line 19) add:

```dart
/// Window width from which the browser build wears the desktop frame
/// (left rail, centred column, sheets as dialogs — spec: testu-learn-web).
/// Below it every surface is the phone app unchanged.
const double kTestuWide = 700;

/// The frame is a browser thing: an iPhone on its side is 874pt wide and
/// must stay the phone app. Tests flip this to exercise the frame on the VM.
@visibleForTesting
bool testuDesktop = kIsWeb;

bool testuWide(BuildContext context) =>
    testuDesktop && MediaQuery.sizeOf(context).width >= kTestuWide;
```

`testu_widgets.dart` needs `import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;` (material re-exports neither reliably; add the import).

In `_TestuPressableState.build`, wrap the `GestureDetector` in a `MouseRegion`:

```dart
  @override
  Widget build(BuildContext context) {
    // Desktop: a hand cursor says "this presses"; haptics are silent there.
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      child: GestureDetector(
        ...existing GestureDetector unchanged...
      ),
    );
  }
```

- [ ] **Step 4: Grabber hides on wide**

Replace `TestuGrabber.build` (lines 752-766):

```dart
  @override
  Widget build(BuildContext context) {
    // A dialog has nothing to drag; keep only the sheet's top breathing room.
    if (testuWide(context)) return const SizedBox(height: 16);
    final t = TestuTokens.of(context);
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 16),
        decoration: BoxDecoration(
          color: t.line2,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
```

- [ ] **Step 5: Sheet becomes a dialog on wide**

Replace `showTestuSheet` (lines 769-796):

```dart
/// THE bottom-sheet chrome (spec: 22px top radius, card fill, hairline
/// edge, 66% backdrop, 88% height cap, Material's 640px landscape cap,
/// backdrop-tap closes unless [dismissible] is false). Bodies start with a
/// [TestuGrabber] and own their scrolling. On a desktop window
/// (spec: testu-learn-web) the same body opens as a centred dialog — a
/// 640px strip glued to the bottom of a 1920px window is a sheet in name
/// only.
Future<T?> showTestuSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxHeight = 0.88,
  bool dismissible = true,
}) {
  final t = TestuTokens.of(context);
  if (testuWide(context)) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: t.barrier,
      builder: (ctx) => Dialog(
        backgroundColor: t.card,
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: t.line2),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 640,
            maxWidth: 640,
            maxHeight: MediaQuery.sizeOf(ctx).height * maxHeight,
          ),
          child: builder(ctx),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    backgroundColor: t.card,
    barrierColor: t.barrier,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: t.line2),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * maxHeight,
      maxWidth: 640,
    ),
    builder: builder,
  );
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/testu_web_test.dart test/testu_landscape_test.dart`
Expected: all pass. The landscape rig is unchanged (`testuDesktop` is false there, so phone landscape keeps its bottom sheets). If a real sheet overflows inside the dialog in the new test, the fix belongs in that sheet's body (it assumed the window width); report it rather than loosening the test.

- [ ] **Step 7: Commit**

```bash
git add lib/testu/testu_widgets.dart test/testu_web_test.dart
git commit -m "learn-web: 700px breakpoint, sheets open as dialogs on wide, hover cursor on pressables"
```

---

### Task 5: Rail, frame, and no bottom nav on wide

**Files:**
- Create: `lib/testu/testu_web.dart`
- Modify: `lib/testu/testu_shell.dart:21-102` (TestuShell), `:211-231` (Today landscape branch)
- Modify: `lib/main_testu.dart:151-187` (MaterialApp)
- Test: `test/testu_web_test.dart` (extend)

**Interfaces:**
- Produces in `testu_shell.dart`: `TestuShell.currentTab` (`ValueNotifier<int>`, the tab on screen) and top-level `List<String> testuTabLabels()`.
- Produces in `testu_web.dart`: `TestuFrame({required bool rail, required ValueChanged<int> onTab, required Widget child})` and `TestuRail({required ValueChanged<int> onTab})`.
- Consumes: `kTestuWide`, `testuWide`, `TestuPressable`, `TestuTokens`, `client`, `testuLang`, `L`.

- [ ] **Step 1: Write the failing tests**

Append to `test/testu_web_test.dart` (add imports `package:genai_labs/testu/testu_shell.dart` and `package:genai_labs/testu/testu_web.dart`):

```dart
  group('frame', () {
    Future<void> pumpShell(WidgetTester tester, Size size,
        {ValueChanged<int>? onTab}) async {
      window(tester, size);
      await tester.pumpWidget(MaterialApp(
        theme: testuTheme(),
        builder: (context, child) =>
            TestuFrame(rail: true, onTab: onTab ?? (_) {}, child: child!),
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

    testWidgets('a rail tap reports the tab; the shell publishes its tab',
        (tester) async {
      int? tapped;
      await pumpShell(tester, desktop, onTab: (i) => tapped = i);
      await tester.tap(find.text('TOPICS'));
      expect(tapped, 1);
      TestuShell.tabRequest.value = 3;
      await tester.pump();
      expect(TestuShell.currentTab.value, 3);
    });
  });
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/testu_web_test.dart`
Expected: FAIL — `testu_web.dart` does not exist.

- [ ] **Step 3: Shell publishes its tab, labels become shareable, nav hides on wide**

In `lib/testu/testu_shell.dart`:

Add to `TestuShell` (after `tabRequest`, line 25):

```dart
  /// The tab on screen — the desktop rail (testu_web.dart) mirrors it.
  static final currentTab = ValueNotifier<int>(0);
```

Replace the `_tabs` getter (lines 34-42) with a top-level function placed just above `class TestuShell`:

```dart
/// The four tab labels, in nav order. The tutor tab wears the org tutor's
/// name (Vueling → Sully): it opens the general tutor that routes questions
/// to the topic-expert tutors who answer inside topic/question contexts.
List<String> testuTabLabels() => [
      L('TODAY', 'HOY'),
      L('TOPICS', 'TEMAS'),
      client.tutor.toUpperCase(),
      L('DASHBOARD', 'DASHBOARD'),
    ];
```

In `_TestuShellState`, add one method and route the three tab changes through it:

```dart
  void _select(int i) {
    TestuShell.currentTab.value = i;
    setState(() => _tab = i);
  }
```

- `_onTabRequest`: `setState(() => _tab = i);` → `_select(i);`
- `TestuTutorScreen(... onCalibration: () => _select(3), ...)`
- `TestuNav(... onTap: (i) { HapticFeedback.selectionClick(); _select(i); })`

In `build`, `items: _tabs` → `items: testuTabLabels()`, and the nav line becomes:

```dart
      // On a desktop window the rail (testu_web.dart) carries the tabs.
      bottomNavigationBar: testuWide(context)
          ? null
          : TestuNav(
              items: testuTabLabels(),
              current: _tab,
              onTap: (i) {
                HapticFeedback.selectionClick();
                _select(i);
              },
            ),
```

- [ ] **Step 4: Today's "landscape" means a short window**

In `_TestuTodayScreenState.build` (line 211-215), replace the condition and its comment:

```dart
    final size = MediaQuery.sizeOf(context);
    if (size.height < 500) {
      // Short viewport (a phone on its side): pinned, the header would
      // swallow half the height — it scrolls away with the cards instead
      // (it has its own 18px padding). A desktop window is wide AND tall,
      // so it keeps the pinned header.
```

- [ ] **Step 5: Create the frame and the rail**

Create `lib/testu/testu_web.dart`:

```dart
import 'package:flutter/material.dart';

import 'testu_client.dart';
import 'testu_i18n.dart';
import 'testu_shell.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Desktop frame for the browser build (spec: testu-learn-web). Below
/// [kTestuWide] the child is the phone app untouched; from there on a left
/// rail carries the four tabs and every route lives in a centred 720px
/// column. Sits in MaterialApp.builder, outside the Navigator, so pushed
/// routes keep the rail beside them.
class TestuFrame extends StatelessWidget {
  const TestuFrame({
    super.key,
    required this.rail,
    required this.onTab,
    required this.child,
  });

  /// Rail only once signed in and unlocked — sign-in, the lock screen and
  /// the launch intro are client-neutral full-window surfaces.
  final bool rail;
  final ValueChanged<int> onTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!testuWide(context)) return child;
    final t = TestuTokens.of(context);
    return ColoredBox(
      color: t.bg,
      child: Row(children: [
        if (rail) TestuRail(onTab: onTab),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: child,
            ),
          ),
        ),
      ]),
    );
  }
}

/// The bottom nav stood on its side: client logo or wordmark, then the four
/// mono labels with the 2px orange tick on their left edge (same colours
/// and tracking as [TestuNav]).
class TestuRail extends StatelessWidget {
  const TestuRail({super.key, required this.onTab});

  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      width: 200,
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: t.line)),
      ),
      // Language switch re-reads L(); the shell tells us which tab is up.
      child: ValueListenableBuilder<String>(
        valueListenable: testuLang,
        builder: (_, __, ___) => ValueListenableBuilder<int>(
          valueListenable: TestuShell.currentTab,
          builder: (_, current, __) {
            final labels = testuTabLabels();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (client.logo != null)
                  Image.asset(client.logo!, height: 22)
                else
                  Text(
                    client.wordmark.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Sora',
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 0.8,
                      color: client.brand,
                    ),
                  ),
                const SizedBox(height: 34),
                for (var i = 0; i < labels.length; i++)
                  TestuPressable(
                    onTap: () => onTab(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: TestuTokens.curve,
                          width: 2,
                          height: 12,
                          color: i == current ? t.orange : Colors.transparent,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontFamily: 'GeistMono',
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: i == current ? t.ink : t.faint,
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Mount the frame in the app**

In `lib/main_testu.dart`, add `import 'testu/testu_web.dart';` and give the `MaterialApp` (line 174) a `builder`:

```dart
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
        child: child!,
      ),
      ...rest unchanged...
```

- [ ] **Step 7: Run the tests**

Run: `flutter analyze lib && flutter test test/testu_web_test.dart test/testu_landscape_test.dart`
Expected: clean; all pass. If the shell test fails with a pending-timer error from the tutor tab, replace `home: const TestuShell()` in `pumpShell` with `home: const Scaffold(body: Text('x'))` for the first two tests only and keep the third on the shell; report the change.

- [ ] **Step 8: Commit**

```bash
git add lib/testu/testu_web.dart lib/testu/testu_shell.dart lib/main_testu.dart test/testu_web_test.dart
git commit -m "learn-web: rail + 720px column in MaterialApp.builder; no bottom nav on wide; Today pins its header on tall windows"
```

---

### Task 6: The "made for desktop" dialog

**Files:**
- Modify: `lib/testu/testu_web.dart` (append)
- Modify: `lib/main_testu.dart:122-138` (`_restore`)
- Test: `test/testu_web_test.dart` (extend)

**Interfaces:**
- Produces: `Future<void> maybeShowTestuWebNudge(BuildContext context, {bool web = kIsWeb})` in `testu_web.dart`. `context` must be under the app's `Navigator` (the navigator key's own context is fine).
- Consumes: `showTestuDialog`, `TestuEyebrow`, `TestuButton`, `TestuButtonVariant` from `testu_widgets.dart`.

- [ ] **Step 1: Write the failing tests**

Append to `test/testu_web_test.dart` (add `import 'package:shared_preferences/shared_preferences.dart';`):

```dart
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('a phone-sized browser is told once', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await pumpNudge(tester, phone);
      expect(find.text('CONTINUE ON THE WEB'), findsOneWidget);
      await tester.tap(find.text('CONTINUE ON THE WEB'));
      await tester.pump(const Duration(milliseconds: 400));
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
```

- [ ] **Step 2: Run to see it fail**

Run: `flutter test test/testu_web_test.dart`
Expected: FAIL — `maybeShowTestuWebNudge` is not defined.

- [ ] **Step 3: Implement the nudge**

Append to `lib/testu/testu_web.dart` (add imports `package:flutter/foundation.dart show kIsWeb` and `package:shared_preferences/shared_preferences.dart`):

```dart
const _kNudged = 'testu_web_nudged';

/// Phone-sized browser, once per browser: the web build is for desks, the
/// app is for phones (Diego, 2026-09-07). Checked at first frame only, so
/// resizing a desktop window never triggers it. [web] is the test seam.
/// ponytail: no store buttons until the App Store / Play listings exist.
Future<void> maybeShowTestuWebNudge(BuildContext context,
    {bool web = kIsWeb}) async {
  if (!web || MediaQuery.sizeOf(context).width >= 600) return;
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_kNudged) ?? false) return;
  await prefs.setBool(_kNudged, true);
  if (!context.mounted) return;
  final t = TestuTokens.of(context);
  await showTestuDialog<void>(
    context,
    dismissible: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TestuEyebrow(L('MADE FOR DESKTOP', 'PENSADO PARA ESCRITORIO')),
        const SizedBox(height: 10),
        Text(
          L('TestU Learn on the web is designed for a desktop screen. On your phone, the TestU Learn app is the way to learn.',
              'TestU Learn en la web está pensado para pantallas de escritorio. En tu teléfono, la app de TestU Learn es la forma de aprender.'),
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 13.5,
            height: 1.5,
            color: t.mut,
          ),
        ),
        const SizedBox(height: 16),
        TestuButton(
          L('CONTINUE ON THE WEB', 'SEGUIR EN LA WEB'),
          variant: TestuButtonVariant.primary,
          onTap: () => Navigator.of(context).pop(),
        ),
      ],
    ),
  );
}
```

- [ ] **Step 4: Fire it at first frame in the app**

In `lib/main_testu.dart`, at the end of `_restore()` (after the `setState` block, line 137), add:

```dart
    // First frame on a phone-sized browser: point at the app, once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = _nav.currentContext;
      if (c != null) maybeShowTestuWebNudge(c);
    });
```

- [ ] **Step 5: Run the tests**

Run: `flutter analyze lib && flutter test test/testu_web_test.dart`
Expected: clean; all pass.

- [ ] **Step 6: Commit**

```bash
git add lib/testu/testu_web.dart lib/main_testu.dart test/testu_web_test.dart
git commit -m "learn-web: once-per-browser 'made for desktop' dialog on phone-sized windows"
```

---

### Task 7: Build and run scripts

**Files:**
- Create: `build_learn.sh`
- Create: `run_learn.sh`

**Interfaces:**
- Produces: `eme-plugin-testu/html/learn/` (build output + `_site.xconf`), consumed by the plugin's `deploy.sh`.

- [ ] **Step 1: Create the build script**

Create `build_learn.sh` at the app root:

```sh
#!/bin/sh
# Builds the learner app for the web and drops it into the plugin so eMe
# serves it at /site/mediadb/learn/ (spec: testu-learn-web). Mirrors
# build_admin.sh; same-origin, so no CORS anywhere.
set -e
cd "$(dirname "$0")"
# build/web is merged into, never cleaned (see build_admin.sh for the
# stale --wasm artifact that once shipped).
rm -rf build/web
flutter build web -t lib/main_testu.dart --release --base-href /site/mediadb/learn/ --dart-define=TESTU_CLIENT=minsur --pwa-strategy=none
rm -rf ../eme-plugin-testu/html/learn && cp -R build/web ../eme-plugin-testu/html/learn
# The plugin's _site.xconf is owned by this script, not by build/web.
cat > ../eme-plugin-testu/html/learn/_site.xconf << 'XCONF'
<page>
  <property name="fallbackdirectory"></property>
  <generator name="file"/>
  <permission name="view"><boolean value="true"/></permission>
</page>
XCONF
echo "learner web built into eme-plugin-testu/html/learn"
```

- [ ] **Step 2: Create the run script**

Create `run_learn.sh` at the app root:

```sh
#!/bin/sh
# Learner app in Chrome against the local server (start it first). Extra
# args go to flutter run.
# ponytail: --disable-web-security covers the :7358 -> :8080 CORS gap for
# local dev only; production serves the app same-origin from the plugin, so
# this flag never ships.
cd "$(dirname "$0")" && exec flutter run -t lib/main_testu.dart -d chrome --web-port 7358 \
  --web-browser-flag=--disable-web-security \
  --dart-define=TESTU_CLIENT=minsur --dart-define=TESTU_MEDIADB=http://localhost:8080/site/mediadb "$@"
```

- [ ] **Step 3: Make them executable and build**

```bash
chmod +x build_learn.sh run_learn.sh
./build_learn.sh 2>&1 | tail -3
ls ../eme-plugin-testu/html/learn | head        # index.html, main.dart.js, _site.xconf, assets/ ...
grep -c '<base href="/site/mediadb/learn/">' ../eme-plugin-testu/html/learn/index.html   # 1
```

Expected: the build succeeds and the base href is `/site/mediadb/learn/`.

- [ ] **Step 4: Commit the scripts (app) and the build (plugin)**

```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs"
git add build_learn.sh run_learn.sh
git commit -m "learn-web: build_learn.sh (into the plugin at /site/mediadb/learn/) and run_learn.sh"
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu"
git add html/learn
git commit -m "learn: learner web build served at /site/mediadb/learn/"
```

---

### Task 8: Manual pass in the browser

**Files:** none (verification). Screenshots go to `/tmp/learn-web/`.

**Interfaces:**
- Consumes: the local eMe server (`~/Code/eme-server-minsur`, Tomcat on :8080), the plugin's `deploy.sh`, the agent-browser skill.

- [ ] **Step 1: Confirm the local server is up and deploy the plugin**

```bash
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/site/mediadb/services/authentication/user.json   # 403 or 200, not "connection refused"
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/eme-plugin-testu" && ./deploy.sh
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8080/site/mediadb/learn/   # 200
```

If the server is down, start it per the `testu-backend-wiring-state` memory before continuing.

- [ ] **Step 2: Desktop pass with agent-browser (1280×800)**

Use the agent-browser skill. Open `http://localhost:8080/site/mediadb/learn/` at 1280×800 and screenshot each state to `/tmp/learn-web/`:

1. `01_signin.png` — sign-in screen, no rail, column centred.
2. Sign in with the local test account (`diego@testu.co`; the local mail sink prints the code, the known local code is `123456`). `02_today.png` — rail on the left (MINSUR logo, HOY active with the orange tick), Today with the pinned header, no bottom nav.
3. Click TEMAS, IRIS, DASHBOARD in the rail: `03_topics.png`, `04_tutor.png`, `05_dashboard.png`. The tutor greeting must arrive (WebSocket over same origin).
4. Back on HOY, click "Programar evaluación": `06_schedule_dialog.png` — centred dialog, 22px corners, no grabber.
5. Open a topic, then "Continuar con tu tutor": `07_session.png` — session inside the 720 column, rail still visible. Click a rail tab: the session pops and the tab shows.
6. Open a source (a citation's "Ver fuente" or a Resources row): `08_pdf_dialog.png` — page images load (same-origin `image3000x3000pageN.webp`).
7. Profile from the avatar: `09_profile.png` — no SEGURIDAD card; pick a photo; the avatar updates in the header. Reload the page: the photo survives (localStorage).
8. Open the browser console: no red errors besides the known 403 burst on a stale session.

- [ ] **Step 3: Phone-window pass (390×844)**

Resize (or open a new context) at 390×844 and reload: `10_nudge.png` — "PENSADO PARA ESCRITORIO" dialog with "SEGUIR EN LA WEB". Dismiss: the phone app with the bottom nav. Reload: no dialog.

- [ ] **Step 4: Report**

Write the findings as a short list in the task report: each screenshot, pass or fail, and any overflow, missing image, or console error with the exact text. Anything failing here is a defect to fix in the task that owns that surface, not in this one.

---

### Task 9: Close out

**Files:**
- Create: `/Users/DSANJORGE/.traycer/epics/016e93d6-be42-47c3-ba0a-e36434a5132e/artifacts/testu-learn-web/plan/index.md` (pointer, status 2 when done)

- [ ] **Step 1: Full suite and analyzer**

Run: `flutter analyze && flutter test`
Expected: clean; all pass (the `shots` tag stays skipped by default).

- [ ] **Step 2: Mark the pointer artifact complete**

Set `status: 2` in the plan pointer artifact's frontmatter and add one line per task with its commit hash (`git log --oneline learn-web ^analytics-v1`).

- [ ] **Step 3: Do not push, do not merge**

Both `learn-web` branches stay local until DSANJORGE asks. Leave `lib/admin/*` uncommitted as found.
