import 'dart:io';

import 'package:eme_app_package/models/workspace.dart';
import 'package:eme_app_package/services/auth_service.dart';
import 'package:eme_app_package/services/workspace_service.dart';
import 'package:eme_app_package/testing/fake_eme_http.dart';
import 'package:eme_app_package/utils/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_client.dart';
import 'package:genai_labs/testu/testu_i18n.dart';
import 'package:genai_labs/testu/testu_live.dart';
import 'package:genai_labs/testu/testu_profile.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:genai_labs/testu/testu_tutor.dart';
import 'package:genai_labs/testu/testu_widgets.dart';
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
    // ponytail: skip AuthService.logout() here — it calls DioUtil.clearCookies(),
    // whose cookie jar is never initialized in a unit test (no DioUtil.init()),
    // which prints noisy non-fatal errors. Each test's signIn() fully
    // re-authenticates via loginWithOtp(), so AuthService's static session
    // fields never leak between tests; only the standalone testuOrganization
    // notifier needs a manual reset.
    // This group leaves AuthService signed in with a FakeEmeHttp for the
    // rest of this file; the later groups below don't read AuthService state.
    tearDown(() {
      testuOrganization.value = '';
    });

    test('the name comes from the signed-in user', () async {
      await signIn({
        'firstname': 'Lucía',
        'lastname': 'Pérez',
        'email': 'lucia@x.com',
      });
      if (testuLive) {
        expect(testuFirstName, 'Lucía');
        expect(testuFullName, 'Lucía Pérez');
        expect(testuInitials, 'LP');
        expect(testuEmail, 'lucia@x.com');
      } else {
        expect(testuFirstName, client.persona);
        expect(testuFullName, client.personaFull);
        expect(testuEmail, '');
      }
    });

    test('a user without a name is greeted by their email, never by the demo persona',
        () async {
      await signIn({'firstname': '', 'lastname': '', 'email': 'lperez@x.com'});
      if (testuLive) {
        expect(testuFirstName, 'lperez');
        expect(testuFullName, 'lperez');
        expect(testuInitials, 'L');
      } else {
        expect(testuFirstName, client.persona);
        expect(testuFullName, client.personaFull);
      }
    });

    test('organisation comes from me.json; a failed fetch leaves it empty',
        () async {
      final http = await signIn({
        'firstname': 'Lucía',
        'lastname': 'Pérez',
        'email': 'lucia@x.com',
      });
      // loadTestuOrganization() debugPrint('TestU: me.json (...)') on the
      // 404 below — debugPrint is Flutter's officially-reassignable global,
      // so silence it for this call rather than let it clutter test output.
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};
      try {
        await loadTestuOrganization(); // nothing canned -> 404 -> unchanged
      } finally {
        debugPrint = originalDebugPrint;
      }
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
  });

  group('honest failures', () {
    // TestuTutorScreen loads its progress through loadTutorProgress(), which
    // calls the internal, un-overridable TopicService()/DioEmeHttp() — there
    // is no seam here to hand it a FakeEmeHttp. So this group runs the same
    // bootstrap AuthService.init() does at real app startup (WorkspaceService
    // + DioUtil), minus sign-in, so that DioEmeHttp's Dio field is actually
    // set. Without it, the very first request throws LateInitializationError
    // on the unset field instead of exercising a real failure. DioUtil.init()
    // persists cookies via path_provider; fake that channel so it succeeds
    // quietly rather than falling back with its own non-fatal log.
    setUp(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (call) async => Directory.systemTemp.path,
      );
      SharedPreferences.setMockInitialValues({});
      await WorkspaceService.init(
          initialWorkspace: Workspace(
              id: 'test', name: 'Test', mediaDBRoot: 'http://x/site/mediadb'));
      await DioUtil.init();
    });

    testWidgets('the tutor tab says when progress cannot load and offers a retry',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: testuTheme(),
          home: Scaffold(
              body: TestuTutorScreen(active: true, onCalibration: () {}))));
      // No server in a test: with a real, initialised Dio, the request
      // actually reaches flutter_test's HttpOverrides, whose HttpClient
      // answers every request with an empty 400 (never real network) — so
      // the fetch fails and the typing dots must give way to the error
      // line, not to "no answers yet". DioEmeHttp logs one non-fatal error
      // per failed call by design (its doc comment: "every failure is
      // recorded ... exactly once, in here, before throwing"), plus
      // TestuTutorScreen's own one-line "TestU: tutor progress (...)" log —
      // both route through Flutter's global debugPrint variable (officially
      // reassignable from tests), so silence it around the settle below
      // (restored in `finally`, before this testWidgets body returns, since
      // flutter_test asserts debug vars are back to normal at the end of
      // each widget test — a `tearDown`-based restore runs too late for
      // that check). A plain pump() (or a fixed loop of them) doesn't drain
      // this chain reliably — pumpAndSettle does.
      final originalDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {};
      try {
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      } finally {
        debugPrint = originalDebugPrint;
      }
      expect(
          find.text(
              'Could not load your progress. Check your connection and try again.'),
          findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining("I don't have any answers"), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

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
  });

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
}
