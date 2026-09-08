import 'dart:async';
import 'dart:convert';

import 'package:eme_app_package/eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_client.dart';
import 'testu_i18n.dart';
import 'testu_icons.dart';
import 'testu_live.dart';
import 'testu_route.dart';
import 'testu_shell.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

/// Rule of the split: Today carries everything ACTIONABLE (do this now);
/// Notifications carries the non-actionable/informative tail (your report
/// was reviewed, content updated, certificate issued). Nothing informative
/// goes on Today anymore.
class TestuNotice {
  TestuNotice(this.title, this.body, this.when,
      {this.unread = true,
      this.id,
      this.type,
      this.channel,
      this.messageId,
      this.tutorialId,
      this.topicId,
      this.questionId,
      this.date});

  /// One row of `services/testu/social/notifications.json`. Empty ids from
  /// the server (`entityquestion` on a topic review) read as none.
  factory TestuNotice.fromJson(Map<String, dynamic> j) {
    final type = '${j['type'] ?? ''}';
    final date = DateTime.tryParse('${j['date'] ?? ''}')?.toLocal();
    return TestuNotice(
      testuNoticeTitle(type, '${j['actorname'] ?? ''}'.trim()),
      '${j['text'] ?? ''}',
      date == null ? L('Now', 'Ahora') : '${date.day}/${date.month}',
      unread: j['read'] != true,
      id: _nz(j['id']),
      type: type,
      channel: _nz(j['channel']),
      messageId: _nz(j['messageid']),
      tutorialId: _nz(j['entitytutorial']),
      topicId: _nz(j['entitytopic']),
      questionId: _nz(j['entityquestion']),
      date: date,
    );
  }

  final String title;
  final String body;
  final String when; // display string; live rows also carry [date]
  bool unread;

  /// Server identity and origin; null on demo/local rows (`id` null =
  /// never posted to the server, survives a poll).
  final String? id, type, channel, messageId, tutorialId, topicId, questionId;
  final DateTime? date;

  /// The «HOY» group: a real date today, or the demo's "Now" label.
  bool get isToday {
    final d = date;
    if (d == null) return when == L('Now', 'Ahora');
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

String? _nz(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

/// Title line per server type; the actor's display name is the subject.
String testuNoticeTitle(String type, String actor) => switch (type) {
      'reply' => L('$actor replied to you', '$actor te respondió'),
      'mention' => L('$actor mentioned you', '$actor te mencionó'),
      'reaction' => L('$actor reacted to your comment',
          '$actor reaccionó a tu comentario'),
      'tutorreply' =>
        L('${client.tutor} answered you', '${client.tutor} te respondió'),
      _ => actor,
    };

/// Where a tap on [n] lands: a shell tab to select, or a screen to push
/// (question session, else the topic's review tab). Pure, so the routing
/// table is a unit test; the screen turns it into navigation.
typedef TestuNoticeTarget = ({
  int? tab,
  String? topicId,
  String? questionId,
  String? messageId,
  String? tutorialId,
});

TestuNoticeTarget testuNoticeTarget(TestuNotice n) => switch (n.type) {
      'tutorreply' => (
          tab: 2,
          topicId: null,
          questionId: null,
          messageId: null,
          tutorialId: null
        ),
      'reply' || 'mention' || 'reaction' when n.topicId != null => (
          tab: null,
          topicId: n.topicId,
          questionId: n.questionId,
          messageId: n.messageId,
          tutorialId: n.tutorialId,
        ),
      _ => (
          tab: null,
          topicId: null,
          questionId: null,
          messageId: null,
          tutorialId: null
        ),
    };

/// Store — demo-seeded lazily so `L()` resolves per language at first use.
/// A live build starts empty and is filled by [refreshTestuNotices].
final testuNotices = ValueNotifier<List<TestuNotice>>([]);
bool _seeded = false;

void _seed() {
  if (_seeded || testuLive) return;
  _seeded = true;
  testuNotices.value = [
    TestuNotice(
      L('Your question report was incorporated',
          'Tu reporte de pregunta fue incorporado'),
      CL('The Cybersecurity question you flagged was corrected by the content team. Thanks!',
          'La pregunta de Ciberseguridad que reportaste fue corregida por el equipo de contenido. ¡Gracias!',
          'The FOD question you flagged was corrected by the content team. Thanks!',
          'La pregunta de FOD que reportaste fue corregida por el equipo de contenido. ¡Gracias!'),
      L('Yesterday', 'Ayer'),
    ),
    TestuNotice(
      CL('New resource in Human Rights', 'Nuevo recurso en Derechos Humanos',
          'New resource in Ramp Safety', 'Nuevo recurso en Seguridad en Rampa'),
      CL('“Grievance mechanisms guide” was added to your topic resources.',
          'Se añadió «Guía de mecanismos de reclamación» a los recursos de tu tema.',
          '“Winter operations addendum” was added to your topic resources.',
          'Se añadió «Anexo de operaciones de invierno» a los recursos de tu tema.'),
      L('Tuesday', 'Martes'),
      unread: false,
    ),
    TestuNotice(
      L('Certificate renewed', 'Certificado renovado'),
      CL('Your Human Rights certificate was renewed and verified by TestU.',
          'Tu certificado de Derechos Humanos fue renovado y verificado por TestU.',
          'Your FOD Prevention certificate was renewed and verified by TestU.',
          'Tu certificado de Prevención de FOD fue renovado y verificado por TestU.'),
      L('Aug 12', '12 ago'),
      unread: false,
    ),
  ];
}

/// Notice-body preview: [splitCite]'s stripped text (no citation, quote or
/// highlight markers), collapsed to one line and cut at [max] chars. Used
/// for the `tutorreply` local notice so a multi-line reply with a trailing
/// `[Title, p. N]` doesn't leak brackets/`>` into the notifications row.
String noticePreview(String reply, {int max = 120}) {
  final s = splitCite(reply).text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.length > max ? '${s.substring(0, max)}…' : s;
}

/// A local notice (demo events; live only `tutorreply`, see testu_tutor.dart).
void addTestuNotice(String title, String body, {String? type}) {
  _seed();
  testuNotices.value = [
    TestuNotice(title, body, L('Now', 'Ahora'), type: type),
    ...testuNotices.value,
  ];
}

// ---- Live store.
// ponytail: polling, switch to the websocket channel when EnterMedia exposes a per-user channel.

const _notificationsPath = 'services/testu/social/notifications.json';
const _markreadPath = 'services/testu/social/markread.json';
Timer? _poll;
bool _refreshing = false;

/// Swipe-deleted server rows, so a poll does not resurrect them.
/// ponytail: in memory only; a server-side delete when someone asks for it.
final _dismissed = <String>{};

/// Replaces the server rows with the newest 50; local rows (`id == null`)
/// stay in front. A failure keeps what is on screen.
Future<void> refreshTestuNotices({EmeHttp? http}) async {
  if (!testuLive || _refreshing) return;
  _refreshing = true;
  try {
    final data = await (http ?? DioEmeHttp()).getJson(_notificationsPath);
    testuNotices.value = [
      ...testuNotices.value.where((n) => n.id == null),
      for (final j in (data['notifications'] as List? ?? const []))
        if (!_dismissed.contains('${(j as Map)['id']}'))
          TestuNotice.fromJson(Map<String, dynamic>.from(j)),
    ];
  } catch (e) {
    debugPrint('TestU: notifications ($e)');
  } finally {
    _refreshing = false;
  }
}

/// Fetch now and every 60 s until [stopTestuNoticePolling]. Idempotent.
void startTestuNoticePolling() {
  if (!testuLive) return;
  refreshTestuNotices();
  _poll ??= Timer.periodic(
      const Duration(seconds: 60), (_) => refreshTestuNotices());
}

void stopTestuNoticePolling() {
  _poll?.cancel();
  _poll = null;
  // ponytail: a stranded true here (e.g. a torn-down refresh whose finally
  // never ran) would wedge every future refresh into a silent no-op.
  _refreshing = false;
}

/// Sign-out: nothing of this learner stays for the next one.
void clearTestuNotices() {
  stopTestuNoticePolling();
  _dismissed.clear();
  testuNotices.value = [];
}

void dismissTestuNotice(TestuNotice n) {
  if (n.id != null) _dismissed.add(n.id!);
  testuNotices.value = [
    for (final x in testuNotices.value)
      if (!identical(x, n)) x
  ];
}

/// Tells the server these rows were seen. Local state is untouched: the
/// screen's leave-marks-read sweep and swipe toggles keep their own rules.
Future<void> markTestuNoticesRead(Iterable<String> ids, {EmeHttp? http}) async {
  final list = ids.toList();
  if (!testuLive || list.isEmpty) return;
  try {
    await (http ?? DioEmeHttp())
        .postForm(_markreadPath, [MapEntry('ids', jsonEncode(list))]);
  } catch (e) {
    debugPrint('TestU: markread ($e)');
  }
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
                      key: const ValueKey('testu-bell-dot'),
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
  void initState() {
    super.initState();
    // The server learns these were seen now; the rows stay bold until the
    // learner leaves (dispose sweep) so what is new reads as new.
    markTestuNoticesRead(
        [for (final n in testuNotices.value) if (n.unread && n.id != null) n.id!]);
  }

  /// Reply, mention, reaction → the question's session (that question first,
  /// thread open, comment tinted) or the topic's review tab; tutorreply →
  /// the IRIS tab. Pops this screen first so the origin sits over the shell.
  void _open(TestuNotice n) {
    final target = testuNoticeTarget(n);
    if (target.tab == null && target.topicId == null) return;
    // The wrapping TestuPressable already fires the tap haptic.
    final nav = Navigator.of(context);
    nav.pop();
    // One door for "go to X": the shell selects the tab, pushes the origin
    // and (on web) writes the address.
    openLearnerRoute(LearnerRoute(target.tab ?? 1,
        topicId: target.topicId,
        questionId: target.questionId,
        messageId: target.messageId));
  }

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
              padding: const EdgeInsets.fromLTRB(18, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(L('Notifications', 'Notificaciones'),
                        style: kH1),
                  ),
                  TestuIconButton(TestuGlyph.close,
                      onTap: () => Navigator.of(context).pop()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Text(
                // Live: reports stay on-device for now, so no reviews to promise.
                testuLive
                    ? L('Replies, mentions and reactions on your comments, and answers from ${client.tutor} you missed. Anything that needs action stays on Today.',
                        'Respuestas, menciones y reacciones a tus comentarios, y respuestas de ${client.tutor} que te perdiste. Lo que requiere acción sigue en Hoy.')
                    : L('Reviews of your reports, content updates, certificates. Anything that needs action stays on Today.',
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
    // Deferred: the route unmounts mid-frame with the tree locked, and the
    // bell's ValueListenableBuilder cannot rebuild until the frame ends.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final n in testuNotices.value) {
        if (!_keepUnread.contains(n)) n.unread = false;
      }
      testuNotices.value = [...testuNotices.value];
    });
    super.dispose();
  }

  /// Row actions: swipe right = toggle read/unread (row springs back),
  /// swipe left = delete. Standard mail-app grammar, no hidden gestures.
  Widget _item(TestuTokens t, TestuNotice n, {bool showWhen = true}) {
    final target = testuNoticeTarget(n);
    final tappable = target.tab != null || target.topicId != null;
    return Dismissible(
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
        // ponytail: right-swipe toggles are local; the server was told "read"
        // on open, so a row kept unread here reads as read after the next poll.
        confirmDismiss: (dir) async {
          if (dir == DismissDirection.endToStart) return true;
          // Right swipe: toggle, never dismiss the row.
          HapticFeedback.selectionClick();
          n.unread = !n.unread;
          n.unread ? _keepUnread.add(n) : _keepUnread.remove(n);
          testuNotices.value = [...testuNotices.value];
          return false;
        },
        onDismissed: (_) => dismissTestuNotice(n),
        child: TestuPressable(
          onTap: tappable ? () => _open(n) : null,
          child: _row(t, n, showWhen: showWhen),
        ),
      );
  }

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
        if (n.isToday) n
    ];
    final earlier = [
      for (final n in items)
        if (!n.isToday) n
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      children: [
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(L('Nothing here yet.', 'Nada por aquí todavía.'),
                style: kMeta),
          ),
        if (today.isNotEmpty) ...[
          TestuEyebrow(L('TODAY', 'HOY')),
          for (final n in today) _item(t, n, showWhen: false),
          const SizedBox(height: 14),
        ],
        if (earlier.isNotEmpty) TestuEyebrow(L('EARLIER', 'ANTERIORES')),
        for (final n in earlier) _item(t, n),
      ],
    );
  }
}
