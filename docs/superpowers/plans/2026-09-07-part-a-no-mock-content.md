# Part A: No Mock Content in the Live Build — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** In a live build (`testuLive`), every name, organisation, photo, cover, badge and line of copy on screen comes from the signed-in eMe user, the server, or a neutral fallback that admits it has no data; the demo (Vueling) build stays byte-for-byte.

**Architecture:** Two top-level getters in `lib/testu/testu_live.dart` (`testuFirstName`, `testuFullName`, plus `testuInitials`, `testuEmail`) become the only source of a learner's name; a `ValueNotifier<String> testuOrganization` fed by `services/testu/personas/me.json` becomes the only source of an organisation line. Every site that printed the client's demo persona, the "Minsur · Lima" line, a job title, a stock photo or a stock cover switches to those, gated with `testuLive` (a compile-time `const`, so the demo branch is byte-identical and the live binary drops the demo strings). Silent failures get the dashboard's existing "Reintentar" pattern.

**Tech Stack:** Flutter 3.44.6 / Dart 3.x, `eme_app_package` (path dep `../eme_app_package`: `AuthService`, `User`, `EmeHttp`, `FakeEmeHttp`), `flutter_test`, `shared_preferences` mock, `unzip`/`strings` for the release-binary scan.

**Spec:** `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs/docs/superpowers/specs/2026-09-07-minsur-pilot-readiness-design.md` — Part A (table + verification paragraph) and Part B "Data on screen".

## Global Constraints

- Repo `/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs`, branch `testu/impeccable`, **25 uncommitted files already modified** (tonight's store fixes). Never revert, stash, checkout, commit or push. Every task ends with "leave uncommitted for the user". Never `git add`.
- Never run `deploy.sh` or `build_store.sh` yourself; Task 8 asks the user to run `build_store.sh`.
- `ios/Runner.xcodeproj/project.pbxproj` must stay `objectVersion = 60`. If a build changes it to `54`: `git checkout -- ios/Runner.xcodeproj/project.pbxproj`.
- Ponytail mode full: minimal diffs, reuse existing helpers, `// ponytail:` comment on deliberate shortcuts, no new dependencies, no new abstractions beyond the two widgets the spec asks for (initials avatar, neutral cover).
- Every live-only behaviour is gated `if (testuLive)` / `testuLive ? live : demo` (`const bool testuLive` in `lib/testu/testu_live.dart:26`). The Vueling demo build must not change.
- The app never offers signup. Spanish copy goes through `L(en, es)` / `CL(mEn, mEs, vEn, vEs)` from `lib/testu/testu_i18n.dart`; widget tests run in English (`test/flutter_test_config.dart` pins `testuLang.value = 'en'`).
- Test commands: `flutter test <file>` (single file, seconds) and `flutter test` (whole suite, minutes). Analyze: `flutter analyze`. The golden shot suites (`test/landscape_shots_test.dart`, `test/console_shots_test.dart`) are skipped by default (`--run-skipped` to run); do not regenerate them in this plan.
- Spec rule (Part A): "every string, number and image on screen comes from the signed-in user, the server, or a neutral fallback that admits it has no data. Nothing invented."
- Spec rule (Part B, Data on screen): "Wherever the app shows IRIS 'saying' something outside a chat (Today card, tutor tab header, empty states) the text is a fixed template filled from real data or omitted. No generated copy outside the chat."
- Spec verification words for the release-binary scan: `Diego`, `Ana Ruiz`, `Lima`, `rampa`, `OPERACIONES`. Baseline measured 2026-09-07 on the current store artifacts (both platforms identical): Diego 8, Ana Ruiz 0, Lima 3, rampa 1, OPERACIONES 1. Target after this plan: 0 for all five.

---

## File structure

| File | Responsibility in this plan |
|---|---|
| `lib/testu/testu_live.dart` | Identity getters (`testuFirstName`, `testuFullName`, `testuInitials`, `testuEmail`), `testuOrganization` + `loadTestuOrganization()`, live default topic title. |
| `lib/testu/testu_client.dart` | Neutral minsur demo persona/org consts so the release binary carries no real name. |
| `lib/testu/testu_profile.dart` | `kInitialsAvatar` sentinel, `TestuAvatar` widget, live preset list, head (name, email · organisation), privacy copy. |
| `lib/testu/testu_widgets.dart` | `TestuCover` widget (server picture or flat brand block with initial). |
| `lib/testu/testu_shell.dart` | Today header: org line, greeting, avatar; hero cover. |
| `lib/testu/testu_tutor.dart` | Header, privacy note copy, greeting name, progress error + retry. |
| `lib/testu/testu_topics.dart` | Row and Topic Home covers, resources badge. |
| `lib/testu/testu_dashboard.dart` | Role eyebrow hidden live. |
| `lib/testu/testu_splash.dart`, `testu_session.dart`, `testu_social.dart`, `testu_lock.dart`, `testu_signin.dart` | One-line greeting / hint swaps. |
| `build_store.sh` | Comment documenting `TESTU_PRIVACY_URL`. |
| `test/testu_no_mock_test.dart` (new) | Getters, organisation, profile head, tutor error card, cover. |
| `test/testu_question_source_test.dart` | Neutral default topic. |

---

### Task 1: Identity getters, organisation store, neutral demo consts

**Files:**
- Modify: `lib/testu/testu_live.dart:11` (import), `:69-110` (auth section)
- Modify: `lib/testu/testu_client.dart:99-104`
- Create: `test/testu_no_mock_test.dart`

**Interfaces:**
- Consumes: `AuthService.currentUser` (`../eme_app_package/lib/services/auth_service.dart:96`, returns `User?` with `firstName`, `lastName`, `email` — `../eme_app_package/lib/models/user.dart`), `AuthService.http` (static `EmeHttp` seam, `auth_service.dart:16`), `client.persona` / `client.personaFull` (`lib/testu/testu_client.dart:55-56`).
- Produces (top-level in `testu_live.dart`): `String get testuFirstName`, `String get testuFullName`, `String get testuInitials`, `String get testuEmail`, `final ValueNotifier<String> testuOrganization`, `Future<void> loadTestuOrganization()`. Every later task uses these names.

- [ ] **Step 1: Write the failing tests**

Create `test/testu_no_mock_test.dart`:

```dart
import 'package:eme_app_package/models/workspace.dart';
import 'package:eme_app_package/services/auth_service.dart';
import 'package:eme_app_package/services/workspace_service.dart';
import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_live.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Part A of the Minsur pilot readiness spec: a live build shows the
/// signed-in learner and the server's data, never the demo persona.

/// Signs a fake learner in through the real AuthService, so the getters
/// under test read exactly what the app reads. Returns the fake transport
/// so a test can add more canned replies (me.json).
Future<FakeEmeHttp> signIn(Map<String, String> user) async {
  SharedPreferences.setMockInitialValues({});
  await WorkspaceService.init(
      initialWorkspace: Workspace(
          id: 'test', name: 'Test', mediaDBRoot: 'http://x/site/mediadb'));
  final http = FakeEmeHttp()
    ..canned['services/authentication/token.json'] = {
      'access_token': 't',
      'user': {'id': 'u1', ...user},
    }
    ..canned['services/server/list.json'] = {'servers': []};
  AuthService.http = http;
  expect(await AuthService.loginWithOtp(user['email']!, '000000'), isTrue);
  return http;
}

void main() {
  group('identity', () {
    tearDown(() async {
      await AuthService.logout();
      testuOrganization.value = '';
    });

    test('the name comes from the signed-in user', () async {
      await signIn({
        'firstname': 'Lucía',
        'lastname': 'Pérez',
        'email': 'lucia@x.com',
      });
      expect(testuFirstName, 'Lucía');
      expect(testuFullName, 'Lucía Pérez');
      expect(testuInitials, 'LP');
      expect(testuEmail, 'lucia@x.com');
    });

    test('a user without a name is greeted by their email, never by the demo persona',
        () async {
      await signIn({'firstname': '', 'lastname': '', 'email': 'lperez@x.com'});
      expect(testuFirstName, 'lperez');
      expect(testuFullName, 'lperez');
      expect(testuInitials, 'L');
    });

    test('organisation comes from me.json; a failed fetch leaves it empty',
        () async {
      final http = await signIn({
        'firstname': 'Lucía',
        'lastname': 'Pérez',
        'email': 'lucia@x.com',
      });
      await loadTestuOrganization(); // nothing canned -> 404 -> unchanged
      expect(testuOrganization.value, '');
      http.canned['services/testu/personas/me.json'] = {
        'user': {
          'id': 'u1',
          'email': 'lucia@x.com',
          'firstName': 'Lucía',
          'lastName': 'Pérez',
        },
        'role': 'users',
        'permissions': <String>[],
        'modules': <Map<String, Object>>[],
        'persona': {
          'name': 'IRIS',
          'avatar': '',
          'organization': 'Minsur',
          'language': 'es',
        },
      };
      await loadTestuOrganization();
      expect(testuOrganization.value, 'Minsur');
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_no_mock_test.dart`
Expected: compile error — `Undefined name 'testuOrganization'`, `testuFirstName`, `testuFullName`, `testuInitials`, `testuEmail`, `loadTestuOrganization`.

- [ ] **Step 3: Add the getters and the organisation store to `testu_live.dart`**

At `lib/testu/testu_live.dart:11` widen the foundation import:

```dart
import 'package:flutter/foundation.dart' show ValueNotifier, debugPrint;
```

Replace the four auth bodies `liveRestoreSession` … `liveSignOut` (`testu_live.dart:71-110`) with:

```dart
Future<bool> liveRestoreSession() async {
  await _init();
  if (AuthService.isLoggedIn) unawaited(loadTestuOrganization());
  return AuthService.isLoggedIn;
}

/// 'ok' | 'nouser' | 'error' — the server's own status word, or 'error'
/// when it could not be reached.
Future<String> liveSendUserCode(String email) async {
  await _init();
  try {
    final r = await AuthService.sendUserCode(email: email);
    return r['status']?.toString() ?? 'error';
  } catch (_) {
    return 'error';
  }
}

Future<bool> liveLoginWithOtp(String email, String code) async {
  await _init();
  try {
    final ok = await AuthService.loginWithOtp(email, code);
    if (ok) unawaited(loadTestuOrganization());
    return ok;
  } catch (_) {
    return false;
  }
}

Future<void> liveSignOut() async {
  await _init();
  await AuthService.logout();
  testuOrganization.value = '';
  // The socket is a singleton: left connected, the next user would hear
  // this user's tutor channel.
  ChatSocketService().disconnect();
  _tutorChannel = null;
  _tutorChannelId = null;
  _liveTutorialId = null;
  _liveTutorialTitle = null;
  _liveSections = const [];
  _liveQs = const [];
  _lastSectionId = null;
}
```

(`liveSendUserCode` and the tail of `liveSignOut` are unchanged; they are repeated so the block is one contiguous replacement.)

Then insert, after `liveSignOut` and before the `// ---- Data.` comment (`testu_live.dart:112`):

```dart
// ---- Who is signed in: the only source of a name in a live build.

/// First name for greetings. Live: the eMe user's first name, else the
/// part of their email before the @ (an account always has one); demo: the
/// client's persona. A live build never greets anyone by an invented name.
String get testuFirstName {
  if (!testuLive) return client.persona;
  final u = AuthService.currentUser;
  final first = u?.firstName.trim() ?? '';
  if (first.isNotEmpty) return first;
  final email = u?.email ?? '';
  final at = email.indexOf('@');
  return at > 0 ? email.substring(0, at) : client.persona;
}

/// Full name for the profile header; falls back to [testuFirstName].
String get testuFullName {
  if (!testuLive) return client.personaFull;
  final u = AuthService.currentUser;
  final full = '${u?.firstName ?? ''} ${u?.lastName ?? ''}'.trim();
  return full.isEmpty ? testuFirstName : full;
}

/// "LP" for Lucía Pérez, "L" for a lone name — the live avatar until the
/// learner adds a photo.
String get testuInitials => [
      for (final w in testuFullName.split(' '))
        if (w.isNotEmpty) w[0].toUpperCase(),
    ].take(2).join();

/// The signed-in learner's email; empty in the demo, which has no account.
String get testuEmail =>
    testuLive ? (AuthService.currentUser?.email ?? '') : '';

/// Organisation name from the tutor persona (`personas/me.json`), for the
/// Today header and the profile. Empty until it loads or when the server
/// has none; the screens then print nothing rather than a guess.
final testuOrganization = ValueNotifier<String>('');

/// Fetches [testuOrganization]. A failure leaves it as it was (the header
/// simply shows the date). Called after every successful sign-in/restore.
Future<void> loadTestuOrganization() async {
  try {
    final j =
        await AuthService.http.getJson('services/testu/personas/me.json');
    final p = j['persona'];
    testuOrganization.value =
        p is Map ? '${p['organization'] ?? ''}'.trim() : '';
  } catch (e) {
    debugPrint('TestU: me.json ($e)');
  }
}
```

`unawaited` comes from `dart:async`, already imported at `testu_live.dart:1`. `me.json` is learner-visible (`eme-plugin-testu/html/services/testu/personas/me.xconf` has `<permission name="view"><user/></permission>`) and returns `persona.organization` (see `me.groovy`).

- [ ] **Step 4: Neutralise the minsur demo persona and org line**

The live binary keeps every string of the `_minsur` const (it is referenced for `name`, `tutor`, `brand`…), so "Diego", "Diego San Jorge" and "Minsur · Lima" survive tree-shaking as long as they sit there. Replace `lib/testu/testu_client.dart:99-104`:

```dart
  // ponytail: neutral demo persona — the live build ships this const, so it
  // must carry no real name or invented office (Part A string scan). The
  // offline minsur demo (TESTU_LIVE=false) greets "Colaborador".
  persona: 'Colaborador',
  personaFull: 'Colaborador',
  personaAvatar: 'assets/img/p_diego.jpg',
  gender: 'm',
  orgEn: 'Minsur',
  orgEs: 'Minsur',
```

(`_vueling` at `:71-86` is untouched: it is dead code in a minsur build and the Vueling demo keeps its persona.)

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_no_mock_test.dart test/testu_client_test.dart`
Expected: `All tests passed!` (3 new + 2 existing).

- [ ] **Step 6: Analyze and leave uncommitted**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter analyze lib/testu/testu_live.dart lib/testu/testu_client.dart test/testu_no_mock_test.dart && git status --short lib/testu/testu_live.dart lib/testu/testu_client.dart test/testu_no_mock_test.dart`
Expected: `No issues found!`, the three files listed as ` M` / `??`. Do not commit.

---

### Task 2: Initials avatar and live profile head

**Files:**
- Modify: `lib/testu/testu_profile.dart:30-38` (presets), `:66-70` (restore), `:105-106` (`testuAvatarImage`), `:341-352` (privacy copy), `:443-452` (head avatar), `:460` (name), `:466-469` (sub line), `:582-584` (tile image)
- Modify: `lib/testu/testu_shell.dart:313-323` (header avatar)
- Test: `test/testu_no_mock_test.dart`

**Interfaces:**
- Consumes: `testuFullName`, `testuInitials`, `testuEmail`, `testuOrganization` (Task 1); `testuAvatar` / `testuAvatarLibrary` (`testu_profile.dart:24-28`); `client.brand` (`testu_client.dart:44`).
- Produces: `const String kInitialsAvatar = 'initials'` and `class TestuAvatar extends StatelessWidget { const TestuAvatar({super.key, required double size, String? src}) }` in `testu_profile.dart` (exported; `testu_shell.dart` already imports `testu_profile.dart`).

- [ ] **Step 1: Write the failing widget test**

Append inside the `identity` group of `test/testu_no_mock_test.dart` (after the organisation test), and add these imports at the top of the file:

```dart
import 'package:flutter/material.dart';
import 'package:genai_labs/testu/testu_profile.dart';
import 'package:genai_labs/testu/testu_theme.dart';
```

```dart
    testWidgets(
        'the profile shows the learner, their email · organisation, and initials for an avatar',
        (tester) async {
      await signIn({
        'firstname': 'Lucía',
        'lastname': 'Pérez',
        'email': 'lucia@x.com',
      });
      testuOrganization.value = 'Minsur';
      await tester.pumpWidget(
          MaterialApp(theme: testuTheme(), home: const TestuProfileScreen()));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Lucía Pérez'), findsOneWidget);
      expect(find.text('lucia@x.com · Minsur'), findsOneWidget);
      // Header avatar and the picker's first tile both draw the initials.
      expect(find.text('LP'), findsWidgets);
      expect(find.textContaining('Diego'), findsNothing);
      expect(find.textContaining('Safety Lead'), findsNothing);
      expect(find.textContaining('certification'), findsNothing);
    });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_no_mock_test.dart`
Expected: the new test fails — `find.text('lucia@x.com · Minsur')` finds nothing (head still prints `Operations · Safety Lead track · Minsur`), and `find.textContaining('Safety Lead')` finds one.

- [ ] **Step 3: Sentinel, presets and restore guard**

Replace `lib/testu/testu_profile.dart:30-38` (the `_presetAvatars` list):

```dart
/// Value of [testuAvatar] meaning "no photo — draw the learner's initials".
const kInitialsAvatar = 'initials';

final _presetAvatars = [
  // Live: nobody's stock photo — initials until the learner adds a photo.
  if (testuLive) kInitialsAvatar else client.personaAvatar,
  // ponytail: the prototype faces are demo-only; a live user adds their
  // own photo. Drops with the persona once profiles come from the server.
  if (!testuLive) ...[
    'assets/img/p_ana.jpg',
    'assets/img/p_laia.jpg',
    'assets/img/p_miranda.jpg',
  ],
];
```

In `restoreTestuAvatar` (`testu_profile.dart:66-70`) replace the restore condition so a live install that saved a bundled photo under the old build falls back to initials:

```dart
  final saved = prefs.getString(_kAvatarPref);
  if (saved != null &&
      (saved == kInitialsAvatar ||
          (!testuLive && saved.startsWith('assets/')) ||
          File(saved).existsSync())) {
    testuAvatar.value = saved;
  }
```

- [ ] **Step 4: The `TestuAvatar` widget**

Insert after `testuAvatarImage` (`testu_profile.dart:105-106`):

```dart
/// The learner's picture wherever it appears: their chosen photo, or — live,
/// before they add one — their initials on the brand colour.
class TestuAvatar extends StatelessWidget {
  const TestuAvatar({super.key, required this.size, this.src});

  final double size;

  /// A specific source (the picker's tiles); null follows [testuAvatar].
  final String? src;

  Widget _of(String s) => s == kInitialsAvatar
      ? Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration:
              BoxDecoration(shape: BoxShape.circle, color: client.brand),
          child: Text(testuInitials,
              style: TextStyle(
                  fontFamily: 'Sora',
                  fontWeight: FontWeight.w700,
                  fontSize: size * 0.36,
                  color: Colors.white)),
        )
      : ClipOval(
          child: Image(
              image: testuAvatarImage(s),
              width: size,
              height: size,
              fit: BoxFit.cover));

  @override
  Widget build(BuildContext context) => src != null
      ? _of(src!)
      : ValueListenableBuilder<String>(
          valueListenable: testuAvatar, builder: (_, s, _) => _of(s));
}
```

- [ ] **Step 5: Use it in the three places that drew the photo**

Profile head, `testu_profile.dart:443-452` — replace the `ValueListenableBuilder<String>(... ClipOval(... Image(...)))` block with:

```dart
          const TestuAvatar(size: 62),
```

Profile tile, `testu_profile.dart:582-584` — replace `child: ClipOval(child: Image(image: testuAvatarImage(src), fit: BoxFit.cover)),` (the child of the 46px bordered `Container`) with:

```dart
                child: TestuAvatar(size: 42, src: src),
```

Today header, `lib/testu/testu_shell.dart:313-323` — replace the `child: ValueListenableBuilder<String>(... ClipOval(... Image(image: testuAvatarImage(src), fit: BoxFit.cover)))` inside the 32px bordered `Container` with:

```dart
                  child: const TestuAvatar(size: 30),
```

`testuAvatarImage` is still used by `TestuAvatar` only; leave it.

- [ ] **Step 6: Head name and sub line**

`testu_profile.dart:460` — replace `client.personaFull,` with:

```dart
                  testuFullName,
```

`testu_profile.dart:466-469` — replace the `CL('Operations · Safety Lead track · ${client.orgEn}', …)` `Text` with a listener on the organisation:

```dart
                ValueListenableBuilder<String>(
                  valueListenable: testuOrganization,
                  builder: (_, org, _) => Text(
                    // Live: what the account and the server say, nothing
                    // more — email · organisation, or just the email.
                    testuLive
                        ? [testuEmail, org]
                            .where((s) => s.isNotEmpty)
                            .join(' · ')
                        : CL('Operations · Safety Lead track · ${client.orgEn}',
                            'Operaciones · Vía Líder de Seguridad · ${client.orgEs}',
                            'Ramp Agent · Safety Lead track · ${client.orgEn}',
                            'Agente de Rampa · Vía Líder de Seguridad · ${client.orgEs}'),
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 11,
                      height: 1.5,
                      color: t.mut,
                    ),
                  ),
                ),
```

(The `// No hand \n:` comment above the old `CL` moves with it or is dropped; the text still wraps naturally.)

- [ ] **Step 7: Privacy paragraph without the certification claim**

`testu_profile.dart:342-352` — replace the `L(...)` argument of the `Text` under `_H4(L('PRIVACY', 'PRIVACIDAD'))`:

```dart
              Text(
                testuLive
                    ? L('Your conversations with ${client.tutor} are private to you. Your '
                            'managers see readiness signals — never your chats, never '
                            'individual answers.',
                        'Tus conversaciones con ${client.tutor} son privadas. Tus '
                            'responsables ven señales de preparación — nunca tus '
                            'chats, nunca respuestas individuales.')
                    : L('Your conversations with ${client.tutor} are private to you. Your '
                            'managers see readiness signals and certification '
                            'status — never your chats, never individual answers.',
                        'Tus conversaciones con ${client.tutor} son privadas. Tus '
                            'responsables ven señales de preparación y estado de '
                            'certificación — nunca tus chats, nunca respuestas '
                            'individuales.'),
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_no_mock_test.dart test/testu_lock_test.dart`
Expected: `All tests passed!` — including `testu_lock_test.dart` "only added photos can be removed" (one initials tile without a badge, one photo with).

- [ ] **Step 9: Analyze and leave uncommitted**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter analyze lib/testu/testu_profile.dart lib/testu/testu_shell.dart && git status --short lib/testu/testu_profile.dart lib/testu/testu_shell.dart`
Expected: `No issues found!`; both files ` M`. Do not commit.

---

### Task 3: Greetings and the organisation line

**Files:**
- Modify: `lib/testu/testu_splash.dart:3-5` (imports), `:229-232`
- Modify: `lib/testu/testu_shell.dart:296-297`, `:333-334`
- Modify: `lib/testu/testu_tutor.dart:258`, `:350-352`
- Modify: `lib/testu/testu_session.dart:1613-1614`
- Modify: `lib/testu/testu_social.dart:4-9` (imports), `:93`, `:122`, `:768`
- Modify: `lib/testu/testu_lock.dart:8-12` (imports), `:339`

**Interfaces:**
- Consumes: `testuFirstName`, `testuFullName`, `testuOrganization`, `testuLive` from `testu_live.dart` (Task 1).
- Produces: nothing new. `_myShortName` (private, `testu_social.dart`).

- [ ] **Step 1: Splash — neutral live greeting, demo byte-identical**

Add `import 'testu_live.dart';` after `import 'testu_i18n.dart';` at `lib/testu/testu_splash.dart:4`. Replace `:229-232` (the `widget.welcomeBack ? L(...) : L(...)` expression):

```dart
                                  testuLive
                                      // Live: no gendered "bienvenido/a"
                                      // — the account carries no gender.
                                      ? (widget.welcomeBack
                                          ? L('$testuFirstName, welcome back.',
                                              'Hola de nuevo, $testuFirstName.')
                                          : L('$testuFirstName, welcome.',
                                              'Hola, $testuFirstName.'))
                                      : (widget.welcomeBack
                                          ? L('${client.persona}, welcome back.',
                                              '${client.persona}, ${G('bienvenido', 'bienvenida')} de nuevo.')
                                          : L('${client.persona}, welcome.',
                                              '${client.persona}, ${G('bienvenido', 'bienvenida')}.')),
```

- [ ] **Step 2: Today header — organisation from the server, greeting from the account**

`lib/testu/testu_shell.dart:296-297` — replace the `Text(L('${_today()} · ${client.orgEn}', '${_today()} · ${client.orgEs}'), style: kCardBody)` with:

```dart
                  child: ValueListenableBuilder<String>(
                    valueListenable: testuOrganization,
                    builder: (_, org, _) => Text(
                      testuLive
                          ? (org.isEmpty ? _today() : '${_today()} · $org')
                          : L('${_today()} · ${client.orgEn}',
                              '${_today()} · ${client.orgEs}'),
                      style: kCardBody,
                    ),
                  ),
```

`testu_shell.dart:333-334` — replace `${client.persona}` in both halves:

```dart
                    text: L('Good morning, $testuFirstName.\nHere’s what ',
                        'Buenos días, $testuFirstName.\nEsto es lo que ')),
```

Part B check (no code change): the tutor line under the greeting at `testu_shell.dart:358-362` already renders the fixed template `L('Pick up where you left off.', 'Retoma donde lo dejaste.')` when live and the hero below fills title/pill/tally from `primaryLiveTopic()`. Nothing generated; leave it.

- [ ] **Step 3: Tutor greetings**

`lib/testu/testu_tutor.dart:258`:

```dart
  final hi = L('Hello $testuFirstName. ', 'Hola, $testuFirstName. ');
```

`testu_tutor.dart:350-352` (demo greeting; identical output in demo, keeps the file free of `client.persona`):

```dart
          text: L('Hello $testuFirstName. Yesterday a misconception surfaced '
                  'on ',
              'Hola, $testuFirstName. Ayer apareció un concepto erróneo '
                  'sobre ')),
```

- [ ] **Step 4: Session debrief**

`lib/testu/testu_session.dart:1613-1614`:

```dart
              L('Here’s what today’s session means, $testuFirstName.',
                  'Esto es lo que significa la sesión de hoy, $testuFirstName.'),
```

- [ ] **Step 5: Social (demo-only today, hidden live at `testu_session.dart:1426` and `testu_topics.dart:486`)**

Add `import 'testu_live.dart';` after `import 'testu_i18n.dart';` at `lib/testu/testu_social.dart:4`. Add a top-level getter right after the imports:

```dart
/// "Lucía P." — how the learner's own comments are signed.
String get _myShortName =>
    '$testuFirstName ${testuFullName.split(' ').last[0]}.';
```

Then replace the three occurrences of `'${client.persona} ${client.personaFull.split(' ').last[0]}.'` at `testu_social.dart:93`, `:122` and `:768` with `_myShortName`. If `client` is no longer referenced anywhere else in the file after this, keep `import 'testu_client.dart';` only if `flutter analyze` does not flag it unused (it is still used at `:761`, `client.name == 'Minsur'`).

- [ ] **Step 6: Lock screen**

Add `import 'testu_live.dart';` after `import 'testu_icons.dart';` at `lib/testu/testu_lock.dart:10`. Replace `:339`:

```dart
                        Text(
                            testuLive
                                ? L('Welcome back, $testuFirstName',
                                    'Hola, $testuFirstName')
                                : L('Welcome back', 'Bienvenida de nuevo'),
                            style: kH1),
```

- [ ] **Step 7: Verify the persona no longer reaches any live screen**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && grep -n "client\.persona\b\|client\.personaFull\|client\.orgE" lib/testu/*.dart`
Expected: hits only in `testu_client.dart` (definitions), `testu_live.dart` (the getters' demo/fallback branches), `testu_splash.dart` (demo branch), `testu_shell.dart:296-297` region (demo branch), `testu_profile.dart` (demo branch of the sub line, `personaAvatar` in `_presetAvatars`), and `testu_schedule_sheet.dart:98,101,355,356` (demo-only sheet reachable from `_CertificationCard`, which `testu_shell.dart:202` hides live — left alone on purpose).

- [ ] **Step 8: Run the tests, analyze, leave uncommitted**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter analyze lib/testu && flutter test test/testu_no_mock_test.dart test/testu_client_test.dart test/testu_lock_test.dart test/testu_session_scroll_test.dart`
Expected: `No issues found!`, `All tests passed!` (the splash test still passes: with no user signed in, live falls back to "Colaborador, welcome." and the test only checks the logo). Do not commit.

---

### Task 4: Tutor tab — header, honest privacy note, progress error with retry

**Files:**
- Modify: `lib/testu/testu_tutor.dart:44-45` (state), `:74-91` (`_enter`), `:147-155` (build), `:207-213` (header), `:236-239` (privacy note)
- Test: `test/testu_no_mock_test.dart`

**Interfaces:**
- Consumes: `loadTutorProgress()` (`testu_live.dart:289`, `Future<TutorProgress?>`), `TestuAct` (`testu_widgets.dart:141`), `kMeta` (`testu_theme.dart:179`), `_liveGreeting` (`testu_tutor.dart:254`).
- Produces: `_progressFailed` state, `_progressError()` widget (both private).

- [ ] **Step 1: Write the failing widget test**

Append a second group to `test/testu_no_mock_test.dart` (outside `identity`; no sign-in, no logout tearDown), and add `import 'package:genai_labs/testu/testu_tutor.dart';` at the top:

```dart
  group('honest failures', () {
    testWidgets('the tutor tab says when progress cannot load and offers a retry',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: testuTheme(),
          home: Scaffold(
              body: TestuTutorScreen(active: true, onCalibration: () {}))));
      // No server in a test: the fetch fails (the test binding's HttpClient
      // answers 400) and the typing dots must give way to the error line,
      // not to "no answers yet". runAsync lets the real I/O settle.
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(
          find.text(
              'Could not load your progress. Check your connection and try again.'),
          findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining("I don't have any answers"), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_no_mock_test.dart --name "honest failures"`
Expected: FAIL — `find.text('Could not load your progress…')` finds nothing (today the failure is swallowed and the greeting says "I don't have any answers of yours yet").

- [ ] **Step 3: Track the failure and offer a retry**

`lib/testu/testu_tutor.dart:44-45` — after `bool _loadingProgress = false;` add:

```dart
  /// The last fetch threw and there is no earlier record to show.
  bool _progressFailed = false;
```

Replace the `if (testuLive) { … }` block in `_enter` (`testu_tutor.dart:79-90`):

```dart
    if (testuLive) {
      _loadingProgress = true;
      _progressFailed = false;
      loadTutorProgress().then((p) {
        if (!mounted) return;
        setState(() {
          _loadingProgress = false;
          if (p != null) _progress = p;
        });
      }).catchError((Object e) {
        debugPrint('TestU: tutor progress ($e)');
        if (mounted) {
          setState(() {
            _loadingProgress = false;
            _progressFailed = _progress == null;
          });
        }
      });
    }
```

In `build` (`testu_tutor.dart:147-155`) replace the `child:` expression of the `AnimatedOpacity`:

```dart
                  child: !testuLive
                      ? _demoGreeting(context, widget.onCalibration, _send)
                      : _loadingProgress && _progress == null
                          ? const SullyMessage.typing(
                              key: ValueKey('tutor-loading'),
                              avatar: false,
                              bottomPadding: 16)
                          : _progressFailed
                              ? _progressError()
                              : _liveGreeting(context, _progress,
                                  widget.onCalibration, _send),
```

Add the method to `_TestuTutorScreenState` (after `_scrollDown`, `testu_tutor.dart:121-125`), the dashboard's own copy and pattern (`testu_dashboard.dart:74-82`):

```dart
  /// Same words and retry as the dashboard's failed load — one honest
  /// line, never a greeting invented about a record that did not arrive.
  Widget _progressError() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              L('Could not load your progress. Check your connection and try again.',
                  'No se pudo cargar tu progreso. Revisa tu conexión e inténtalo de nuevo.'),
              style: kMeta),
          const SizedBox(height: 12),
          TestuAct(L('Try again', 'Reintentar'), onTap: _enter),
        ],
      );
```

`debugPrint` comes with `package:flutter/material.dart` (already imported at `:3`).

- [ ] **Step 4: Header = tutor name only; privacy note that we can keep**

`testu_tutor.dart:207-213` — wrap the org line so it is demo-only:

```dart
                  Text(client.tutor, style: kH1),
                  if (!testuLive) ...[
                    const SizedBox(height: 2),
                    Text(
                        CL('Tutor ${client.name} Operations',
                            'Tutor ${client.name} Operaciones',
                            'Tutor ${client.name} Ground Operations',
                            'Tutor ${client.name} Operaciones en Tierra'),
                        style: kLabel),
                  ],
```

`testu_tutor.dart:236-239` — replace the `L(...)` in `_PrivacyNote`:

```dart
        testuLive
            ? L('Private to you. ${client.tutor} answers with the source when it finds one; '
                    'when it does not, it says so. Your managers see readiness signals — never this conversation.',
                'Privado para ti. ${client.tutor} responde con la fuente cuando la encuentra; '
                    'si no la encuentra, te lo dice. Tus responsables ven señales de preparación — nunca esta conversación.')
            : L('Private to you. ${client.tutor}’s answers always cite their sources. '
                    'Your managers see readiness signals — never this conversation.',
                'Privado para ti. Las respuestas de ${client.tutor} siempre citan sus fuentes. '
                    'Tus responsables ven señales de preparación — nunca esta conversación.'),
```

Part B check (no further change): the live greeting `_liveGreeting` (`testu_tutor.dart:254-321`) is a fixed template filled from `TutorProgress` (last section, weakest section, tally) — that is the rule. The header now shows only `client.tutor` ("IRIS").

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_no_mock_test.dart test/testu_tutor_progress_test.dart`
Expected: `All tests passed!`

- [ ] **Step 6: Analyze and leave uncommitted**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter analyze lib/testu/testu_tutor.dart && git status --short lib/testu/testu_tutor.dart`
Expected: `No issues found!`; ` M lib/testu/testu_tutor.dart`. Do not commit.

---

### Task 5: Role eyebrow, resources badge, neutral default topic

**Files:**
- Modify: `lib/testu/testu_dashboard.dart:318-323`
- Modify: `lib/testu/testu_topics.dart:908`, `:1602-1613` and `:1640-1656` (`_ResRow`)
- Modify: `lib/testu/testu_live.dart:131-132` (`EmeQuestionSource.topic`)
- Test: `test/testu_question_source_test.dart`

**Interfaces:**
- Consumes: `EmeQuestionSource` (`testu_live.dart:119`), `_ResRow` (`testu_topics.dart:1601`).
- Produces: `_ResRow.required` becomes `bool?` (null = no badge).

- [ ] **Step 1: Write the failing test for the default topic**

Add to `test/testu_question_source_test.dart`, right after the `setUp` block (before `test('walks topics -> …')`):

```dart
  test('before anything loads the topic is a neutral word, not the prototype\'s',
      () {
    expect(source.topic, 'Topic');
  });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_question_source_test.dart --name "neutral word"`
Expected: FAIL — `Expected: 'Topic' Actual: 'Ramp Safety'`.

- [ ] **Step 3: Live default topic title**

`lib/testu/testu_live.dart:131-132` — replace the `topic` override in `EmeQuestionSource`:

```dart
  /// The loaded topic's title; before a load, a neutral word — never the
  /// prototype's "Ramp Safety".
  @override
  String get topic => _topic ?? L('Topic', 'Tema');
```

`TestuQuestionSource.topic` at `testu_question_source.dart:79` stays: it is the demo `LocalQuestionSource`'s default and is unreachable in a live build (the only live source now overrides it without calling `super`). Task 8's scan confirms "rampa" is gone from the binary.

- [ ] **Step 4: Role eyebrow hidden live**

`lib/testu/testu_dashboard.dart:318-323` — wrap the eyebrow and its spacer:

```dart
        children: [
          if (!testuLive) ...[
            TestuEyebrow.h4(
                CL('ROLE READINESS · OPERATIONS, SAFETY LEAD',
                    'PREPARACIÓN DEL ROL · OPERACIONES',
                    'ROLE READINESS · RAMP AGENT, SAFETY LEAD',
                    'PREPARACIÓN DEL ROL · AGENTE DE RAMPA')),
            const SizedBox(height: 12),
          ],
          Row(
```

- [ ] **Step 5: Resources badge only when the server says so**

`lib/testu/testu_topics.dart:1602-1613` — make the flag optional:

```dart
  const _ResRow(
      {required this.icon,
      required this.title,
      required this.sub,
      this.required,
      required this.onTap});

  final String icon;
  final String title;
  final String sub;

  /// true = REQUIRED, false = OPTIONAL, null = the source has no such
  /// flag, so no badge (the server does not send one yet).
  final bool? required;
  final VoidCallback onTap;
```

`testu_topics.dart:1639-1656` — replace `const SizedBox(width: 10),` and the badge `Container(...)` that follows it with a null-guarded pair:

```dart
            if (required != null) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 7),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: required! ? t.amberBorder : t.line2),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                    required!
                        ? L('REQUIRED', 'OBLIGATORIO')
                        : L('OPTIONAL', 'OPCIONAL'),
                    style: TextStyle(
                        fontFamily: 'GeistMono',
                        fontWeight: FontWeight.w500,
                        fontSize: 8.5,
                        letterSpacing: 0.85,
                        color: required! ? t.amber : t.mut)),
              ),
            ],
```

`testu_topics.dart:908` (the live `_ResRow` inside the `FutureBuilder<List<LiveDoc>>`) — delete the line `required: true,` (the demo rows at `:932`, `:939`, `:948` keep their explicit `true`/`false`).

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_question_source_test.dart test/testu_no_mock_test.dart`
Expected: `All tests passed!`

- [ ] **Step 7: Analyze and leave uncommitted**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter analyze lib/testu/testu_dashboard.dart lib/testu/testu_topics.dart lib/testu/testu_live.dart && git status --short lib/testu/testu_dashboard.dart lib/testu/testu_topics.dart lib/testu/testu_live.dart test/testu_question_source_test.dart`
Expected: `No issues found!`; four files ` M`. Do not commit.

---

### Task 6: Neutral covers

**Files:**
- Modify: `lib/testu/testu_widgets.dart:6-7` (imports), after `testuImage` (`:11-12`)
- Modify: `lib/testu/testu_topics.dart:150-151`, `:255-258`, `:372-373`, `:1030-1032`
- Modify: `lib/testu/testu_shell.dart:505-519`
- Test: `test/testu_no_mock_test.dart`

**Interfaces:**
- Consumes: `testuImage` (`testu_widgets.dart:11`), `client.brand`, `LiveTopicHead.img` / `.title` (`testu_topics.dart:156-165`), `_Topic.img` / `.title` (`testu_topics.dart:21-30`), `TestuTopicHomeScreen.img` / `.title` (`testu_topics.dart:412`, `:420`).
- Produces: `class TestuCover extends StatelessWidget { const TestuCover({super.key, ImageProvider? image, required String title, Alignment alignment = Alignment.center}) }` in `testu_widgets.dart`; `_topicImage` returns `ImageProvider?` (null for `''`).

- [ ] **Step 1: Write the failing widget test**

Append to the `honest failures` group in `test/testu_no_mock_test.dart`, and add `import 'package:genai_labs/testu/testu_widgets.dart';` at the top:

```dart
    testWidgets('a topic without a picture gets a flat block with its initial',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: testuTheme(),
          home: const Center(
              child: SizedBox(
                  width: 100,
                  height: 100,
                  child: TestuCover(title: 'derechos humanos')))));
      expect(find.text('D'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });
```

- [ ] **Step 2: Run it to verify it fails**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_no_mock_test.dart --name "flat block"`
Expected: compile error — `The name 'TestuCover' isn't a class`.

- [ ] **Step 3: The `TestuCover` widget**

In `lib/testu/testu_widgets.dart` add `import 'testu_client.dart';` after `import 'testu_icons.dart';` (`:6`), then insert after `testuImage` (`:11-12`):

```dart
/// A topic's cover: its picture from the server, or — when there is none —
/// a flat block in the brand colour with the title's initial. Never a stock
/// photo standing in for a topic it does not show.
class TestuCover extends StatelessWidget {
  const TestuCover(
      {super.key,
      this.image,
      required this.title,
      this.alignment = Alignment.center});

  final ImageProvider? image;
  final String title;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image != null) {
      return Image(image: image, fit: BoxFit.cover, alignment: alignment);
    }
    final t = title.trim();
    return Container(
      color: client.brand,
      alignment: Alignment.center,
      // Scales with the box: a 52px thumbnail and a 300px hero share it.
      child: FractionallySizedBox(
        heightFactor: 0.4,
        child: FittedBox(
          child: Text(t.isEmpty ? '' : t[0].toUpperCase(),
              style: const TextStyle(
                  fontFamily: 'Sora',
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Topics list — no bundled fallback live**

`lib/testu/testu_topics.dart:150-151` — `_topicImage` becomes nullable:

```dart
/// `img` is a bundled file name for prototype rows, an absolute URL for
/// live ones, and '' for a live topic with no picture (no cover).
ImageProvider? _topicImage(String img) => img.isEmpty
    ? null
    : testuImage(img.startsWith('http') ? img : 'assets/img/$img');
```

`testu_topics.dart:255-258` in `_mapTopic` — no stock picture for a live topic:

```dart
    img: t.thumbnail.isEmpty
        ? ''
        : liveAssetUrl(
            t.thumbnail.replaceFirst('image200x200', 'image3000x3000')),
```

`testu_topics.dart:372-373` in `_TopicRow` — replace `child: Image(image: _topicImage(topic.img), fit: BoxFit.cover),`:

```dart
                child: TestuCover(
                    image: _topicImage(topic.img), title: topic.title),
```

`testu_topics.dart:1030-1032` in `_TopicHero` — replace the `Image(image: _topicImage(home.img), fit: BoxFit.cover, alignment: const Alignment(0, 0.24))`:

```dart
          TestuCover(
              image: _topicImage(home.img),
              title: home.title ?? '',
              alignment: const Alignment(0, 0.24)), // center 62%
```

The `_imgs` list at `testu_topics.dart:145-146` now feeds only the demo rows; leave it (the comment above it, "else a bundled picture", becomes "else no picture" — update the comment).

- [ ] **Step 5: Today hero**

`lib/testu/testu_shell.dart:505-519` — replace the `Positioned.fill(child: head == null ? Image.asset(...) : Image(...))`:

```dart
                Positioned.fill(
                  child: head == null
                      ? (testuLive
                          // Live with no topic: the brand block, no mine.
                          ? const TestuCover(title: '')
                          : Image.asset(
                              client.name == 'Minsur'
                                  ? 'assets/img/mine_hero.jpg'
                                  : 'assets/img/ramp.jpg',
                              fit: BoxFit.cover,
                              alignment: const Alignment(0, 0.44), // center 72%
                            ))
                      : TestuCover(
                          image: head.img.isEmpty ? null : testuImage(head.img),
                          title: head.title,
                          alignment: const Alignment(0, 0.44),
                        ),
                ),
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter test test/testu_no_mock_test.dart test/testu_client_test.dart`
Expected: `All tests passed!`

- [ ] **Step 7: Analyze and leave uncommitted**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter analyze lib/testu/testu_widgets.dart lib/testu/testu_topics.dart lib/testu/testu_shell.dart && git status --short lib/testu/testu_widgets.dart lib/testu/testu_topics.dart lib/testu/testu_shell.dart`
Expected: `No issues found!`; three files ` M`. Do not commit.

---

### Task 7: Sign-in hint and the privacy URL note

**Files:**
- Modify: `lib/testu/testu_signin.dart:10`, `:240-241`
- Modify: `build_store.sh:13`

**Interfaces:**
- Consumes: `testuLive`, `testuPrivacyUrl` (`testu_live.dart:26`, `:32`).
- Produces: nothing.

- [ ] **Step 1: Neutral hint live**

`lib/testu/testu_signin.dart:10` — widen the import:

```dart
import 'testu_live.dart' show testuLive, testuPrivacyUrl;
```

`testu_signin.dart:240-241`:

```dart
                  decoration: testuFieldDecoration(t,
                      hint: testuLive
                          ? 'correo@empresa.com'
                          : 'ana.ruiz@${client.wordmark}.com'),
```

- [ ] **Step 2: Document the privacy define where the build is cut**

`build_store.sh:13` — insert above the `D=` line:

```sh
# Privacy policy link (profile + sign-in): append
#   --dart-define=TESTU_PRIVACY_URL=https://<page>
# to D once the GenAI Labs page exists. Empty = the rows stay hidden
# (testu_live.dart: testuPrivacyUrl), which is the code's default.
```

No define is added now: the page does not exist and the code already hides the rows (`testu_profile.dart:359`, `testu_signin.dart` uses the same const).

- [ ] **Step 3: Analyze and leave uncommitted**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter analyze lib/testu/testu_signin.dart && sh -n build_store.sh && git status --short lib/testu/testu_signin.dart build_store.sh`
Expected: `No issues found!`, no shell syntax error, both files ` M`. Do not commit.

---

### Task 7b: Gender-neutral Spanish in live builds

**Files:**
- Modify: `lib/testu/testu_i18n.dart:26-32` (`testuGender`, `G()`)
- Test: `test/testu_no_mock_test.dart` (append one group)

**Interfaces:**
- Consumes: `testuLive` (`lib/testu/testu_live.dart`), `testuGender` and `G(String masc, String fem)` (`testu_i18n.dart:28,32`).
- Produces: in a live build `G('seguro', 'segura')` returns `seguro/a`; demo behaviour unchanged. No call site changes: all 19 `G(...)` sites (`testu_splash.dart:230,232`, `testu_topics.dart:1206`, `testu_session.dart:47,50,537,545,564,593,1117,1742`, `testu_question_source.dart:143,184,242`, `testu_dashboard.dart:283,663,668,679,684`) pass pairs that differ only in the last letter, which is what the slash form needs.

Why: the demo client hardcodes `gender: 'm'`, so a live build would address every learner in the masculine ("¿Cuán seguro estás?"). Accounts carry no gender field, and asking for one is not in the spec. The written slash form ("seguro/a") is the standard neutral in Peruvian corporate Spanish and costs one line.

- [ ] **Step 1: Write the failing test**

Append to `test/testu_no_mock_test.dart`:

```dart
group('G() in live builds', () {
  test('returns the slash form, demo keeps the persona gender', () {
    if (testuLive) {
      expect(G('seguro', 'segura'), 'seguro/a');
      expect(G('SEGURO', 'SEGURA'), 'SEGURO/A');
      expect(G('Preparado', 'Preparada'), 'Preparado/a');
    } else {
      testuGender.value = 'f';
      expect(G('seguro', 'segura'), 'segura');
      testuGender.value = 'm';
      expect(G('seguro', 'segura'), 'seguro');
    }
  });
});
```

Add `import 'package:genai_labs/testu/testu_i18n.dart';` at the top if it is not already there.

- [ ] **Step 2: Run it to verify it fails in the live configuration**

Run: `flutter test test/testu_no_mock_test.dart --dart-define=TESTU_LIVE=true --plain-name 'G() in live builds'`
Expected: FAIL, `Expected: 'seguro/a' Actual: 'seguro'`.

- [ ] **Step 3: Implement**

Replace `testu_i18n.dart:32` with:

```dart
/// Live accounts carry no gender, so a live build writes the neutral slash
/// form ("seguro/a"); every call site passes a pair that differs only in
/// the last letter. ponytail: one line instead of 19 neutral rewrites;
/// switch on a profile field when accounts get one.
String G(String masc, String fem) => testuLive
    ? '$masc/${fem.substring(fem.length - 1)}'
    : (testuGender.value == 'f' ? fem : masc);
```

Add `import 'testu_live.dart';` to `testu_i18n.dart` if missing (check for an import cycle: `testu_live.dart` must not import `testu_i18n.dart`; if it does, move `testuLive` reading behind `const bool.fromEnvironment('TESTU_LIVE')` directly in `G()`).

- [ ] **Step 4: Run both configurations**

Run: `flutter test test/testu_no_mock_test.dart --dart-define=TESTU_LIVE=true --plain-name 'G() in live builds'` then `flutter test test/testu_no_mock_test.dart --plain-name 'G() in live builds'`
Expected: PASS in both.

- [ ] **Step 5: Leave uncommitted for the user**

---

### Task 8: Verification — suite, store artifacts, binary scan, simulator walk

**Files:** none modified (read-only checks; `ios/Runner.xcodeproj/project.pbxproj` restored if a build touched it).

**Interfaces:**
- Consumes: everything above; `build_store.sh` (run by the user), `build/app/outputs/bundle/release/app-release.aab`, `build/ios/archive/Runner.xcarchive`.

- [ ] **Step 1: Whole suite and analyzer**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && flutter analyze && flutter test`
Expected: `No issues found!` and `All tests passed!` (the golden shot suites are skipped by default and stay skipped).

- [ ] **Step 2: Ask the user to rebuild both store artifacts**

Do not run it yourself. Ask: "Please run `./build_store.sh` in `app-genailabs` (it builds the .aab and the unsigned .xcarchive with `TESTU_CLIENT=minsur TESTU_LIVE=true TESTU_MEDIADB=https://minsur.genailabs.tech/site/mediadb`), then tell me when it has finished." Wait for the answer before Step 3.

- [ ] **Step 3: String scan of both binaries**

Run:

```bash
cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs"
AAB=build/app/outputs/bundle/release/app-release.aab
IOS=build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app/Frameworks/App.framework/App
ls -la "$AAB" "$IOS"
for w in Diego "Ana Ruiz" Lima rampa OPERACIONES; do
  printf '%-12s aab=%s ios=%s\n' "$w" \
    "$(unzip -p "$AAB" base/lib/arm64-v8a/libapp.so | strings | grep -c -- "$w")" \
    "$(strings "$IOS" | grep -c -- "$w")"
done
```

Expected (both artifacts newer than the plan's edits, and):

```
Diego        aab=0 ios=0
Ana Ruiz     aab=0 ios=0
Lima         aab=0 ios=0
rampa        aab=0 ios=0
OPERACIONES  aab=0 ios=0
```

Baseline before this plan was `Diego 8 / Ana Ruiz 0 / Lima 3 / rampa 1 / OPERACIONES 1` on both. If any count is non-zero, print the offending lines (`strings "$IOS" | grep -- "<word>"`) and trace each to its source: a surviving `rampa` means `TestuQuestionSource.topic`'s base body was kept — in that case change `lib/testu/testu_question_source.dart:79` to `String get topic => testuLive ? L('Topic', 'Tema') : L('Ramp Safety', 'Seguridad en rampa');` with `import 'testu_live.dart' show testuLive;`, ask for a rebuild, and rescan.

- [ ] **Step 4: pbxproj check**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && grep -n "objectVersion" ios/Runner.xcodeproj/project.pbxproj && git diff --stat -- ios/Runner.xcodeproj/project.pbxproj`
Expected: `objectVersion = 60;` and no diff. If the diff is only `60` → `54`: `git checkout -- ios/Runner.xcodeproj/project.pbxproj` and re-check.

- [ ] **Step 5: Simulator walk as the test learner**

Run the live app against the local server (`./run_minsur.sh` — the user's usual dev loop; do not use `build_store.sh`), sign in as `testuser@eme.world` with OTP `666666`, and check, tab by tab:

1. Splash: "`<first name>`, welcome." / "Hola, `<first name>`." — no gendered word, no "Diego".
2. Today: date line reads `<date> · <organisation>` (or just the date while `me.json` is out / empty); greeting "Buenos días, `<first name>`."; header avatar is initials on the brand colour; tutor line "Retoma donde lo dejaste."; hero shows the server cover or the flat block with the topic initial — never the mine photo.
3. Temas: rows without a server thumbnail show the flat block; a Topic Home's resources show no REQUIRED/OPTIONAL badge; the Topic Home header has no photo fallback.
4. IRIS tab: header is "IRIS" alone; privacy note reads "Responde con la fuente cuando la encuentra; si no la encuentra, te lo dice."; kill the server (or airplane mode) and re-enter the tab: error line + "Reintentar", tap it after restoring the connection and the greeting loads.
5. Dashboard: readiness card has no "PREPARACIÓN DEL ROL · OPERACIONES" eyebrow.
6. Profile: full name from the account, `email · organisation`, initials avatar as the first tile, privacy paragraph without "certificación"; sign out.
7. Sign-in: hint reads `correo@empresa.com`. Lock screen (enable Face ID in profile first, background the app > 15 s): "Hola, `<first name>`".

Record anything that still shows invented text as a finding for the user; do not widen the plan.

- [ ] **Step 6: Final state**

Run: `cd "/Users/DSANJORGE/Code/EME-GenAI Labs/app-genailabs" && git status --short`
Expected: tonight's 25 pre-existing modified files plus the files this plan touched (`lib/testu/testu_live.dart`, `testu_client.dart`, `testu_profile.dart`, `testu_widgets.dart`, `testu_shell.dart`, `testu_tutor.dart`, `testu_topics.dart`, `testu_dashboard.dart`, `testu_splash.dart`, `testu_session.dart`, `testu_social.dart`, `testu_lock.dart`, `testu_signin.dart`, `build_store.sh`, `test/testu_question_source_test.dart`, new `test/testu_no_mock_test.dart`). Leave everything uncommitted for the user.

---

## Self-review against the spec

- Table row `testu_client.dart:99-107` → Task 1 (getters, six call sites in Tasks 2–3, initials avatar in Task 2).
- Row `testu_profile.dart:469-473, :341-348` → Task 2 Steps 6–7 (email · organisation; certification claim dropped; the notification "certification deadlines" rows were already hidden live at `:301-305`). Spec says "team": `me.json` returns no team field (`me.groovy`), so the line shows the organisation — the same field the console uses.
- Row `testu_shell.dart:296`, `testu_dashboard.dart:320-323`, `testu_tutor.dart:210-213` → Task 3 Step 2, Task 5 Step 4, Task 4 Step 4.
- Row `testu_shell.dart:502-508`, `testu_topics.dart:145,255` → Task 6.
- Row `testu_topics.dart:908` → Task 5 Step 5 (badge omitted, not flipped to "OPTIONAL").
- Row `testu_tutor.dart:79-90,254-274` → Task 4 Steps 1–3.
- Row `testu_tutor.dart:236-239` → Task 4 Step 4.
- Row `testu_signin.dart:241` → Task 7 Step 1.
- Row `testu_lock.dart:339` → Task 3 Step 6.
- Row `testu_question_source.dart:79` → Task 5 Step 3.
- Row `build_store.sh` → Task 7 Step 2.
- Verification paragraph → Task 8 (the "existing string scan" did not exist as a script; Step 3 is the scan, with the measured baseline).
- Part B "Data on screen" for the Today card and tutor header → Task 3 Step 2 and Task 4 Step 4 (fixed templates only; nothing generated).
- Out of scope, flagged for the user: `testuGender` (`testu_i18n.dart:28`) still feeds gendered Spanish inside sessions ("¿Cuán seguro estás?") from the client's `gender: 'm'`; the account has no gender field. Not in the spec table; left as is.
