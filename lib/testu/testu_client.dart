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
    this.logo,
    required this.brand,
    required this.tutor,
    required this.tutorAvatar,
    required this.lang,
    required this.persona,
    required this.personaFull,
    required this.personaAvatar,
    required this.gender,
    required this.orgEn,
    required this.orgEs,
    required this.askEn,
    required this.askEs,
  });

  /// "Vueling" — the company as written in copy.
  final String name;

  /// The word the launch intro spells out, letter by letter, when there is
  /// no [logo].
  final String wordmark;

  /// Logo image the launch intro rises in instead of the lettered wordmark
  /// (transparent PNG, drawn on the dark intro background).
  final String? logo;

  /// Brand colour of the launch intro (glow, letters, landing light).
  final Color brand;

  /// The tutor's name ("Sully") and picture.
  final String tutor;
  final String tutorAvatar;

  /// UI language at first launch: 'en' | 'es'.
  final String lang;

  /// Demo persona: first name, full name, default profile picture, and
  /// grammatical gender for the Spanish copy ('f' | 'm').
  final String persona;
  final String personaFull;
  final String personaAvatar;
  final String gender;

  /// Organisation line under the persona ("Vueling Ground Operations · BCN").
  final String orgEn;
  final String orgEs;

  /// Canned question on the tutor tab, sent to the tutor as if typed. Must be
  /// something the client's live tutorial actually covers, or the model
  /// rightly says it has nothing on it.
  final String askEn;
  final String askEs;
}

const _vueling = TestuClient(
  name: 'Vueling',
  wordmark: 'vueling',
  brand: Color(0xFFFFCC00),
  tutor: 'Sully',
  tutorAvatar: 'assets/img/sully.png',
  lang: 'en',
  persona: 'Diego',
  personaFull: 'Diego San Jorge',
  personaAvatar: 'assets/img/p_diego.jpg',
  gender: 'm',
  orgEn: 'Vueling Ground Operations · BCN',
  orgEs: 'Vueling Operaciones en Tierra · BCN',
  askEn: 'Explain the FOD walk again',
  askEs: 'Explícame otra vez la inspección FOD',
);

// IRIS: Integrity, Respect, Innovation, Sustainability — an acronym, so the
// name is uppercase everywhere (Diego, 2026-09-03). Her personality text
// lives on the server (tutorpersona record), not in the app.
const _minsur = TestuClient(
  name: 'Minsur',
  wordmark: 'minsur',
  logo: 'assets/img/minsur_logo.png',
  brand: Color(0xFF7291B0),
  tutor: 'IRIS',
  tutorAvatar: 'assets/img/iris.png',
  lang: 'es',
  persona: 'Diego',
  personaFull: 'Diego San Jorge',
  personaAvatar: 'assets/img/p_diego.jpg',
  gender: 'm',
  orgEn: 'Minsur · Lima',
  orgEs: 'Minsur · Lima',
  // Section 1.1 of the DDHH tutorial (universality, inalienability, dignity).
  askEn: 'Explain again why human rights are inalienable',
  askEs: 'Explícame otra vez por qué los derechos humanos son inalienables',
);
