import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_signin.dart';
import 'package:genai_labs/admin/admin_theme.dart';
import 'package:genai_labs/testu/testu_widgets.dart';
import 'package:genai_labs/testu/testu_theme.dart';

/// The one screen every console user meets before the console exists: two
/// stages, no self-service, and no dead end -- a wrong email or a code that
/// never arrived has to be recoverable without a page reload.

/// Records what the screen asked the server for, so a "Resend code" that
/// quietly does nothing cannot pass.
class _Auth {
  _Auth({this.status = 'ok', this.signedIn = true});

  final String status;
  final bool signedIn;
  final sent = <String>[];
  final verified = <(String, String)>[];

  Future<String> send(String email) async {
    sent.add(email);
    return status;
  }

  Future<bool> login(String email, String code) async {
    verified.add((email, code));
    return signedIn;
  }
}

Future<void> _pump(WidgetTester tester, _Auth auth,
    {VoidCallback? onSignedIn}) async {
  await tester.pumpWidget(MaterialApp(
    theme: testuTheme(),
    home: AdminSignin(
      onSignedIn: onSignedIn ?? () {},
      sendCode: auth.send,
      login: auth.login,
    ),
  ));
  await tester.pump();
}

/// Reach the code stage the way a user does.
Future<void> _sendCode(WidgetTester tester, String email) async {
  await tester.enterText(find.byType(TextField), email);
  await tester.tap(find.text('Send code'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the screen names the console and the product', (tester) async {
    await _pump(tester, _Auth());

    expect(find.text('ADMIN CONSOLE'), findsOneWidget);
    expect(find.text('TestU Learn'), findsOneWidget);
  });

  // Orange is progress everywhere else in TestU; a refusal has to read as a
  // refusal, and it has to clear 4.5:1 on `bg` at body size.
  testWidgets('a refused email reads in red, never in the brand orange',
      (tester) async {
    await _pump(tester, _Auth(status: 'nouser'));
    await _sendCode(tester, 'nadie@minsur.test');

    final error = tester.widget<Text>(
        find.text('No account for that email. Ask your administrator.'));
    expect(error.style?.color, AdminTokens.redText);
    expect(error.style?.color, isNot(TestuTokens.instance.orange));
  });

  testWidgets('a typo in the email is one tap from being fixed',
      (tester) async {
    final auth = _Auth();
    await _pump(tester, auth);
    await _sendCode(tester, 'diego@minsur.test');
    expect(find.text('6-digit code'), findsOneWidget);

    await tester.tap(find.text('Change email'));
    await tester.pumpAndSettle();

    expect(find.text('Work email'), findsOneWidget,
        reason: 'the email stage is back');
    expect(find.text('6-digit code'), findsNothing);
  });

  // eMe sends a real email per request. The first code was sent one second
  // ago; the second one waits, and the label says how long.
  testWidgets('resending waits out a 30 s cooldown', (tester) async {
    final auth = _Auth();
    await _pump(tester, auth);
    await _sendCode(tester, 'diego@minsur.test');

    expect(find.text('Resend code (30 s)'), findsOneWidget);
    await tester.tap(find.text('Resend code (30 s)'));
    await tester.pump();
    expect(auth.sent, ['diego@minsur.test'], reason: 'still on cooldown');

    await tester.pump(const Duration(seconds: 10));
    expect(find.text('Resend code (20 s)'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Resend code'), findsOneWidget);
  });

  testWidgets('a code that never arrived can be asked for again',
      (tester) async {
    final auth = _Auth();
    await _pump(tester, auth);
    await _sendCode(tester, 'diego@minsur.test');
    expect(auth.sent, ['diego@minsur.test']);
    await tester.pump(const Duration(seconds: 30));

    await tester.tap(find.text('Resend code'));
    await tester.pumpAndSettle();

    expect(auth.sent, ['diego@minsur.test', 'diego@minsur.test']);
    expect(find.text('6-digit code'), findsOneWidget,
        reason: 'resending must not throw the reader back a stage');
    // Nothing else on screen moves when a second code is sent, so the
    // screen has to say it happened.
    expect(find.text('Code sent again.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  // AdminSession.sendCode answers 'error' when the eMe boot itself throws --
  // first screen, server down. The screen has to say so AND stay usable; it
  // used to sit with its button disabled until someone reloaded the page.
  testWidgets('a send that never reaches the server leaves the screen usable',
      (tester) async {
    await _pump(tester, _Auth(status: 'error'));
    await _sendCode(tester, 'diego@minsur.test');

    expect(find.text('Could not send the code.'), findsOneWidget);
    expect(tester.widget<TestuButton>(find.byType(TestuButton)).onTap, isNotNull,
        reason: 'the CTA is live again, not stuck busy');
    expect(find.text('Work email'), findsOneWidget,
        reason: 'a failed send does not move the reader on');
  });

  testWidgets('a wrong code says so and the right one signs in',
      (tester) async {
    var signedIn = false;
    final auth = _Auth(signedIn: false);
    await _pump(tester, auth, onSignedIn: () => signedIn = true);
    await _sendCode(tester, 'diego@minsur.test');

    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Enter'));
    await tester.pumpAndSettle();

    expect(find.text('Wrong or expired code.'), findsOneWidget);
    expect(signedIn, isFalse);
  });

  // Six digits and two links, with nothing on screen saying which inbox to
  // look in -- and a typo in the address then looks like a broken code.
  testWidgets('the code stage says where the code went', (tester) async {
    final auth = _Auth();
    await _pump(tester, auth);
    expect(find.textContaining('Code sent to'), findsNothing);

    await _sendCode(tester, 'diego@minsur.test');

    expect(find.text('Code sent to diego@minsur.test'), findsOneWidget);

    // And it goes away with the stage it belongs to.
    await tester.tap(find.text('Change email'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Code sent to'), findsNothing);
  });

}
