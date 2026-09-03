import 'dart:ui';

/// Which client this build is skinned for:
/// `flutter run -t lib/main_testu.dart --dart-define=TESTU_CLIENT=vueling|minsur`
/// (see `run_minsur.sh` / `run_vueling.sh`). Default = minsur, live against
/// the local eMe server; vueling = the offline prototype, unchanged.
const testuClientId =
    String.fromEnvironment('TESTU_CLIENT', defaultValue: 'minsur');

/// The client profile every screen reads its branding from.
const client = testuClientId == 'vueling' ? _vueling : _minsur;

class TestuClient {
  const TestuClient({
    required this.name,
    required this.wordmark,
    required this.brand,
    required this.tutor,
    required this.lang,
    required this.persona,
    required this.personaFull,
    required this.gender,
    required this.orgEn,
    required this.orgEs,
  });

  /// "Vueling" — the company as written in copy.
  final String name;

  /// The word the launch intro spells out, letter by letter.
  final String wordmark;

  /// Brand colour of the launch intro (glow, letters, landing light).
  final Color brand;

  /// The tutor's name ("Sully").
  final String tutor;

  /// UI language at first launch: 'en' | 'es'.
  final String lang;

  /// Demo persona's first name and full name, and grammatical gender for
  /// the Spanish copy ('f' | 'm').
  final String persona;
  final String personaFull;
  final String gender;

  /// Organisation line under the persona ("Vueling Ground Operations · BCN").
  final String orgEn;
  final String orgEs;
}

const _vueling = TestuClient(
  name: 'Vueling',
  wordmark: 'vueling',
  brand: Color(0xFFFFCC00),
  tutor: 'Sully',
  lang: 'en',
  persona: 'Ana',
  personaFull: 'Ana Ruiz',
  gender: 'f',
  orgEn: 'Vueling Ground Operations · BCN',
  orgEs: 'Vueling Operaciones en Tierra · BCN',
);

// ponytail: tutor name, colour and org line are placeholders until Minsur
// confirms them — each is a one-word change here.
const _minsur = TestuClient(
  name: 'Minsur',
  wordmark: 'minsur',
  brand: Color(0xFFD08A2E),
  tutor: 'Inti',
  lang: 'es',
  persona: 'Diego',
  personaFull: 'Diego Sanjorge',
  gender: 'm',
  orgEn: 'Minsur · Lima',
  orgEs: 'Minsur · Lima',
);
