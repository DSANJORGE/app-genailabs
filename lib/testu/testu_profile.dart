import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'testu_auth.dart';
import 'testu_i18n.dart';
import 'testu_lock.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Ana's chosen avatar — the Today header listens so the photo swap
/// propagates, like the prototype's setAvatar() updating every .ana-ava.
/// ponytail: photos live on-device only; no upload endpoint yet.
final testuAvatar = ValueNotifier<String>(_presetAvatars.first);

/// Photos the user added, oldest first. Presets are bundled and permanent;
/// these are the ones that can be removed again.
final testuAvatarLibrary = ValueNotifier<List<String>>(const []);

const _presetAvatars = [
  'assets/img/p_ana.jpg',
  'assets/img/p_laia.jpg',
  'assets/img/p_miranda.jpg',
];

const _kAvatarPref = 'testu_avatar';

Future<Directory> _avatarDir() async {
  final d =
      Directory('${(await getApplicationDocumentsDirectory()).path}/avatars');
  if (!d.existsSync()) d.createSync(recursive: true);
  return d;
}

/// Restores the library and the selection; call once at startup.
Future<void> restoreTestuAvatar() async {
  final dir = await _avatarDir();
  // Carried over from the single-photo cut, which saved one fixed avatar.jpg.
  final legacy = File('${dir.parent.path}/avatar.jpg');
  if (legacy.existsSync()) {
    legacy.renameSync(
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg');
  }
  testuAvatarLibrary.value = dir
      .listSync()
      .whereType<File>()
      .map((f) => f.path)
      .toList()
    ..sort();
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_kAvatarPref);
  if (saved != null &&
      (saved.startsWith('assets/') || File(saved).existsSync())) {
    testuAvatar.value = saved;
  }
}

Future<void> _selectAvatar(String src) async {
  testuAvatar.value = src;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kAvatarPref, src);
}

/// Copies the pick into the library under a unique name — FileImage caches by
/// path, so reusing one filename would keep serving the previous photo.
Future<void> _addAvatar() async {
  final picked = await ImagePicker()
      .pickImage(source: ImageSource.gallery, maxWidth: 512);
  if (picked == null) return;
  final dir = await _avatarDir();
  final dest = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(picked.path).copy(dest);
  testuAvatarLibrary.value = [...testuAvatarLibrary.value, dest];
  await _selectAvatar(dest);
}

/// Removes a photo from TestU (not from the phone's own library). If it was
/// the one in use, the profile falls back to the first preset rather than
/// leaving the header with a missing file.
Future<void> _removeAvatar(String path) async {
  final f = File(path);
  if (f.existsSync()) f.deleteSync();
  await FileImage(f).evict();
  testuAvatarLibrary.value =
      testuAvatarLibrary.value.where((p) => p != path).toList();
  if (testuAvatar.value == path) await _selectAvatar(_presetAvatars.first);
}

/// [testuAvatar] holds either a bundled asset key or a picked file path.
ImageProvider testuAvatarImage(String src) =>
    src.startsWith('assets/') ? AssetImage(src) : FileImage(File(src));

void showTestuProfile(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const TestuProfileScreen()),
  );
}

/// Profile & settings — opens from Ana's avatar on Today, never from the nav.
class TestuProfileScreen extends StatefulWidget {
  const TestuProfileScreen({super.key});

  @override
  State<TestuProfileScreen> createState() => _TestuProfileScreenState();
}

class _TestuProfileScreenState extends State<TestuProfileScreen> {
  // ponytail: in-memory settings — a demo restart resetting toggles is fine.
  // (Biometric unlock is the exception: it must survive a restart to mean
  // anything, so TestuLock persists it.)
  bool _outlookConnected = false;
  bool _googleOn = true;
  String? _lockError;

  /// Turning it on runs the sensor first; a refused or failed check leaves
  /// the toggle where it was and says why.
  Future<void> _toggleLock() async {
    final want = !TestuLock.enabled;
    final ok = await TestuLock.setEnabled(want);
    if (!mounted) return;
    setState(() => _lockError = ok
        ? null
        : L("${TestuLock.name} didn't confirm — unlock is still off.",
            '${TestuLock.name} no lo confirmó: el desbloqueo sigue '
                'desactivado.'));
  }
  final _toggles = <String, bool>{
    'daily': true,
    'nudges': true,
    'weekly': false,
  };

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 6),
            _Head(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: EdgeInsets.only(
                        top: 6,
                        bottom: MediaQuery.paddingOf(context).bottom + 28),
                    children: [
                      _ProfCard(children: [
              _H4(L('PROFILE PHOTO', 'FOTO DE PERFIL')),
              const _AvatarPicker(),
              const SizedBox(height: 10),
              _Note(
                  L('Vueling allows personal photos on internal apps. Your '
                          'photo is visible to your team — never outside the '
                          'airline. Removing one here leaves it on your phone.',
                      'Vueling permite fotos personales en apps internas. Tu '
                          'foto es visible para tu equipo — nunca fuera de la '
                          'aerolínea. Quitar una aquí no la borra de tu '
                          'teléfono.'),
                  t: t),
            ]),
            _ProfCard(children: [
              _H4(L('SECURITY', 'SEGURIDAD')),
              _SetRow(
                title: TestuLock.available
                    ? L('Unlock with ${TestuLock.name}',
                        'Desbloquear con ${TestuLock.name}')
                    : L('Unlock with Face ID or fingerprint',
                        'Desbloquear con Face ID o huella'),
                sub: TestuLock.available
                    ? L('Open the app without waiting for an emailed code',
                        'Abre la app sin esperar un código por correo')
                    : L('Set up Face ID or a fingerprint on this device first',
                        'Configura Face ID o una huella en este dispositivo '
                            'primero'),
                last: true,
                trailing: TestuLock.available
                    ? _Toggle(on: TestuLock.enabled, onTap: _toggleLock)
                    : Opacity(
                        opacity: 0.55, child: _Toggle(on: false)),
              ),
              if (_lockError != null) ...[
                const SizedBox(height: 8),
                Text(_lockError!,
                    style: TextStyle(
                        fontFamily: 'Geist', fontSize: 11.5, color: t.red)),
              ],
              const SizedBox(height: 8),
              _Note(
                  L('Your face or fingerprint stays on this phone — TestU '
                          'never receives it. Signing out turns this off.',
                      'Tu cara o tu huella se quedan en este teléfono: TestU '
                          'nunca las recibe. Al cerrar sesión se desactiva.'),
                  t: t),
            ]),
            _ProfCard(children: [
              _H4(L('LANGUAGE', 'IDIOMA')),
              _SetRow(
                // ponytail: one language setting, not two — Sully's copy
                // resolves through the same `testuLang` notifier as the UI,
                // so a "tutor language" row would be a second source of truth
                // for the same fact. Split it only if the backend ever serves
                // tutor content in a language the UI is not in.
                title: L('App & tutor language',
                    'Idioma de la app y del tutor'),
                sub: L('Applies across TestU Learn, including Sully',
                    'Se aplica en todo TestU Learn, incluido Sully'),
                last: true,
                trailing: _LangDropdown(
                    onChanged: (v) => setState(() => testuLang.value = v)),
              ),
            ]),
            _ProfCard(children: [
              _H4(L('CALENDARS · SULLY USES THESE TO FIND QUIET SLOTS',
                  'CALENDARIOS · SULLY LOS USA PARA ENCONTRAR HUECOS')),
              _SetRow(
                title: L('Vueling roster', 'Turnos Vueling'),
                sub: L('Shifts & briefings · required by your organisation',
                    'Turnos y briefings · requerido por tu organización'),
                trailing: _GreenPill(L('Connected', 'Conectado')),
              ),
              _SetRow(
                title: 'Google Calendar',
                sub: 'Personal · ana.ruiz@gmail.com',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GreenPill(L('Connected', 'Conectado')),
                    const SizedBox(width: 10),
                    _Toggle(
                      on: _googleOn,
                      onTap: () => setState(() => _googleOn = !_googleOn),
                    ),
                  ],
                ),
              ),
              _SetRow(
                title: 'Outlook',
                sub: L('Work · lets Sully avoid meetings when proposing '
                        'evaluations',
                    'Trabajo · permite a Sully evitar reuniones al proponer '
                        'evaluaciones'),
                last: true,
                trailing: _outlookConnected
                    ? _GreenPill(L('Connected', 'Conectado'))
                    : TestuPressable(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          setState(() => _outlookConnected = true);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 7, horizontal: 12),
                          decoration: BoxDecoration(
                            color: t.primaryAction,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            L('Connect', 'Conectar'),
                            style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.42, // .04em
                              color: t.onPrimaryAction,
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              _Note(
                  L('Sully only reads free/busy times — never event contents.',
                      'Sully solo lee horas libres/ocupadas — nunca el contenido de los eventos.'),
                  t: t),
            ]),
            _ProfCard(children: [
              _H4(L('NOTIFICATIONS', 'NOTIFICACIONES')),
              _SetRow(
                title: L('Certification deadlines', 'Plazos de certificación'),
                sub: L('Required by Vueling — cannot be turned off',
                    'Requerido por Vueling — no se puede desactivar'),
                trailing:
                    const Opacity(opacity: 0.55, child: _Toggle(on: true)),
              ),
              _SetRow(
                title: L('Daily Challenge reminder',
                    'Recordatorio del Reto Diario'),
                sub: L('“Hey, this is Sully…” · 08:00',
                    '«Hola, soy Sully…» · 08:00'),
                trailing: _tgl('daily'),
              ),
              _SetRow(
                title: L('Sully nudges', 'Avisos de Sully'),
                sub: L('When a topic drifts to “At risk”',
                    'Cuando un tema pasa a «En riesgo»'),
                trailing: _tgl('nudges'),
              ),
              _SetRow(
                title: L('Weekly summary', 'Resumen semanal'),
                sub: L('Monday, before your first shift',
                    'Lunes, antes de tu primer turno'),
                trailing: _tgl('weekly'),
              ),
              _SetRow(
                title: L('Quiet hours', 'Horas de silencio'),
                sub: L('No notifications 22:00 – 07:00',
                    'Sin notificaciones 22:00 – 07:00'),
                last: true,
                trailing: Text(
                  '22:00–07:00 ›',
                  style: kLabel,
                ),
              ),
            ]),
            _ProfCard(children: [
              _H4(L('PRIVACY', 'PRIVACIDAD')),
              Text(
                L('Your conversations with Sully are private to you. Your '
                        'managers see readiness signals and certification '
                        'status — never your chats, never individual answers.',
                    'Tus conversaciones con Sully son privadas. Tus '
                        'responsables ven señales de preparación y estado de '
                        'certificación — nunca tus chats, nunca respuestas '
                        'individuales.'),
                style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 11.5,
                  height: 1.6,
                  color: Color(0xFFB9B8B4),
                ),
              ),
            ]),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Column(
                children: [
                  TestuButton(
                    L('Sign out', 'Cerrar sesión'),
                    color: t.red,
                    borderColor: const Color(0x52C25555),
                    onTap: () {
                      Navigator.of(context).pop();
                      TestuAuth.signOut();
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TESTU LEARN · VUELING · DEMO BUILD',
                    style: TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 9.5,
                      color: t.faint,
                    ),
                  ),
                ],
              ),
            ),
                    ],
                  ),
                  // Cards fade out as they slide under the pinned header.
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 16,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [t.bg, t.bg.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tgl(String key) => _Toggle(
        on: _toggles[key]!,
        onTap: () => setState(() => _toggles[key] = !_toggles[key]!),
      );
}

class _Head extends StatelessWidget {
  const _Head({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 18, 6),
      child: Row(
        children: [
          TestuPressable(
            onTap: onBack,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                '‹',
                style: TextStyle(
                    fontFamily: 'Sora', fontSize: 26, color: t.mut),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<String>(
            valueListenable: testuAvatar,
            builder: (_, src, child) => ClipOval(
              child: Image(
                  image: testuAvatarImage(src),
                  width: 62,
                  height: 62,
                  fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ana Ruiz',
                  style: TextStyle(
                    fontFamily: 'Sora',
                    fontWeight: FontWeight.w700,
                    fontSize: 19,
                    letterSpacing: -0.19,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  // No hand \n: the Spanish first half only just fits at
                  // 390pt — let the text wrap where it needs to.
                  L('Ramp Agent · Safety Lead track · '
                          'Vueling Ground Operations · BCN',
                      'Agente de Rampa · Vía Líder de Seguridad · '
                          'Vueling Operaciones en Tierra · BCN'),
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 11,
                    height: 1.5,
                    color: t.mut,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return ValueListenableBuilder<List<String>>(
      valueListenable: testuAvatarLibrary,
      builder: (_, mine, _) => ValueListenableBuilder<String>(
        valueListenable: testuAvatar,
        // Wraps rather than scrolls: the row grows a tile per added photo,
        // and a second line reads better than a hidden horizontal overflow.
        builder: (_, sel, _) => Wrap(
          spacing: 11,
          runSpacing: 11,
          children: [
            for (final src in [..._presetAvatars, ...mine])
              _AvatarTile(
                src: src,
                selected: src == sel,
                // Presets ship with the app; only added photos can go.
                onRemove: mine.contains(src) ? () => _removeAvatar(src) : null,
              ),
            // Same 58px box as the tiles so it sits on their baseline rather
            // than floating in their badge gutter.
            SizedBox(
              width: 46,
              height: 58,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: TestuPressable(
                  onTap: _addAvatar,
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: t.line2),
                    ),
                    child: Text('+',
                        style: TextStyle(
                            fontFamily: 'Sora', fontSize: 20, color: t.mut)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One avatar option: 46px circle, white ring when in use, and — for added
/// photos — a remove badge that is always visible rather than a long-press
/// nobody discovers. The badge sits in the tile's own 12px gutter so it never
/// covers the face.
class _AvatarTile extends StatelessWidget {
  const _AvatarTile({
    required this.src,
    required this.selected,
    required this.onRemove,
  });

  final String src;
  final bool selected;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: TestuPressable(
              onTap: () => _selectAvatar(src),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    width: 2,
                    color:
                        selected ? const Color(0xFFF4F2EE) : Colors.transparent,
                  ),
                ),
                child: ClipOval(
                    child:
                        Image(image: testuAvatarImage(src), fit: BoxFit.cover)),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 0,
              top: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onRemove!();
                },
                // 26px target around an 18px badge — the badge is the mark,
                // the padding is the tap.
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 18,
                    height: 18,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.card2,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.line2),
                    ),
                    child: Text('✕',
                        style: TextStyle(fontSize: 8.5, color: t.mut)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Settings row: title + sub on the left, control on the right, hairline
/// between rows.
class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.title,
    required this.sub,
    required this.trailing,
    this.last = false,
  });

  final String title;
  final String sub;
  final Widget trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: last
          ? null
          : const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF17171A))),
            ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: kMeta,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

/// iOS-style toggle: 40×24 pill, knob slides 16px, green track when on.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.on, this.onTap});

  final bool on;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 24,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: on ? const Color(0xFF2F6A4C) : const Color(0xFF2C2C33),
          borderRadius: BorderRadius.circular(99),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: TestuTokens.curve,
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? const Color(0xFFE9E8E4) : const Color(0xFF8B8F98),
            ),
          ),
        ),
      ),
    );
  }
}

class _GreenPill extends StatelessWidget {
  const _GreenPill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return TestuPill(label,
        color: const Color(0xFF7DBB9C), borderColor: const Color(0xFF2F6A4C));
  }
}

/// Native dropdown listing [testuLanguages] — new locales appear
/// automatically.
class _LangDropdown extends StatelessWidget {
  const _LangDropdown({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.card2,
        border: Border.all(color: t.line2),
        borderRadius: BorderRadius.circular(7),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: testuLang.value,
          isDense: true,
          dropdownColor: t.card2,
          borderRadius: BorderRadius.circular(10),
          icon: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text('▾', style: TextStyle(fontSize: 11, color: t.mut)),
          ),
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: t.ink,
          ),
          items: [
            for (final e in testuLanguages.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null && v != testuLang.value) {
              HapticFeedback.selectionClick();
              onChanged(v);
            }
          },
        ),
      ),
    );
  }
}

class _ProfCard extends StatelessWidget {
  const _ProfCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
      child: TestuCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// Profile section label: the shared h4 eyebrow plus this screen's spacing.
class _H4 extends StatelessWidget {
  const _H4(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TestuEyebrow.h4(text),
      );
}

class _Note extends StatelessWidget {
  const _Note(this.text, {required this.t});

  final String text;
  final TestuTokens t;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: kNote,
    );
  }
}
