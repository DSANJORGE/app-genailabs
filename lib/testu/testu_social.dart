import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_icons.dart';
import 'testu_live.dart';
import 'testu_report_sheet.dart';
import 'testu_social_api.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';
import 'testu_client.dart';

// TestuComment and TestuReaction moved to testu_social_api.dart (2026-09-07,
// Part C social sync) so the API client can build/parse them without
// depending on Flutter; re-exported here so existing call sites don't move.
export 'testu_social_api.dart' show TestuComment, TestuReaction;

/// "Lucía P." — how the learner's own comments are signed.
String get _myShortName =>
    '$testuFirstName ${testuFullName.split(' ').last[0]}.';

/// Comment threads — THE one conversation surface for social learning.
/// Question threads and topic reviews share it (full alignment rule: vote,
/// reply, report work identically everywhere a thread appears).
///
/// Replies follow the LinkedIn model: one nesting level, replying to a reply
/// attaches to the same parent. Rendering is «Anidado» (chosen 2026-09-01,
/// revised same day): threads start CLOSED — only main comments listed, the
/// «Reply N» action unfolds that comment's replies (lighter rows under a 1px
/// hairline connector) together with the reply composer.
///
/// Reaction rule (app-wide, replaced the thumbs concept 2026-09-01): a
/// «Like» action — tap once to like, long-press for the reaction pill
/// (Like, Applause, Support, Love, Idea, Laugh). One reaction per user;
/// every type present on a comment shows in the cluster next to the total.
/// Reports go through the shared report sheet.
///
/// Thread data: the demo passes a mock list; live passes a channel and the
/// thread reads/writes services/testu/social/* through [TestuSocialApi].

/// Reusable thread: comments with vote/reply/report + bottom composer.
/// Demo: mutates [comments] in place. Live: [channel] is loaded from
/// thread.json and every send/reaction goes to the server, which is the
/// source of truth (author name, id, time) -- so a successful send reloads
/// instead of appending a local guess. [onChanged] lets the host refresh.
class TestuThread extends StatefulWidget {
  const TestuThread({
    super.key,
    this.comments,
    this.channel,
    this.api,
    required this.composerHint,
    required this.reportEyebrow,
    required this.reportTitle,
    this.onChanged,
    this.onCount,
    this.highlightMessageId,
  }) : assert(comments != null || channel != null, 'demo list or live channel');

  /// Demo rows, mutated in place. Null when [channel] is live.
  final List<TestuComment>? comments;

  /// `q-<entityquestion>` or `t-<entitytutorial>`. Null = demo.
  final String? channel;

  /// Live transport; the app's singleton unless a test or the console hands one in.
  final TestuSocialApi? api;
  final String composerHint;
  final String reportEyebrow;
  final String reportTitle;
  final VoidCallback? onChanged;

  /// Comments + replies on screen, after every load or send (the entry row's count).
  final ValueChanged<int>? onCount;

  /// Comment to tint for two seconds when the thread opens from a
  /// notification; its parent unfolds so the row is on screen.
  final String? highlightMessageId;

  @override
  State<TestuThread> createState() => _TestuThreadState();
}

class _TestuThreadState extends State<TestuThread> {
  late List<TestuComment> _comments = widget.comments ?? [];
  bool _loading = false;
  Object? _error;

  /// Parent comment whose inline reply composer is open, if any.
  TestuComment? _replyingTo;

  /// Who the composer addresses — the person whose Reply was tapped
  /// (a reply's author, not its parent, when tapped on a reply row).
  String _replyName = '';

  /// The comment actually addressed by the open reply composer -- a reply's
  /// own id when replying to a reply, so the server (which flattens storage
  /// to the top-level parent itself) can still resolve the real addressee's
  /// author for notifications. Null when addressing a top-level comment,
  /// where `parent` in [_post] already is that comment.
  TestuComment? _replyTarget;

  /// True while a send is in flight; the composer's send is a no-op meanwhile
  /// so a double-tap can't post the same comment twice.
  bool _sending = false;

  /// Parents whose replies are shown. Threads start CLOSED — only main
  /// comments listed; tapping «Reply N» opens that comment's replies and
  /// the composer underneath (tap again to fold).
  final _expanded = <TestuComment>{};

  /// Notification-driven highlight: the comment id to tint, cleared after
  /// two seconds. Armed once comments are actually on screen -- at once for
  /// the demo list, after [_load] for a live channel.
  String? _hl;
  Timer? _hlTimer;

  // Live composers own their controllers so a failed send keeps the text.
  // Each composer keeps the ids picked from the @ sheet for its own send.
  final _draft = TextEditingController();
  final _replyDraft = TextEditingController();
  final _draftMentions = <String>{};
  final _replyMentions = <String>{};
  List<Mentionable>? _people;

  bool get _live => widget.channel != null;
  TestuSocialApi get _api => widget.api ?? testuSocial;
  int get _count => _comments.fold(_comments.length, (a, c) => a + c.replies.length);

  @override
  void initState() {
    super.initState();
    _hl = widget.highlightMessageId;
    if (_live) {
      _load();
    } else if (_comments.isNotEmpty) {
      _armHighlight();
    }
  }

  /// Unfold the highlighted reply's parent so the row is on screen, then
  /// start the two-second tint. Guarded by `_hlTimer` so a reload (live)
  /// never re-arms an already-shown-and-faded highlight.
  void _armHighlight() {
    if (_hl == null || _hlTimer != null) return;
    for (final c in _comments) {
      if (c.replies.any((r) => r.id == _hl)) _expanded.add(c);
    }
    _hlTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _hl = null);
    });
  }

  @override
  void dispose() {
    _hlTimer?.cancel();
    _draft.dispose();
    _replyDraft.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.thread(widget.channel!);
      if (!mounted) return;
      // Unfolded parents stay unfolded across a reload: match by id.
      final open = {for (final c in _expanded) c.id};
      setState(() {
        _comments = rows;
        _expanded
          ..clear()
          ..addAll(rows.where((c) => open.contains(c.id)));
        _replyingTo = rows.where((c) => c.id == _replyingTo?.id).firstOrNull;
        _armHighlight();
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
    if (mounted) widget.onCount?.call(_count);
  }

  void _mutate(VoidCallback fn) {
    setState(fn);
    widget.onChanged?.call();
    widget.onCount?.call(_count);
  }

  void _snack(String text) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(text)));

  /// Live send. On failure the text stays where it was. A send already in
  /// flight makes this a no-op -- the composer has no disabled state of its
  /// own, so a double-tap must be caught here instead.
  Future<void> _post(TextEditingController ctl, Set<String> mentions, {TestuComment? parent}) async {
    if (_sending) return;
    final text = ctl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _api.comment(
          channel: widget.channel!,
          text: text,
          replyToId: (_replyTarget ?? parent)?.id,
          mentions: mentions.toList());
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      _snack(L('Could not send. Try again.', 'No se pudo enviar. Inténtalo de nuevo.'));
      return;
    }
    if (!mounted) return;
    setState(() => _sending = false);
    ctl.clear();
    mentions.clear();
    if (parent != null) {
      _expanded.add(parent);
      _replyingTo = null;
      _replyTarget = null;
    }
    await _load();
    widget.onChanged?.call();
  }

  /// Optimistic: TestuReactions already moved the counts; on success the
  /// server's own mine/reacts replace the optimistic guess (another
  /// reactor's write can race this one). A failed write reloads so the row
  /// shows the server's truth again.
  void _react(TestuComment c, TestuReaction? r) {
    _mutate(() => c.myReact = r);
    if (!_live) return;
    unawaited(_api.react(c.id, r).then((res) {
      if (!mounted) return;
      setState(() {
        c.myReact = res.mine;
        c.reacts
          ..clear()
          ..addAll(res.reacts);
      });
    }).catchError((Object _) {
      if (!mounted) return;
      _snack(L('Could not save your reaction.', 'No se pudo guardar tu reacción.'));
      _load();
    }));
  }

  /// The `@` picker: people from mentionables.json (fetched once per thread),
  /// a pick appends `@Nombre ` to the field and keeps the id for the send.
  /// [composerContext] is a context inside the calling composer's own
  /// (non-scoping) [Focus] node -- with two composers open (bottom thread
  /// composer + an expanded reply composer), looking up that node and
  /// requesting focus on its focusable descendant restores focus to this
  /// composer's own field, not whichever field is first in the whole page's
  /// tab order.
  Future<void> _pickMention(
      BuildContext composerContext, TextEditingController ctl, Set<String> mentions) async {
    HapticFeedback.selectionClick();
    try {
      _people ??= await _api.mentionables();
    } catch (_) {
      if (!mounted) return;
      _snack(L('Could not load people.', 'No se pudo cargar la lista de personas.'));
      return;
    }
    if (!mounted) return;
    final people = _people!;
    if (people.isEmpty) {
      _snack(L('Nobody to mention yet.', 'Todavía no hay a quién mencionar.'));
      return;
    }
    await showTestuListSheet(
      context,
      title: L('MENTION', 'MENCIONAR'),
      rows: [
        for (final p in people)
          (
            tag: null,
            label: p.name,
            trailing: roleBadge(p.role),
            selected: mentions.contains(p.id),
            indent: false,
            onTap: () {
              mentions.add(p.id);
              final t = ctl.text;
              ctl.text = '${t.isEmpty || t.endsWith(' ') ? t : '$t '}@${p.name} ';
              ctl.selection = TextSelection.collapsed(offset: ctl.text.length);
              // The sheet's own route took focus; hand it back to this
              // composer's own field so the pick reads as "insert and keep
              // typing" -- found via this composer's own Focus node so it
              // can't land on a different, also-open composer's field.
              if (composerContext.mounted) {
                final target = Focus.of(composerContext)
                    .descendants
                    .where((n) => n.canRequestFocus)
                    .firstOrNull;
                target?.requestFocus();
              }
            },
          ),
      ],
    );
  }

  /// Live composer: the house pill plus the `@` button. Wrapped in a plain,
  /// non-scoping [Focus] node -- not a [FocusScope] -- so `_pickMention`'s
  /// focus restore (below) can find this composer's own field via
  /// `descendants` without bounding Tab/`nextFocus()` traversal to this
  /// composer; a [FocusScope] would trap keyboard focus inside a
  /// single-field composer, breaking Tab-out on the web build.
  Widget _composer(TestuTokens t,
          {required String hint,
          required TextEditingController ctl,
          required Set<String> mentions,
          required Future<void> Function() onSend}) =>
      Focus(
        canRequestFocus: false,
        skipTraversal: true,
        child: Builder(
          builder: (ctx) => Row(children: [
            Expanded(child: TestuComposer(hint: hint, controller: ctl, onSend: (_) => onSend())),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              label: L('Mention someone', 'Mencionar a alguien'),
              child: TestuPressable(
                onTap: () => _pickMention(ctx, ctl, mentions),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration:
                      BoxDecoration(shape: BoxShape.circle, border: Border.all(color: t.line2)),
                  child: Text('@',
                      style: TextStyle(fontFamily: 'GeistMono', fontSize: 13, color: t.mut)),
                ),
              ),
            ),
          ]),
        ),
      );

  Widget _errorRow(TestuTokens t) => Row(children: [
        Expanded(
          child: Text(L('Could not load the conversation.', 'No se pudo cargar la conversación.'),
              style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: t.mut)),
        ),
        TestuAct(L('Retry', 'Reintentar'), onTap: _load),
      ]);

  /// Live rows have no photo: two initials on the house disc (Part A's rule).
  Widget _initials(TestuTokens t, String who, double size) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration:
            BoxDecoration(color: t.card2, shape: BoxShape.circle, border: Border.all(color: t.line2)),
        child: Text(
          who.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join().toUpperCase(),
          style: TextStyle(
              fontFamily: 'Geist', fontSize: size * 0.42, fontWeight: FontWeight.w600, color: t.mut),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    if (_live && _loading && _comments.isEmpty) {
      return const Column(children: [
        TestuSkeletonRow(thumb: 20, pill: false),
        TestuSkeletonRow(thumb: 20, pill: false),
      ]);
    }
    if (_live && _error != null && _comments.isEmpty) return _errorRow(t);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_live && _comments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
                L('Nobody has commented yet. Be the first.',
                    'Nadie ha comentado todavía. Sé la primera persona.'),
                style: TextStyle(fontFamily: 'Geist', fontSize: 12, color: t.mut)),
          ),
        for (final c in _comments) ..._commentBlock(t, c),
        const SizedBox(height: 4),
        if (_live)
          _composer(t,
              hint: widget.composerHint,
              ctl: _draft,
              mentions: _draftMentions,
              onSend: () => _post(_draft, _draftMentions))
        else
          TestuComposer(
            hint: widget.composerHint,
            onSend: (text) => _mutate(() => _comments.add(
                TestuComment(_myShortName, null, client.personaAvatar, text))),
          ),
      ],
    );
  }

  /// One top-level comment card; its replies (and the inline reply
  /// composer) unfold inside the hairline connector when expanded.
  List<Widget> _commentBlock(TestuTokens t, TestuComment c) => [
        _comment(t, c),
        if (_expanded.contains(c))
          Container(
            // Connector starts under the parent avatar's center line.
            margin: const EdgeInsets.only(left: 10, bottom: 4),
            padding: const EdgeInsets.only(left: 14),
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: t.line2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in c.replies) _comment(t, r, parent: c),
                if (_replyingTo == c)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _live
                        ? _composer(t,
                            hint: L('Reply to $_replyName…', 'Responde a $_replyName…'),
                            ctl: _replyDraft,
                            mentions: _replyMentions,
                            onSend: () => _post(_replyDraft, _replyMentions, parent: c))
                        : TestuComposer(
                            hint: L('Reply to $_replyName…', 'Responde a $_replyName…'),
                            onSend: (text) => _mutate(() {
                              c.replies.add(TestuComment(
                                  _myShortName, null, client.personaAvatar, text));
                              _expanded.add(c);
                              _replyingTo = null;
                            }),
                          ),
                  ),
              ],
            ),
          ),
      ];

  void _report(TestuComment c) {
    showTestuReportSheet(
      context,
      eyebrow: widget.reportEyebrow,
      title: widget.reportTitle,
      subtitle: L(
          'Marks the comment as reported on this device. The author is not notified.',
          'Marca el comentario como reportado en este dispositivo. El autor no recibe aviso.'),
      reasons: [
        L('Incorrect information', 'Información incorrecta'),
        L('Inappropriate', 'Inapropiado'),
        L('Off topic', 'Fuera de tema'),
        L('Other', 'Otro'),
      ],
      onSend: (_, _) => setState(() => c.reported = true),
    );
  }

  /// Top-level comments are cards; replies ([parent] non-null) are lighter
  /// open rows inside the connector (no box-in-box — the hairline alone
  /// carries the nesting).
  Widget _comment(TestuTokens t, TestuComment c, {TestuComment? parent}) {
    final reply = parent != null;
    final hl = _hl != null && c.id == _hl;
    return Container(
      margin: EdgeInsets.only(bottom: reply ? 12 : 10),
      // Replies keep the card's 12px right inset so their Report links
      // align exactly under the parent card's Report.
      padding: reply
          ? const EdgeInsets.only(right: 12)
          : const EdgeInsets.all(12),
      decoration: reply
          ? (hl ? BoxDecoration(color: t.amberTint) : null)
          : BoxDecoration(
              color: hl ? t.amberTint : t.card,
              border: Border.all(color: t.line2),
              borderRadius: BorderRadius.circular(12),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              c.avatar == null
                  ? _initials(t, c.who, reply ? 16 : 20)
                  : ClipOval(
                      child: Image.asset(c.avatar!,
                          width: reply ? 16 : 20, height: reply ? 16 : 20, fit: BoxFit.cover)),
              const SizedBox(width: 8),
              Text(c.who,
                  style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: reply ? 11 : 11.5,
                      fontWeight: FontWeight.w600,
                      color: t.ink)),
              if (c.role != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: t.greenBorder),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(c.role!,
                      style: TextStyle(
                          fontFamily: 'GeistMono',
                          fontSize: 7.5,
                          letterSpacing: 0.6,
                          color: t.greenText)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
          Text(c.text,
              style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: reply ? 12 : 12.5,
                  height: 1.5,
                  color: t.inkDim)),
          const SizedBox(height: 7),
          Row(
            children: [
              TestuReactions(
                reacts: c.reacts,
                mine: c.myReact,
                onChanged: (r) => _react(c, r),
              ),
              const SizedBox(width: 14),
              TestuPressable(
                onTap: () => setState(() {
                  if (reply) {
                    // Replying to a reply targets its parent (LinkedIn
                    // model) but addresses the reply's author; tapping
                    // the same person's Reply again closes the composer.
                    // _replyTarget carries the reply's own id so the
                    // server can resolve the real addressee, even though
                    // storage still flattens under `parent`.
                    if (_replyingTo == parent && _replyName == c.who) {
                      _replyingTo = null;
                      _replyTarget = null;
                    } else {
                      _replyingTo = parent;
                      _replyName = c.who;
                      _replyTarget = c;
                    }
                  } else if (_expanded.contains(c)) {
                    _expanded.remove(c);
                    if (_replyingTo == c) {
                      _replyingTo = null;
                      _replyTarget = null;
                    }
                  } else {
                    _expanded.add(c);
                    _replyingTo = c;
                    _replyName = c.who;
                    _replyTarget = null;
                  }
                }),
                // «Reply N» — N = replies waiting under this comment. The
                // count stays quiet (mono faint), same rule as the reaction
                // total: numbers never wear the bold label style.
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(L('Reply', 'Responder'),
                      style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: t.mut)),
                  if (!reply && c.replies.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text('${c.replies.length}',
                        style: TextStyle(
                            fontFamily: 'GeistMono',
                            fontSize: 10,
                            color: t.faint)),
                  ],
                ]),
              ),
              const Spacer(),
              if (c.reported)
                Text(L('Reported', 'Reportado'),
                    style: TextStyle(fontSize: 10, color: t.faint))
              else
                TestuPressable(
                  onTap: () => _report(c),
                  child: Text(L('Report', 'Reportar'),
                      style: TextStyle(
                          fontSize: 10,
                          decoration: TextDecoration.underline,
                          decorationColor: t.idle,
                          color: t.faint)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Question thread (session view) — collapsible entry under the verdict.
// ---------------------------------------------------------------------------

List<TestuComment> _mockThread() {
  if (client.name == 'Minsur') {
    final lucia = TestuComment(
        'Lucía M.',
        null,
        'assets/img/p_laia.jpg',
        L('The part about who human rights apply to confused me — I thought it was only our own employees.',
            'Me confundió a quiénes aplican los Derechos Humanos — pensaba que era solo a nuestros propios trabajadores.'),
        reacts: {TestuReaction.like: 3, TestuReaction.support: 1});
    lucia.replies.addAll([
      TestuComment(
          'Jorge P.',
          'INSTRUCTOR',
          'assets/img/p_jordi.jpg',
          L('They apply to everyone equally: employees, contractors, visitors and neighbouring communities. The company relationship does not change the right.',
              'Aplican a todas las personas por igual: propios, contratistas, visitantes y comunidades vecinas. El vínculo con la empresa no cambia el derecho.'),
          reacts: {
            TestuReaction.like: 7,
            TestuReaction.idea: 3,
            TestuReaction.applause: 1,
          }),
      TestuComment(
          client.tutor,
          L('AI TUTOR', 'TUTOR IA'),
          client.tutorAvatar,
          L('I attached the policy reference to this conversation for anyone who wants the source.',
              'He añadido la referencia de la política a esta conversación para quien quiera la fuente.')),
    ]);
    return [
      lucia,
      TestuComment(
          'Carlos V.',
          null,
          'assets/img/p_karsten.jpg',
          L('Same at our site — I keep it simple: every person on the operation, no exceptions.',
              'Igual en nuestra unidad — yo lo simplifico: toda persona en la operación, sin excepciones.'),
          reacts: {TestuReaction.like: 2}),
    ];
  }
  final laia = TestuComment(
      'Laia M.',
      null,
      'assets/img/p_laia.jpg',
      L('The anticollision-lights part confused me too — at my stand we wait for the captain\'s signal.',
          'A mí también me confundió lo de las luces anticolisión — en mi puesto esperamos la señal del capitán.'),
      reacts: {TestuReaction.like: 3, TestuReaction.support: 1});
  laia.replies.addAll([
    TestuComment(
        'Jordi P.',
        'INSTRUCTOR',
        'assets/img/p_jordi.jpg',
        L('Careful: the reference is engines off AND anticollision lights off. The captain\'s signal is an extra step at some bases, not the trigger.',
            'Ojo: la referencia es motores apagados Y luces anticolisión apagadas. La señal del capitán es un paso extra en algunas bases, no el disparador.'),
        reacts: {
          TestuReaction.like: 7,
          TestuReaction.idea: 3,
          TestuReaction.applause: 1,
        }),
    TestuComment(
        client.tutor,
        L('AI TUTOR', 'TUTOR IA'),
        client.tutorAvatar,
        L('I attached the manual citation (p. 12) to this conversation for anyone who wants the source.',
            'He añadido la cita del manual (p. 12) a esta conversación para quien quiera la fuente.')),
  ]);
  return [
    laia,
    TestuComment(
        'Karsten V.',
        null,
        'assets/img/p_karsten.jpg',
        L('Same rule at outstations — I keep it simple: no lights, no chocks conversation.',
            'Misma regla en escalas — yo lo simplifico: sin luces apagadas, no hay conversación de calzos.'),
        reacts: {TestuReaction.like: 2}),
  ];
}

/// Social learning thread on a question — appears under the verdict, only
/// after answer AND confidence are submitted, expanding INLINE in the
/// transcript (chosen over sheet/screen variants, 2026-08-31).
class SocialThreadEntry extends StatefulWidget {
  const SocialThreadEntry({super.key, this.channel, this.highlightMessageId});

  /// Live channel (`q-<entityquestion>`); null shows the demo's mock thread.
  final String? channel;

  /// Set by a notification tap: the entry starts open on that comment.
  final String? highlightMessageId;

  @override
  State<SocialThreadEntry> createState() => _SocialThreadEntryState();
}

class _SocialThreadEntryState extends State<SocialThreadEntry> {
  late final List<TestuComment>? _thread = widget.channel == null ? _mockThread() : null;
  late bool _open = widget.highlightMessageId != null;

  /// Live: known once the thread has loaded (it loads on first open), so the
  /// row reads "Conversaciones sobre esta pregunta" until then.
  int? _liveCount;

  int? get _count => _thread == null
      ? _liveCount
      : _thread.fold<int>(_thread.length, (a, c) => a + c.replies.length);

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final n = _count;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TestuPressable(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _open = !_open);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                TestuIcon(TestuGlyph.chat, size: 13, color: t.faint),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    n == null
                        ? L('Conversations on this question', 'Conversaciones sobre esta pregunta')
                        : L('Conversations on this question · $n',
                            'Conversaciones sobre esta pregunta · $n'),
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 10.5,
                      letterSpacing: 0.42,
                      color: t.mut,
                    ),
                  ),
                ),
                TestuIcon(_open ? TestuGlyph.minus : TestuGlyph.plus,
                    size: 13, color: t.faint),
              ],
            ),
          ),
        ),
        if (_open)
          TestuThread(
            comments: _thread,
            channel: widget.channel,
            composerHint: L('Reply to the thread…', 'Responde al hilo…'),
            reportEyebrow:
                L('CONVERSATION · REPORT', 'CONVERSACIÓN · REPORTAR'),
            reportTitle: L('Report this comment', 'Reportar este comentario'),
            onChanged: () => setState(() {}),
            onCount: (c) {
              if (mounted) setState(() => _liveCount = c);
            },
            highlightMessageId: widget.highlightMessageId,
          ),
      ],
    );
  }
}

/// App-wide reaction affordance (replaced TestuVote 2026-09-01). LinkedIn
/// logic: tap = quick Like (tap again removes it); long-press opens the
/// reaction pill with the six house glyphs. The label takes the name and
/// color of your reaction; the cluster shows every type present + total.
/// (TestuReaction itself lives in testu_social_api.dart, re-exported above.)

TestuGlyph _rGlyph(TestuReaction r) => switch (r) {
      TestuReaction.like => TestuGlyph.thumbUp,
      TestuReaction.applause => TestuGlyph.applause,
      TestuReaction.support => TestuGlyph.support,
      TestuReaction.love => TestuGlyph.love,
      TestuReaction.idea => TestuGlyph.idea,
      TestuReaction.laugh => TestuGlyph.laugh,
    };

String _rLabel(TestuReaction r) => switch (r) {
      TestuReaction.like => L('Like', 'Me gusta'),
      TestuReaction.applause => L('Applause', 'Aplauso'),
      TestuReaction.support => L('Support', 'Apoyo'),
      TestuReaction.love => L('Love', 'Me encanta'),
      TestuReaction.idea => L('Idea', 'Idea'),
      TestuReaction.laugh => L('Laugh', 'Risa'),
    };

// LinkedIn's semantics translated to the house palette (2026-09-01):
// applause=green (Celebrate), support=violet, love=red, idea=amber
// (Insightful's yellow family) match LinkedIn hue-for-hue. Like takes the
// brand orange, NOT LinkedIn blue — blue is reserved for source links, and
// a blue reaction would read as a tappable link. Laugh's light-blue is out
// for the same reason; it stays ink (neutral).
Color _rColor(TestuReaction r, TestuTokens t) => switch (r) {
      TestuReaction.like => t.orange,
      TestuReaction.applause => t.green,
      TestuReaction.support => t.violet,
      TestuReaction.love => t.red,
      TestuReaction.idea => t.amber,
      TestuReaction.laugh => t.ink,
    };

class TestuReactions extends StatefulWidget {
  const TestuReactions({
    super.key,
    required this.reacts,
    required this.mine,
    required this.onChanged,
  });

  /// Count per reaction type present. Mutated in place by this widget.
  final Map<TestuReaction, int> reacts;

  /// The user's own reaction, if any (host owns it — one per user).
  final TestuReaction? mine;

  /// Reports the new own-reaction (null = removed); counts already updated.
  final ValueChanged<TestuReaction?> onChanged;

  @override
  State<TestuReactions> createState() => _TestuReactionsState();
}

class _TestuReactionsState extends State<TestuReactions> {
  final _link = LayerLink();
  final _pillKey = GlobalKey();
  OverlayEntry? _menu;

  /// Chip index under the finger while sliding through the open pill —
  /// drives the magnified chip and the name tooltip above it.
  int? _hover;

  // Pill geometry (padding 6 + 36px chips) — the slide hit-test depends
  // on these staying in sync with the overlay build below.
  static const _pad = 6.0;
  static const _chip = 36.0;

  @override
  void dispose() {
    _menu?.remove();
    super.dispose();
  }

  void _set(TestuReaction? r) {
    final old = widget.mine;
    if (old != null) {
      final n = (widget.reacts[old] ?? 1) - 1;
      n <= 0 ? widget.reacts.remove(old) : widget.reacts[old] = n;
    }
    if (r != null) widget.reacts[r] = (widget.reacts[r] ?? 0) + 1;
    widget.onChanged(r);
  }

  void _close() {
    _hover = null;
    _menu?.remove();
    _menu = null;
  }

  void _setHover(int? h) {
    if (_hover == h) return;
    _hover = h;
    if (h != null) HapticFeedback.selectionClick();
    _menu?.markNeedsBuild();
  }

  /// LinkedIn slide: while the long press is held, the finger position
  /// highlights the chip underneath and shows its name tooltip.
  void _slideTo(Offset global) {
    final box = _pillKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final l = box.globalToLocal(global);
    final inside = l.dy > -30 &&
        l.dy < box.size.height + 16 &&
        l.dx >= _pad &&
        l.dx < box.size.width - _pad;
    _setHover(inside
        ? ((l.dx - _pad) ~/ _chip).clamp(0, TestuReaction.values.length - 1)
        : null);
  }

  /// Releasing over a chip selects it; releasing elsewhere keeps the pill
  /// open for tapping (LinkedIn behavior).
  void _release() {
    final h = _hover;
    if (h == null) return;
    final r = TestuReaction.values[h];
    _close();
    _set(widget.mine == r ? null : r);
  }

  void _openMenu() {
    if (_menu != null) return;
    HapticFeedback.mediumImpact();
    final t = TestuTokens.of(context);
    _menu = OverlayEntry(
      builder: (_) => Stack(children: [
        Positioned.fill(
          child: GestureDetector(
              behavior: HitTestBehavior.opaque, onTap: _close),
        ),
        CompositedTransformFollower(
          link: _link,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(-6, -10),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Constant-height tooltip slot so the pill never shifts.
                SizedBox(
                  height: 26,
                  child: _hover == null
                      ? null
                      : Padding(
                          padding:
                              EdgeInsets.only(left: _pad + _chip * _hover!),
                          child: SizedBox(
                            width: _chip,
                            child: Center(
                              child: OverflowBox(
                                maxWidth: 140,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: t.card2,
                                    border: Border.all(color: t.line2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                      _rLabel(TestuReaction.values[_hover!]),
                                      style: TextStyle(
                                          fontFamily: 'Geist',
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: t.ink)),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                Container(
                  key: _pillKey,
                  padding: const EdgeInsets.all(_pad),
                  decoration: BoxDecoration(
                    color: t.card2,
                    border: Border.all(color: t.line2),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 18,
                          offset: Offset(0, 6)),
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (final (i, r) in TestuReaction.values.indexed)
                      TestuPressable(
                        onTap: () {
                          _close();
                          _set(widget.mine == r ? null : r);
                        },
                        child: AnimatedScale(
                          scale: _hover == i ? 1.25 : 1,
                          duration: const Duration(milliseconds: 120),
                          curve: TestuTokens.curve,
                          child: Container(
                            width: _chip,
                            height: _chip,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.mine == r || _hover == i
                                  ? _rColor(r, t).withValues(alpha: 0.16)
                                  : null,
                            ),
                            child: TestuIcon(_rGlyph(r),
                                size: 18, color: _rColor(r, t)),
                          ),
                        ),
                      ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ]),
    );
    Overlay.of(context).insert(_menu!);
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final mine = widget.mine;
    final types = widget.reacts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = types.fold(0, (a, e) => a + e.value);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CompositedTransformTarget(
        link: _link,
        child: GestureDetector(
          onLongPressStart: (_) => _openMenu(),
          onLongPressMoveUpdate: (d) => _slideTo(d.globalPosition),
          onLongPressEnd: (_) => _release(),
          child: TestuPressable(
            onTap: () => _set(mine == null ? TestuReaction.like : null),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(_rLabel(mine ?? TestuReaction.like),
                  style: TextStyle(
                    fontFamily: 'Geist',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: mine == null ? t.mut : _rColor(mine, t),
                  )),
            ),
          ),
        ),
      ),
      // The cluster + total opens the who-reacted sheet; the count stays
      // quiet (mono faint) whether or not your own reaction is in it.
      if (types.isNotEmpty)
        TestuPressable(
          onTap: () => showTestuReactionsSheet(context,
              reacts: widget.reacts, mine: mine),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(width: 7),
              for (final e in types.take(3))
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: TestuIcon(_rGlyph(e.key),
                      size: 11, color: _rColor(e.key, t)),
                ),
              const SizedBox(width: 3),
              Text('$total',
                  style: TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 10,
                      color: t.faint)),
            ]),
          ),
        ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// Who-reacted detail sheet — tap a comment's reaction cluster to open.
// LinkedIn expanded view: filter tabs (All + one per type) over the list
// of people, each with their reaction badged on the avatar.
// ponytail: names come from a demo roster assigned deterministically to the
// counts until the backend knows real reactors.
// ---------------------------------------------------------------------------

void showTestuReactionsSheet(BuildContext context,
    {required Map<TestuReaction, int> reacts, TestuReaction? mine}) {
  HapticFeedback.selectionClick();
  final roster = client.name == 'Minsur'
      ? <(String, String)>[
          ('Lucía M.', L('Operations · Mine', 'Operaciones · Mina')),
          ('Jorge P.', L('Supervisor · Plant', 'Supervisor · Planta')),
          ('Carlos V.', L('Maintenance', 'Mantenimiento')),
          ('Rosa J.', L('Geology', 'Geología')),
          ('Pedro G.', L('Operations · Plant', 'Operaciones · Planta')),
          ('Nadia R.', L('Safety & Health', 'Seguridad y Salud')),
          ('Tomás E.', L('Environment', 'Medio Ambiente')),
          ('Elena K.', L('Logistics', 'Logística')),
          ('Marco S.', L('Shift coordinator', 'Coordinación de guardia')),
          ('Sofía B.', L('Community relations', 'Relaciones comunitarias')),
          ('Óscar W.', L('Operations · Night shift', 'Operaciones · Turno de noche')),
        ]
      : <(String, String)>[
          ('Laia M.', L('Ramp ops · T1', 'Rampa · T1')),
          ('Jordi P.', L('Instructor · Ground ops', 'Instructor · Ops en tierra')),
          ('Karsten V.', L('Ramp ops · Outstations', 'Rampa · Escalas')),
          ('Miranda J.', L('Load control', 'Control de carga')),
          ('Pau G.', L('Ramp ops · T2', 'Rampa · T2')),
          ('Nadia R.', L('Ramp ops · T1', 'Rampa · T1')),
          ('Tomás E.', L('GSE maintenance', 'Mantenimiento GSE')),
          ('Ewa K.', L('Ramp ops · Cargo', 'Rampa · Carga')),
          ('Marc S.', L('Turnaround coordinator', 'Coordinación de turnaround')),
          ('Iris B.', L('Ramp ops · T2', 'Rampa · T2')),
          ('Olek W.', L('Ramp ops · Night shift', 'Rampa · Turno de noche')),
        ];
  // ponytail: live shows the learner's real org (empty until it loads
  // rather than an invented title); demo keeps its canned role, unchanged.
  final myRole = testuLive
      ? testuOrganization.value
      : (client.name == 'Minsur'
          ? L('Operations · Mine', 'Operaciones · Mina')
          : L('Ramp ops · T1', 'Rampa · T1'));
  final sorted = reacts.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final rows = <(String who, String role, TestuReaction r, bool you)>[
    if (mine != null) (_myShortName, myRole, mine, true),
  ];
  var i = 0;
  for (final e in sorted) {
    var n = e.value - (mine == e.key ? 1 : 0);
    while (n-- > 0) {
      final p = roster[i++ % roster.length];
      rows.add((p.$1, p.$2, e.key, false));
    }
  }
  showTestuSheet<void>(
    context,
    maxHeight: 0.66,
    builder: (context) {
      final t = TestuTokens.of(context);
      TestuReaction? filter;
      return StatefulBuilder(builder: (context, setSheet) {
        final shown =
            filter == null ? rows : rows.where((r) => r.$3 == filter).toList();
        Widget tab(Widget child, bool active, VoidCallback onTap) =>
            TestuPressable(
              onTap: () {
                HapticFeedback.selectionClick();
                setSheet(onTap);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 18),
                padding: const EdgeInsets.only(bottom: 9),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        width: 2,
                        color: active ? t.orange : Colors.transparent),
                  ),
                ),
                child: child,
              ),
            );
        return Padding(
          padding: EdgeInsets.only(
              bottom: 14 + MediaQuery.paddingOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const TestuGrabber(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(children: [
                tab(
                  Text('${L('All', 'Todas')} ${rows.length}',
                      style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: filter == null ? t.ink : t.mut)),
                  filter == null,
                  () => filter = null,
                ),
                for (final e in sorted)
                  tab(
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      TestuIcon(_rGlyph(e.key),
                          size: 12, color: _rColor(e.key, t)),
                      const SizedBox(width: 5),
                      Text('${e.value}',
                          style: TextStyle(
                              fontFamily: 'GeistMono',
                              fontSize: 11,
                              color: filter == e.key ? t.ink : t.mut)),
                    ]),
                    filter == e.key,
                    () => filter = e.key,
                  ),
              ]),
            ),
            Container(height: 1, color: t.line),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                children: [
                  for (final r in shown)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      child: Row(children: [
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: t.card2,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: t.line2),
                                ),
                                child: Text(
                                    r.$1
                                        .split(' ')
                                        .map((w) => w[0])
                                        .take(2)
                                        .join(),
                                    style: TextStyle(
                                        fontFamily: 'Geist',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: t.mut)),
                              ),
                              Positioned(
                                right: -1,
                                bottom: -1,
                                child: Container(
                                  width: 17,
                                  height: 17,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: t.card,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: t.line2),
                                  ),
                                  child: TestuIcon(_rGlyph(r.$3),
                                      size: 9, color: _rColor(r.$3, t)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  r.$4
                                      ? '${r.$1} · ${L('You', 'Tú')}'
                                      : r.$1,
                                  style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: t.ink)),
                              // Live: an empty org (not yet loaded) means no
                              // role line rather than an invented one.
                              if (r.$2.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(r.$2,
                                    style: TextStyle(
                                        fontFamily: 'Geist',
                                        fontSize: 10.5,
                                        color: t.mut)),
                              ],
                            ],
                          ),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
          ]),
        );
      });
    },
  );
}
