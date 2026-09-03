import 'package:flutter/foundation.dart';

import 'testu_client.dart';

/// Available UI languages — add a code+name here and `L()` translations at
/// call sites; the profile dropdown lists this map.
const testuLanguages = {'en': 'English', 'es': 'Español'};

/// Current language, starting from the client's. The shell and profile
/// listen and rebuild on change.
final testuLang = ValueNotifier<String>(client.lang);

/// Inline bilingual string: `L('Hello', 'Hola')`.
/// ponytail: per-call-site pairs beat arb files at demo scale; move to
/// flutter gen-l10n when a third language or external translators arrive.
String L(String en, String es) => testuLang.value == 'es' ? es : en;

/// The user's grammatical gender — Spanish copy that addresses the user
/// must agree with it ("¿Cuán seguro estás?" vs "¿Cuán segura estás?").
/// ponytail: fixed to the client's demo persona; wire to a profile
/// setting when real accounts carry a gender field.
final testuGender = ValueNotifier<String>(client.gender);

/// Gendered Spanish fragment: `G('seguro', 'segura')`. English is
/// gender-neutral, so this only ever feeds the `es` side of `L()`.
String G(String masc, String fem) => testuGender.value == 'f' ? fem : masc;
