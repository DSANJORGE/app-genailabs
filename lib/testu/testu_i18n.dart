import 'package:flutter/foundation.dart';

/// Available UI languages — add a code+name here and `L()` translations at
/// call sites; the profile dropdown lists this map.
const testuLanguages = {'en': 'English', 'es': 'Español'};

/// Current language. The shell and profile listen and rebuild on change.
final testuLang = ValueNotifier<String>('en');

/// Inline bilingual string: `L('Hello', 'Hola')`.
/// ponytail: per-call-site pairs beat arb files at demo scale; move to
/// flutter gen-l10n when a third language or external translators arrive.
String L(String en, String es) => testuLang.value == 'es' ? es : en;
