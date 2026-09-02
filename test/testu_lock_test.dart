import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_lock.dart';
import 'package:genai_labs/testu/testu_profile.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:local_auth_platform_interface/local_auth_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Biometric unlock: the branches that decide whether someone gets into the
/// app. A wrong answer here either strands the user outside a session they
/// paid for with a code, or opens the app to whoever picks up the phone.

class _FakeLocalAuth extends LocalAuthPlatform {
  _FakeLocalAuth({this.enrolled = const [BiometricType.face], this.pass = true});

  final List<BiometricType> enrolled;
  final bool pass;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    required Iterable<AuthMessages> authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async =>
      pass;

  @override
  Future<List<BiometricType>> getEnrolledBiometrics() async => enrolled;

  @override
  Future<bool> deviceSupportsBiometrics() async => enrolled.isNotEmpty;

  @override
  Future<bool> isDeviceSupported() async => true;
}

Widget _app(Widget home) => MaterialApp(theme: testuTheme(), home: home);

void main() {
  tearDown(() => LocalAuthPlatform.instance = _FakeLocalAuth());

  test('a sensor that stopped existing unlocks the app instead of sealing it',
      () async {
    // Enrolment can vanish between runs (new phone, Face ID reset). Keeping
    // the flag would leave the session unreachable behind a prompt that can
    // never succeed.
    SharedPreferences.setMockInitialValues({'testu_lock_on': true});
    LocalAuthPlatform.instance = _FakeLocalAuth(enrolled: const []);
    await TestuLock.restore();
    expect(TestuLock.available, isFalse);
    expect(TestuLock.enabled, isFalse);
  });

  test('the setting survives a restart, and turning it on requires the sensor',
      () async {
    SharedPreferences.setMockInitialValues({});
    LocalAuthPlatform.instance = _FakeLocalAuth();
    await TestuLock.restore();
    expect(TestuLock.enabled, isFalse);
    expect(await TestuLock.setEnabled(true), isTrue);

    await TestuLock.restore();
    expect(TestuLock.enabled, isTrue, reason: 'must persist across launches');

    // A refused check leaves it exactly as it was.
    LocalAuthPlatform.instance = _FakeLocalAuth(pass: false);
    await TestuLock.setEnabled(false); // off never needs the sensor
    expect(await TestuLock.setEnabled(true), isFalse);
    expect(TestuLock.enabled, isFalse);
  });

  test('signing out hands the phone over clean', () async {
    SharedPreferences.setMockInitialValues({});
    LocalAuthPlatform.instance = _FakeLocalAuth();
    await TestuLock.restore();
    await TestuLock.setEnabled(true);
    await TestuLock.markOffered();

    await TestuLock.reset();
    expect(TestuLock.enabled, isFalse);
    expect(TestuLock.offered, isFalse, reason: 'next user gets asked again');
  });

  testWidgets('the lock screen always offers a way in without the sensor',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalAuthPlatform.instance = _FakeLocalAuth(pass: false);
    await TestuLock.restore();

    var unlocked = false;
    await tester.pumpWidget(
        _app(TestuLockScreen(onUnlocked: () => unlocked = true)));
    await tester.pump(); // the automatic prompt on arrival fails

    expect(unlocked, isFalse);
    expect(find.text('Use an email code instead'), findsOneWidget);

    // Retrying with a sensor that cooperates gets in. The label follows the
    // platform's own name for the sensor, so ask for it rather than guess.
    LocalAuthPlatform.instance = _FakeLocalAuth();
    await tester.tap(find.text('UNLOCK WITH ${TestuLock.name.toUpperCase()}'));
    await tester.pump();
    expect(unlocked, isTrue);
  });

  testWidgets('only added photos can be removed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    LocalAuthPlatform.instance = _FakeLocalAuth();
    await TestuLock.restore();

    // A real file: the tile renders it, so a missing path would fail the pump.
    final photo = File('${Directory.systemTemp.path}/testu_avatar_test.jpg')
      ..writeAsBytesSync(
          File('assets/img/p_ana.jpg').readAsBytesSync());
    addTearDown(() {
      if (photo.existsSync()) photo.deleteSync();
      testuAvatarLibrary.value = const [];
    });
    testuAvatarLibrary.value = [photo.path];

    await tester.pumpWidget(_app(const TestuProfileScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    // Three bundled presets carry no remove badge; the added photo does.
    expect(find.text('✕'), findsOneWidget);
  });
}
