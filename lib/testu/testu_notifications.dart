import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_icons.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Rule of the split: Today carries everything ACTIONABLE (do this now);
/// Notifications carries the non-actionable/informative tail (your report
/// was reviewed, content updated, certificate issued). Nothing informative
/// goes on Today anymore.
class TestuNotice {
  TestuNotice(this.title, this.body, this.when, {this.unread = true});
  final String title;
  final String body;
  final String when; // display string; real timestamps come with the backend
  bool unread;
}

/// Store — demo-seeded lazily so `L()` resolves per language at first use.
final testuNotices = ValueNotifier<List<TestuNotice>>([]);
bool _seeded = false;

void _seed() {
  if (_seeded) return;
  _seeded = true;
  testuNotices.value = [
    TestuNotice(
      L('Your question report was incorporated',
          'Tu reporte de pregunta fue incorporado'),
      L('The FOD question you flagged was corrected by the content team. Thanks!',
          'La pregunta de FOD que reportaste fue corregida por el equipo de contenido. ¡Gracias!'),
      L('Yesterday', 'Ayer'),
    ),
    TestuNotice(
      L('New resource in Ramp Safety', 'Nuevo recurso en Seguridad en Rampa'),
      L('“Winter operations addendum” was added to your topic resources.',
          'Se añadió «Anexo de operaciones de invierno» a los recursos de tu tema.'),
      L('Tuesday', 'Martes'),
      unread: false,
    ),
    TestuNotice(
      L('Certificate renewed', 'Certificado renovado'),
      L('Your FOD Prevention certificate was renewed and verified by TestU.',
          'Tu certificado de Prevención de FOD fue renovado y verificado por TestU.'),
      L('Aug 12', '12 ago'),
      unread: false,
    ),
  ];
}

void addTestuNotice(String title, String body) {
  _seed();
  testuNotices.value = [
    TestuNotice(title, body, L('Now', 'Ahora')),
    ...testuNotices.value,
  ];
}

/// Bell for the Today header — avatar-sized circle, orange dot when unread
/// (orange = the app's single brand/progress accent).
class TestuBell extends StatelessWidget {
  const TestuBell({super.key});

  @override
  Widget build(BuildContext context) {
    _seed();
    final t = TestuTokens.of(context);
    return TestuPressable(
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TestuNotificationsScreen())),
      child: ValueListenableBuilder<List<TestuNotice>>(
        valueListenable: testuNotices,
        builder: (_, items, _) {
          final unread = items.any((n) => n.unread);
          return SizedBox(
            width: 32,
            height: 32,
            child: Stack(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: t.line2),
                  ),
                  child: TestuIcon(TestuGlyph.bell, size: 15, color: t.mut),
                ),
                if (unread)
                  Positioned(
                    top: 1,
                    right: 1,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: t.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.bg, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Notifications screen — «Agrupado» structure (chosen 2026-09-01): recency
/// sections HOY / ANTERIORES. Item actions: swipe right toggles read/unread,
/// swipe left deletes. Leaving the screen marks the rest read.
class TestuNotificationsScreen extends StatefulWidget {
  const TestuNotificationsScreen({super.key});

  @override
  State<TestuNotificationsScreen> createState() =>
      _TestuNotificationsScreenState();
}

class _TestuNotificationsScreenState extends State<TestuNotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      L('Notifications', 'Notificaciones'),
                      style: TextStyle(
                        fontFamily: 'Sora',
                        fontWeight: FontWeight.w700,
                        fontSize: 21,
                        letterSpacing: -0.21,
                        color: t.ink,
                      ),
                    ),
                  ),
                  TestuPressable(
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child:
                          Text('✕', style: TextStyle(fontSize: 15, color: t.mut)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Text(
                L('Reviews of your reports, content updates, certificates. Anything that needs action stays on Today.',
                    'Revisiones de tus reportes, cambios de contenido, certificados. Lo que requiere acción sigue en Hoy.'),
                style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 11.5,
                    height: 1.5,
                    color: t.faint),
              ),
            ),
            Expanded(
              child: ValueListenableBuilder<List<TestuNotice>>(
                valueListenable: testuNotices,
                builder: (_, items, _) => _grouped(t, items),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Items the user explicitly long-pressed back to unread — survive the
  /// leave-marks-read sweep so the action isn't silently undone.
  final _keepUnread = <TestuNotice>{};

  @override
  void dispose() {
    // Leaving the screen marks everything read (bell dot clears),
    // except what the user deliberately kept unread.
    for (final n in testuNotices.value) {
      if (!_keepUnread.contains(n)) n.unread = false;
    }
    testuNotices.value = [...testuNotices.value];
    super.dispose();
  }

  /// Row actions: swipe right = toggle read/unread (row springs back),
  /// swipe left = delete. Standard mail-app grammar, no hidden gestures.
  Widget _item(TestuTokens t, TestuNotice n, {bool showWhen = true}) =>
      Dismissible(
        key: ObjectKey(n),
        // Reveal labels sit close to the row edge, colored by consequence:
        // orange = the unread-dot accent, red = destructive.
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 4),
          child: Text(
              n.unread
                  ? L('Mark read', 'Marcar leída')
                  : L('Mark unread', 'Marcar no leída'),
              style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: t.orange)),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 4),
          child: Text(L('Delete', 'Eliminar'),
              style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: t.red)),
        ),
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.endToStart) return true;
          // Right swipe: toggle, never dismiss the row.
          HapticFeedback.selectionClick();
          n.unread = !n.unread;
          n.unread ? _keepUnread.add(n) : _keepUnread.remove(n);
          testuNotices.value = [...testuNotices.value];
          return false;
        },
        onDismissed: (_) => testuNotices.value = [
          for (final x in testuNotices.value)
            if (!identical(x, n)) x
        ],
        child: _row(t, n, showWhen: showWhen),
      );

  Widget _row(TestuTokens t, TestuNotice n, {bool showWhen = true}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 5, right: 10),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: n.unread ? t.orange : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n.title,
                      style: TextStyle(
                        fontFamily: 'Geist',
                        fontSize: 12.5,
                        fontWeight:
                            n.unread ? FontWeight.w700 : FontWeight.w600,
                        color: t.ink,
                      )),
                  const SizedBox(height: 3),
                  Text(n.body, style: kCardBody),
                ],
              ),
            ),
            if (showWhen) ...[
              const SizedBox(width: 10),
              Text(n.when,
                  style: TextStyle(
                      fontFamily: 'GeistMono', fontSize: 9, color: t.faint)),
            ],
          ],
        ),
      );

  /// «Agrupado» — sections by recency, mono group labels.
  Widget _grouped(TestuTokens t, List<TestuNotice> items) {
    final today = [
      for (final n in items)
        if (n.when == L('Now', 'Ahora')) n
    ];
    final earlier = [
      for (final n in items)
        if (n.when != L('Now', 'Ahora')) n
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        if (today.isNotEmpty) ...[
          TestuEyebrow(L('TODAY', 'HOY')),
          for (final n in today) _item(t, n, showWhen: false),
          const SizedBox(height: 14),
        ],
        TestuEyebrow(L('EARLIER', 'ANTERIORES')),
        for (final n in earlier) _item(t, n),
      ],
    );
  }
}
