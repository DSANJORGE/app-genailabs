import 'dart:async';

import 'package:genai_labs/testu/testu_i18n.dart';

/// The TestU widget tests assert the English copy; the default client
/// (minsur) starts in Spanish, so pin the language once for the whole suite.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  testuLang.value = 'en';
  await testMain();
}
