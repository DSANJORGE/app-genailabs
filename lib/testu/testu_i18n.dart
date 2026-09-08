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

/// Client-aware bilingual string for the prototype (unwired) screens, whose
/// sample copy is domain-specific: Minsur gets the mining wording, every
/// other client the aviation wording. `CL(mEn, mEs, vEn, vEs)`.
String CL(String mEn, String mEs, String vEn, String vEs) =>
    client.name == 'Minsur' ? L(mEn, mEs) : L(vEn, vEs);

/// The user's grammatical gender — Spanish copy that addresses the user
/// must agree with it ("¿Cuán seguro estás?" vs "¿Cuán segura estás?").
/// ponytail: fixed to the client's demo persona; wire to a profile
/// setting when real accounts carry a gender field.
final testuGender = ValueNotifier<String>(client.gender);

// ponytail: mirrors testu_live.dart's `testuLive` const (same env key,
// same default) instead of importing it — that file (via
// testu_question_source.dart / testu_sully.dart) imports this one, so a
// direct import would cycle.
const _testuLiveGender =
    bool.fromEnvironment('TESTU_LIVE', defaultValue: testuClientId == 'minsur');

/// Gendered Spanish fragment: `G('seguro', 'segura')`. English is
/// gender-neutral, so this only ever feeds the `es` side of `L()`.
///
/// Live accounts carry no gender, so a live build writes the neutral slash
/// form ("seguro/a"); every call site passes a pair that differs only in
/// the last letter. ponytail: one line instead of 19 neutral rewrites;
/// switch on a profile field when accounts get one.
String G(String masc, String fem) => _testuLiveGender
    ? '$masc/${fem.substring(fem.length - 1)}'
    : (testuGender.value == 'f' ? fem : masc);
