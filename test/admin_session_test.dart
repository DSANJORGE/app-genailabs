import 'package:eme_app_package/eme_http.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_session.dart';

EmeHttpException _at(String path, int? code) => EmeHttpException(
      uri: Uri.parse('https://minsur.genailabs.tech/site/mediadb/$path'),
      statusCode: code,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // There is no workspace, no shared_preferences plugin and no server here,
  // so `init()` throws -- exactly what the first call from a browser against
  // a dead server does. It must come back as a failed send, not as an
  // exception: AdminSignin has no catch, and an escaping one leaves its
  // button disabled for good with nothing on screen to explain it.
  test('a boot failure is a failed send, not an exception', () async {
    expect(await AdminSession.sendCode('diego@minsur.test'), 'error');
  });

  test('a boot failure is a failed login, not an exception', () async {
    expect(await AdminSession.login('diego@minsur.test', '123456'), isFalse);
  });

  // person.json answers 403 for a learner outside the viewer's teams. That is
  // the scope rule talking, not a dead token: signing the console out there
  // would drop a manager to the login screen for clicking a name.
  test("person.json's 403 is a scope reply, not a dead session", () {
    expect(AdminSession.signsOut(_at('services/testu/analytics/person.json', 403)),
        isFalse);
  });

  test('every other 401 or 403 still ends the session', () {
    for (final e in [
      _at('services/testu/analytics/person.json', 401),
      _at('services/testu/analytics/overview.json', 403),
      _at('services/testu/personas/users.json', 403),
      _at('services/testu/personas/me.json', 401),
    ]) {
      expect(AdminSession.signsOut(e), isTrue,
          reason: '${e.statusCode} ${e.uri.path}');
    }
  });
}
