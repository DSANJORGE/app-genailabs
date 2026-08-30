import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Ana's chosen avatar — the Today header listens so the photo swap
/// propagates, like the prototype's setAvatar() updating every .ana-ava.
final testuAvatar = ValueNotifier<String>('assets/img/p_ana.jpg');

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
  bool _outlookConnected = false;
  bool _googleOn = true;
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
        child: ListView(
          padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 28),
          children: [
            const SizedBox(height: 6),
            _Head(onBack: () => Navigator.of(context).pop()),
            _ProfCard(children: [
              _H4(L('PROFILE PHOTO', 'FOTO DE PERFIL')),
              const _AvatarPicker(),
              const SizedBox(height: 10),
              _Note(
                  L('Vueling allows personal photos on internal apps. Your '
                          'photo is visible to your team — never outside the '
                          'airline.',
                      'Vueling permite fotos personales en apps internas. Tu '
                          'foto es visible para tu equipo — nunca fuera de la '
                          'aerolínea.'),
                  t: t),
            ]),
            _ProfCard(children: [
              _H4(L('LANGUAGE', 'IDIOMA')),
              _SetRow(
                title: L('App language', 'Idioma de la app'),
                sub: L('Applies across TestU Learn',
                    'Se aplica en todo TestU Learn'),
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
                  style: TextStyle(
                      fontFamily: 'Geist', fontSize: 11, color: t.mut),
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
                  // ponytail: sign-out just leaves the screen — no auth yet.
                  TestuButton(
                    L('Sign out', 'Cerrar sesión'),
                    color: t.red,
                    borderColor: const Color(0x52C25555),
                    onTap: () => Navigator.of(context).pop(),
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
              child: Image.asset(src, width: 62, height: 62, fit: BoxFit.cover),
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
                  L('Ramp Agent · Safety Lead track\n'
                          'Vueling Ground Operations · BCN',
                      'Agente de Rampa · Vía Líder de Seguridad\n'
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

  static const _options = [
    'assets/img/p_ana.jpg',
    'assets/img/p_laia.jpg',
    'assets/img/p_miranda.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: testuAvatar,
      builder: (_, sel, child) => Row(
        children: [
          for (final src in _options)
            Padding(
              padding: const EdgeInsets.only(right: 11),
              child: TestuPressable(
                onTap: () => testuAvatar.value = src,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      width: 2,
                      color: src == sel
                          ? const Color(0xFFF4F2EE)
                          : Colors.transparent,
                    ),
                  ),
                  child: ClipOval(child: Image.asset(src, fit: BoxFit.cover)),
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
                  style: TextStyle(
                      fontFamily: 'Geist', fontSize: 10.5, color: t.mut),
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

class _H4 extends StatelessWidget {
  const _H4(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'GeistMono',
          fontSize: 9,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.26, // .14em
          color: t.faint,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {required this.t});

  final String text;
  final TestuTokens t;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
          fontFamily: 'Geist', fontSize: 10, height: 1.55, color: t.faint),
    );
  }
}
