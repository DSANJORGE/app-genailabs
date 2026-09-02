import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_icons.dart';
import 'testu_report_sheet.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

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
/// ponytail: thread data is mock until the backend chat channel exists.

class TestuComment {
  TestuComment(this.who, this.role, this.avatar, this.text,
      {Map<TestuReaction, int>? reacts})
      : reacts = reacts ?? {};
  final String who;
  final String? role; // badge, null = learner
  final String avatar;
  final String text;
  final List<TestuComment> replies = [];
  final Map<TestuReaction, int> reacts;
  TestuReaction? myReact;
  bool reported = false;
}

/// Reusable thread: comments with vote/reply/report + bottom composer.
/// Mutates [comments] in place; [onChanged] lets the host refresh counts.
class TestuThread extends StatefulWidget {
  const TestuThread({
    super.key,
    required this.comments,
    required this.composerHint,
    required this.reportEyebrow,
    required this.reportTitle,
    this.onChanged,
  });

  final List<TestuComment> comments;
  final String composerHint;
  final String reportEyebrow;
  final String reportTitle;
  final VoidCallback? onChanged;

  @override
  State<TestuThread> createState() => _TestuThreadState();
}

class _TestuThreadState extends State<TestuThread> {
  /// Parent comment whose inline reply composer is open, if any.
  TestuComment? _replyingTo;

  /// Who the composer addresses — the person whose Reply was tapped
  /// (a reply's author, not its parent, when tapped on a reply row).
  String _replyName = '';

  /// Parents whose replies are shown. Threads start CLOSED — only main
  /// comments listed; tapping «Reply N» opens that comment's replies and
  /// the composer underneath (tap again to fold).
  final _expanded = <TestuComment>{};

  void _mutate(VoidCallback fn) {
    setState(fn);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final c in widget.comments) ..._commentBlock(t, c),
        const SizedBox(height: 4),
        TestuComposer(
          hint: widget.composerHint,
          onSend: (text) => _mutate(() => widget.comments.add(
              TestuComment('Ana R.', null, 'assets/img/p_ana.jpg', text))),
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
                    child: TestuComposer(
                      hint: L('Reply to $_replyName…', 'Responde a $_replyName…'),
                      onSend: (text) => _mutate(() {
                        c.replies.add(TestuComment(
                            'Ana R.', null, 'assets/img/p_ana.jpg', text));
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
          'An instructor will review it. The author is not notified.',
          'Un instructor lo revisará. El autor no recibe aviso.'),
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
    return Container(
      margin: EdgeInsets.only(bottom: reply ? 12 : 10),
      // Replies keep the card's 12px right inset so their Report links
      // align exactly under the parent card's Report.
      padding: reply
          ? const EdgeInsets.only(right: 12)
          : const EdgeInsets.all(12),
      decoration: reply
          ? null
          : BoxDecoration(
              color: const Color(0xFF141416),
              border: Border.all(color: t.line2),
              borderRadius: BorderRadius.circular(12),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipOval(
                  child: Image.asset(c.avatar,
                      width: reply ? 16 : 20,
                      height: reply ? 16 : 20,
                      fit: BoxFit.cover)),
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
                    border: Border.all(color: const Color(0xFF2F6A4C)),
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
                  color: const Color(0xFFC2C1BD))),
          const SizedBox(height: 7),
          Row(
            children: [
              TestuReactions(
                reacts: c.reacts,
                mine: c.myReact,
                onChanged: (r) => _mutate(() => c.myReact = r),
              ),
              const SizedBox(width: 14),
              TestuPressable(
                onTap: () => setState(() {
                  if (reply) {
                    // Replying to a reply targets its parent (LinkedIn
                    // model) but addresses the reply's author; tapping
                    // the same person's Reply again closes the composer.
                    if (_replyingTo == parent && _replyName == c.who) {
                      _replyingTo = null;
                    } else {
                      _replyingTo = parent;
                      _replyName = c.who;
                    }
                  } else if (_expanded.contains(c)) {
                    _expanded.remove(c);
                    if (_replyingTo == c) _replyingTo = null;
                  } else {
                    _expanded.add(c);
                    _replyingTo = c;
                    _replyName = c.who;
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
                          decorationColor: const Color(0xFF3A3A40),
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
        'Sully',
        L('AI TUTOR', 'TUTOR IA'),
        'assets/img/sully.png',
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
  const SocialThreadEntry({super.key});

  @override
  State<SocialThreadEntry> createState() => _SocialThreadEntryState();
}

class _SocialThreadEntryState extends State<SocialThreadEntry> {
  final _thread = _mockThread();
  bool _open = false;

  int get _count =>
      _thread.fold(_thread.length, (a, c) => a + c.replies.length);

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
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
                    L('Conversations on this question · $_count',
                        'Conversaciones sobre esta pregunta · $_count'),
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 10.5,
                      letterSpacing: 0.42,
                      color: t.mut,
                    ),
                  ),
                ),
                Text(_open ? '−' : '+',
                    style: TextStyle(fontSize: 13, color: t.faint)),
              ],
            ),
          ),
        ),
        if (_open)
          TestuThread(
            comments: _thread,
            composerHint: L('Reply to the thread…', 'Responde al hilo…'),
            reportEyebrow:
                L('CONVERSATION · REPORT', 'CONVERSACIÓN · REPORTAR'),
            reportTitle: L('Report this comment', 'Reportar este comentario'),
            onChanged: () => setState(() {}),
          ),
      ],
    );
  }
}

/// App-wide reaction affordance (replaced TestuVote 2026-09-01). LinkedIn
/// logic: tap = quick Like (tap again removes it); long-press opens the
/// reaction pill with the six house glyphs. The label takes the name and
/// color of your reaction; the cluster shows every type present + total.
enum TestuReaction { like, applause, support, love, idea, laugh }

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
  final roster = <(String, String)>[
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
  final sorted = reacts.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final rows = <(String who, String role, TestuReaction r, bool you)>[
    if (mine != null) ('Ana R.', L('Ramp ops · T1', 'Rampa · T1'), mine, true),
  ];
  var i = 0;
  for (final e in sorted) {
    var n = e.value - (mine == e.key ? 1 : 0);
    while (n-- > 0) {
      final p = roster[i++ % roster.length];
      rows.add((p.$1, p.$2, e.key, false));
    }
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xA8000000),
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
        return Container(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.66),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border(top: BorderSide(color: t.line2)),
          ),
          padding: EdgeInsets.only(
              bottom: 14 + MediaQuery.paddingOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 14, bottom: 18),
              decoration: BoxDecoration(
                color: t.line2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
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
                              const SizedBox(height: 2),
                              Text(r.$2,
                                  style: TextStyle(
                                      fontFamily: 'Geist',
                                      fontSize: 10.5,
                                      color: t.mut)),
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
