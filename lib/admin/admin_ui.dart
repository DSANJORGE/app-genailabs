import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import '../testu/testu_widgets.dart';
import 'admin_charts.dart';
import 'admin_models.dart';
import 'admin_nav.dart';
import 'admin_theme.dart';

/// The console's component system (spec analytics-v1 §5). Every screen is
/// assembled from these; none of them reach for a Material data widget, so
/// the desktop face of TestU keeps the app's voice — hairlines, mono
/// numbers, one orange accent, no cards inside cards.

// ---------------------------------------------------------------- primitives

/// Hover + keyboard + focus ring in one place, so every interactive thing in
/// the console behaves identically: click, Enter/Space, a 1 px `ink` at 60 %
/// ring (spec §5), and a pointer cursor. The ring is painted over the child
/// rather than around it, so focus never moves the layout.
class _Interactive extends StatefulWidget {
  const _Interactive({
    required this.onTap,
    required this.builder,
    this.radius = 7,
    this.semanticLabel,
  });

  final VoidCallback? onTap;
  final Widget Function(BuildContext context, bool hovered) builder;
  final double radius;
  final String? semanticLabel;

  @override
  State<_Interactive> createState() => _InteractiveState();
}

class _InteractiveState extends State<_Interactive> {
  bool _hovered = false;
  bool _focused = false;

  void _activate() => widget.onTap?.call();

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final enabled = widget.onTap != null;
    Widget child = widget.builder(context, _hovered && enabled);
    if (_focused) {
      child = Stack(
        children: [
          child,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border:
                      Border.all(color: t.ink.withValues(alpha: 0.6)),
                  borderRadius: BorderRadius.circular(widget.radius),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return FocusableActionDetector(
      enabled: enabled,
      mouseCursor:
          enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hovered = v),
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => _activate()),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) => _activate()),
      },
      child: Semantics(
        button: enabled,
        label: widget.semanticLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: child,
        ),
      ),
    );
  }
}

/// 1 px `line` rule — the console's only separator.
class _Hairline extends StatelessWidget {
  const _Hairline({this.vertical = false});

  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return vertical
        ? Container(width: 1, color: t.line)
        : Container(height: 1, color: t.line);
  }
}

/// State crossfade — 200 ms, zero when the platform asks for no animation.
/// Wrap anything that swaps between skeleton, error and content.
Widget crossfade(Widget child) => _Crossfade(child: child);

class _Crossfade extends StatelessWidget {
  const _Crossfade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: AdminTokens.dur(context, 200),
        switchInCurve: TestuTokens.curve,
        switchOutCurve: TestuTokens.curve,
        child: child,
      );
}

/// One 600 ms `focus` ring when [active] turns true — how an Iris citation
/// points at the element it is quoting.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> {
  bool _ring = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _arm();
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) _arm();
  }

  /// Ring on instantly, then fade out over 600 ms — the fade is the pulse.
  void _arm() {
    _ring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ring = false);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: _ring ? Duration.zero : AdminTokens.dur(context, 600),
        curve: TestuTokens.curve,
        decoration: BoxDecoration(
          border: Border.all(
              color: _ring ? AdminTokens.focus : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
        ),
        child: widget.child,
      );
}

/// Bottom-right notice, `card2` on a hairline, gone after 4 s. Replaces
/// `SnackBar`, which docks to the bottom of a phone screen and covers the
/// content column on a laptop.
void showToast(BuildContext context, String text, {bool error = false}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  const t = TestuTokens.instance;
  late final OverlayEntry entry;
  var removed = false;
  void remove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => Positioned(
      right: 24,
      bottom: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: t.card2,
            border: Border.all(color: t.line),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 12.5,
              height: 1.4,
              color: error ? AdminTokens.redText : t.ink,
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Timer(const Duration(seconds: 4), remove);
}

// -------------------------------------------------------------------- shell

/// The console frame: 220 px text-only nav, the content column capped at
/// 1280 px, and an optional 360 px end panel (Iris).
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.org,
    required this.me,
    required this.sections,
    required this.nav,
    required this.title,
    required this.body,
    this.contextBar,
    this.endPanel,
    required this.onSignOut,
  });

  final String org;
  final AdminMe me;

  /// `(id, label)` — the id is what [ConsoleNav.go] receives.
  final List<(String, String)> sections;
  final ConsoleNav nav;
  final String title;
  final Widget body;
  final Widget? contextBar;
  final Widget? endPanel;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return ColoredBox(
      color: t.bg,
      child: LayoutBuilder(
        builder: (context, box) {
          // The console is a laptop surface; below 900 px it says so rather
          // than reflowing into something no one designed.
          if (box.maxWidth < 900) return const _TooNarrow();
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Nav(
                org: org,
                me: me,
                sections: sections,
                nav: nav,
                onSignOut: onSignOut,
              ),
              Expanded(child: _content(context)),
              if (endPanel != null)
                Container(
                  width: 360,
                  decoration: BoxDecoration(
                    color: t.card,
                    border: Border(left: BorderSide(color: t.line)),
                  ),
                  child: endPanel,
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _content(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              // stretch is what makes the column take the capped width
              // instead of collapsing to its widest child.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AdminTokens.title),
                const SizedBox(height: 16),
                if (contextBar != null) ...[
                  contextBar!,
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [body],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _TooNarrow extends StatelessWidget {
  const _TooNarrow();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            L('The console needs a laptop screen, 1024 px or wider.',
                'La consola necesita una pantalla de portátil, 1024 px o más.'),
            textAlign: TextAlign.center,
            style: AdminTokens.body,
          ),
        ),
      );
}

/// Text-only side nav — the app's bottom bar stood on its end: no icons, a
/// 2 px `focus` tick above the active label.
class _Nav extends StatelessWidget {
  const _Nav({
    required this.org,
    required this.me,
    required this.sections,
    required this.nav,
    required this.onSignOut,
  });

  final String org;
  final AdminMe me;
  final List<(String, String)> sections;
  final ConsoleNav nav;
  final VoidCallback onSignOut;

  String get _role => switch (me.role) {
        'admin' => L('Admin', 'Admin'),
        'manager' => L('Manager', 'Responsable'),
        _ => L('Member', 'Miembro'),
      };

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: t.card,
        border: Border(right: BorderSide(color: t.line)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              org,
              style: TextStyle(
                fontFamily: 'Sora',
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: -0.1,
                color: t.ink,
              ),
            ),
            const SizedBox(height: 26),
            ValueListenableBuilder<ConsoleRoute>(
              valueListenable: nav,
              builder: (context, route, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (id, label) in sections)
                    _NavItem(
                      label: label,
                      active: route.section == id,
                      onTap: () => nav.go(id),
                    ),
                ],
              ),
            ),
            const Spacer(),
            const _Hairline(),
            const SizedBox(height: 14),
            Text(me.name, style: AdminTokens.muted),
            const SizedBox(height: 8),
            TestuPill(_role, color: t.mut, borderColor: t.line2),
            const SizedBox(height: 10),
            TextButton(
              onPressed: onSignOut,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                alignment: Alignment.centerLeft,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: AdminTokens.redText,
                textStyle: const TextStyle(
                    fontFamily: 'Geist', fontSize: 12, height: 1.2),
              ),
              child: Text(L('Sign out', 'Cerrar sesión')),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return _Interactive(
      onTap: onTap,
      radius: 4,
      builder: (context, hovered) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: AdminTokens.dur(context, 200),
              curve: TestuTokens.curve,
              height: 2,
              width: 22,
              color: active ? AdminTokens.focus : Colors.transparent,
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 12.5,
                color: active ? t.ink : (hovered ? t.ink : t.mut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Period, topic and team — the one row that decides what every analytics
/// screen is showing. Writes go through [AnalyticsFilters.set], so a change
/// rebuilds each listening screen exactly once.
class ContextBar extends StatelessWidget {
  const ContextBar({
    super.key,
    required this.filters,
    required this.topics,
    required this.teams,
    this.lockTeam,
    this.actions = const [],
  });

  final AnalyticsFilters filters;

  /// Topic id → display name.
  final Map<String, String> topics;
  final List<AdminTeam> teams;

  /// A manager sees their own team only: the select shows it and is inert.
  final String? lockTeam;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: filters,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Segmented<Period>(
                value: filters.period,
                items: [
                  (Period.d7, L('7 d', '7 d')),
                  (Period.d30, L('30 d', '30 d')),
                  (Period.d90, L('90 d', '90 d')),
                  // Before launch day "Piloto" would be a one-day window
                  // pretending to be a period: offer it once it exists.
                  if (!kPilotStart.isAfter(DateTime.now()))
                    (Period.pilot, L('Pilot', 'Piloto')),
                ],
                onChanged: (p) => filters.set(period: p),
              ),
              Select<String>(
                value: filters.topic,
                hint: L('All topics', 'Todos los temas'),
                items: [
                  (null, L('All topics', 'Todos los temas')),
                  for (final e in topics.entries) (e.key, e.value),
                ],
                onChanged: (v) =>
                    filters.set(topic: v, clearTopic: v == null),
              ),
              Select<String>(
                value: lockTeam ?? filters.team,
                enabled: lockTeam == null,
                hint: L('All teams', 'Todos los equipos'),
                items: [
                  (null, L('All teams', 'Todos los equipos')),
                  for (final team in teams) (team.id, team.name),
                ],
                onChanged: (v) => filters.set(team: v, clearTeam: v == null),
              ),
              ...actions,
            ],
          ),
          const SizedBox(height: 14),
          const _Hairline(),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- components

/// The interpretation header every analytics screen opens with: the tutor
/// says what the numbers mean before the numbers appear.
class Reading extends StatelessWidget {
  const Reading({
    super.key,
    required this.personaName,
    this.avatarUrl,
    required this.sentences,
  });

  final String personaName;
  final String? avatarUrl;
  final List<String> sentences;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: t.card2,
            shape: BoxShape.circle,
            border: Border.all(color: t.line),
            image: avatarUrl == null
                ? null
                : DecorationImage(
                    image: NetworkImage(avatarUrl!), fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ConstrainedBox(
            // ~70ch of Sora 15 — reading copy, not a data row.
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TestuEyebrow(
                  personaName.toUpperCase(),
                  letterSpacing: AdminTokens.eyebrowTracking,
                ),
                const SizedBox(height: 9),
                for (final s in sentences)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(s, style: AdminTokens.reading),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One headline number. Four of these sit hairline-separated in a
/// [StatRow] — deliberately not four cards.
class StatBlock extends StatelessWidget {
  const StatBlock({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.deltaPositive,
    this.spark,
    this.highlight = false,
  });

  final String label;
  final String value;

  /// Already-worded comparison, e.g. "+3 que la semana pasada".
  final String? delta;
  final bool? deltaPositive;

  /// 7 points, one per day.
  final List<num>? spark;

  /// The stat this screen is about, painted in `focus`.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AdminTokens.eyebrow),
          const SizedBox(height: 9),
          Text(
            value,
            style: AdminTokens.mono(22,
                color: highlight ? AdminTokens.focus : t.ink),
          ),
          if (delta != null) ...[
            const SizedBox(height: 5),
            Text(
              delta!,
              style: kLabel.copyWith(
                color: switch (deltaPositive) {
                  true => t.greenText,
                  false => AdminTokens.redText,
                  null => t.mut,
                },
              ),
            ),
          ],
          if (spark != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 28,
              width: double.infinity,
              child: LineChart(
                sparklineData(spark!),
                duration: Duration.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The four headline stats, separated by hairlines rather than boxed.
class StatRow extends StatelessWidget {
  const StatRow(this.blocks, {super.key});

  final List<StatBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Hairline(),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < blocks.length; i++) ...[
                if (i > 0) const _Hairline(vertical: true),
                Expanded(child: blocks[i]),
              ],
            ],
          ),
        ),
        const _Hairline(),
      ],
    );
  }
}

/// A chart with its label, legend and footnote. The only card the console
/// uses, and nothing is ever nested inside another one.
class ChartCard extends StatelessWidget {
  const ChartCard({
    super.key,
    required this.eyebrow,
    this.legend = const [],
    required this.child,
    this.footnote,
    this.height = 220,
    this.trailing,
  });

  final String eyebrow;

  /// `(colour, label)` per series.
  final List<(Color, String)> legend;
  final Widget child;
  final String? footnote;

  /// Fixed chart area. Null lets the child size itself -- what a card full of
  /// rows or a table needs, where the content decides the height and a fixed
  /// one would clip the moment a Spanish label wraps.
  final double? height;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return TestuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(eyebrow.toUpperCase(), style: AdminTokens.eyebrow),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    for (final (color, label) in legend)
                      _LegendDot(color: color, label: label),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 14),
          if (height == null) child else SizedBox(height: height, child: child),
          if (footnote != null) ...[
            const SizedBox(height: 10),
            Text(footnote!, style: AdminTokens.footnote),
          ],
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: kLabel),
        ],
      );
}

/// Inline stacked mastery bar for a table row or a topic line. The counts are
/// also exposed to the semantics tree, so the bar is never colour-only.
class LevelBar extends StatelessWidget {
  const LevelBar(this.levels, {super.key, this.height = 6});

  final Map<String, int> levels;
  final double height;

  static const _order = ['beginner', 'competent', 'expert', 'none'];

  @override
  Widget build(BuildContext context) {
    final present = [
      for (final k in _order)
        if ((levels[k] ?? 0) > 0) k,
    ];
    return Semantics(
      label: [
        for (final k in present) '${_levelLabel(k)} ${levels[k]}',
      ].join(', '),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: present.isEmpty
              ? const ColoredBox(color: AdminTokens.levelNone)
              : Row(
                  children: [
                    for (final k in present)
                      Expanded(
                        key: ValueKey('level.$k'),
                        flex: levels[k]!,
                        child: ColoredBox(color: AdminTokens.level(k)),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

String _levelLabel(String? level) => switch (level) {
      'expert' => L('Expert', 'Experto'),
      'competent' => L('Competent', 'Competente'),
      'beginner' => L('Beginner', 'Principiante'),
      _ => L('No data', 'Sin datos'),
    };

/// The key for a coloured series, shown once per card rather than per row.
class Legend extends StatelessWidget {
  const Legend(this.items, {super.key});

  /// `(colour, label)` -- the label carries the count when there is one, so a
  /// stacked bar is never read by colour alone.
  final List<(Color, String)> items;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 14,
        runSpacing: 4,
        children: [
          for (final (color, label) in items)
            _LegendDot(color: color, label: label),
        ],
      );
}

/// The key for [LevelBar], shown once per table rather than per row.
class LevelLegend extends StatelessWidget {
  const LevelLegend({super.key});

  @override
  Widget build(BuildContext context) => Legend([
        for (final k in LevelBar._order) (AdminTokens.level(k), _levelLabel(k)),
      ]);
}

/// [LevelBar] for data that has no levels: one segment per series, flexed by
/// its count, coloured by the caller. The colours are passed in rather than
/// looked up precisely so non-level data can never borrow the level trio's
/// meaning. Pair it with a [Legend] -- the counts live there.
class StackedBar extends StatelessWidget {
  const StackedBar(this.segments, {super.key, this.height = 10});

  /// `(colour, label, count)`; zero-count segments are dropped.
  final List<(Color color, String label, int count)> segments;
  final double height;

  @override
  Widget build(BuildContext context) {
    final present = [
      for (final s in segments)
        if (s.$3 > 0) s,
    ];
    return Semantics(
      label: [
        for (final (_, label, count) in present) '$label $count',
      ].join(', '),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: SizedBox(
          height: height,
          child: present.isEmpty
              ? const ColoredBox(color: AdminTokens.levelNone)
              : Row(
                  children: [
                    for (final (color, _, count) in present)
                      Expanded(flex: count, child: ColoredBox(color: color)),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One horizontal bar: a label, a `focus` bar proportional to [max], and the
/// count in mono at the end. The length is a comparison, never the reading --
/// the number is always there as text, and [tooltip] carries what does not
/// fit on the row.
class BarRow extends StatelessWidget {
  const BarRow({
    super.key,
    required this.label,
    required this.value,
    required this.max,
    this.tooltip,
    this.labelWidth = 150,
  });

  final String label;
  final int value;

  /// The widest bar on the card -- every row is drawn against the same one.
  final int max;
  final String? tooltip;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label,
                style: AdminTokens.table,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 8,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: max <= 0 ? 0 : (value / max).clamp(0.0, 1.0),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AdminTokens.focus,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48,
            child: Text('$value',
                style: AdminTokens.mono(11), textAlign: TextAlign.right),
          ),
        ],
      ),
    );
    final message = tooltip;
    if (message == null) return row;
    return Tooltip(
      message: message,
      waitDuration: Duration.zero,
      textStyle: AdminTokens.mono(11),
      decoration: BoxDecoration(
        color: t.card2,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(6),
      ),
      child: row,
    );
  }
}

/// The app's calibration quadrant, ported: right/wrong × certain/unsure,
/// with the misconception cell (incorrect while certain) called out.
class Quad extends StatelessWidget {
  const Quad({
    super.key,
    required this.cc,
    required this.cu,
    required this.ic,
    required this.iu,
  });

  /// correct·certain, correct·unsure, incorrect·unsure, incorrect·certain.
  final int cc, cu, ic, iu;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _QuadCell(
                    '$cc',
                    L('Consolidated\ncorrect · certain',
                        'Consolidado\ncorrecto · con certeza'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuadCell(
                    '$cu',
                    L('Fragile\ncorrect · unsure',
                        'Frágil\ncorrecto · con dudas'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _QuadCell(
                    '$ic',
                    L('Known gaps\nincorrect · unsure',
                        'Lagunas conocidas\nincorrecto · con dudas'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuadCell(
                    '$iu',
                    L('Misconception\nincorrect · certain',
                        'Concepto erróneo\nincorrecto · con certeza'),
                    hot: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _QuadCell extends StatelessWidget {
  const _QuadCell(this.count, this.label, {this.hot = false});

  final String count;
  final String label;
  final bool hot;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        // The app's own misconception border, ported verbatim with the rest
        // of the quadrant.
        border: Border.all(color: hot ? const Color(0xFF6E3535) : t.line),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count,
            style: AdminTokens.mono(16,
                color: hot ? AdminTokens.redText : t.ink),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 10.5,
                height: 1.35,
                color: t.mut),
          ),
        ],
      ),
    );
  }
}

/// Horizontal step bars — where people fall out of a flow. Each bar carries
/// its own count and share as text.
class Funnel extends StatelessWidget {
  const Funnel(this.steps, {super.key});

  /// `(label, value)`, widest step first.
  final List<(String, int)> steps;

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) return const SizedBox.shrink();
    final top = steps.first.$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value) in steps)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 180,
                  child: Text(
                    label,
                    style: AdminTokens.body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 10,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: top == 0 ? 0 : value / top,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AdminTokens.focus,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 92,
                  child: Text(
                    top == 0
                        ? '$value'
                        : '$value · ${(100 * value / top).round()}%',
                    style: AdminTokens.mono(11),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One column of an [AdminTable].
class AdminColumn<T> {
  AdminColumn(
    this.label,
    this.cell, {
    this.sortKey,
    this.width,
    this.flex = 1,
    this.numeric = false,
  });

  final String label;
  final Widget Function(T row) cell;

  /// Null makes the column unsortable.
  final Comparable Function(T row)? sortKey;

  /// Fixed width; null means share the remaining space by [flex].
  final double? width;
  final int flex;

  /// Right-aligned, mono, and sorted biggest-first on the first tap.
  final bool numeric;
}

/// Hairline rows, sortable header, hover, whole-row activation by mouse or
/// keyboard. Replaces `DataTable`, which brings Material's own type scale,
/// dividers and density into a surface that has its own.
class AdminTable<T> extends StatefulWidget {
  const AdminTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onTap,
    this.emptyText,
    this.initialSort,
  });

  final List<AdminColumn<T>> columns;
  final List<T> rows;
  final void Function(T row)? onTap;

  /// One muted row inside the table instead of an empty box.
  final String? emptyText;

  /// Column index to sort by on first build.
  final int? initialSort;

  @override
  State<AdminTable<T>> createState() => _AdminTableState<T>();
}

class _AdminTableState<T> extends State<AdminTable<T>> {
  int? _sort;
  bool _asc = true;

  @override
  void initState() {
    super.initState();
    _apply(widget.initialSort, toggle: false);
  }

  void _apply(int? i, {required bool toggle}) {
    if (i == null || i < 0 || i >= widget.columns.length) return;
    final c = widget.columns[i];
    if (c.sortKey == null) return;
    if (toggle && _sort == i) {
      _asc = !_asc;
    } else {
      _sort = i;
      // Numbers read biggest-first; names read A→Z.
      _asc = !c.numeric;
    }
  }

  List<T> get _sorted {
    final i = _sort;
    if (i == null) return widget.rows;
    final key = widget.columns[i].sortKey!;
    final out = [...widget.rows]
      ..sort((a, b) => key(a).compareTo(key(b)));
    return _asc ? out : out.reversed.toList();
  }

  Widget _cells(List<Widget> children) => Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            widget.columns[i].width != null
                ? SizedBox(width: widget.columns[i].width, child: children[i])
                : Expanded(flex: widget.columns[i].flex, child: children[i]),
        ],
      );

  Widget _align(int i, Widget child) => Align(
        alignment: widget.columns[i].numeric
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final rows = _sorted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 32,
          child: _cells([
            for (var i = 0; i < widget.columns.length; i++)
              _HeaderCell(
                column: widget.columns[i],
                sorted: _sort == i,
                ascending: _asc,
                onTap: widget.columns[i].sortKey == null
                    ? null
                    : () => setState(() => _apply(i, toggle: true)),
              ),
          ]),
        ),
        const _Hairline(),
        if (rows.isEmpty)
          SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.emptyText ?? L('No data yet.', 'Todavía no hay datos.'),
                style: AdminTokens.muted,
              ),
            ),
          )
        else
          for (final row in rows)
            _Interactive(
              onTap: widget.onTap == null
                  ? null
                  : () => widget.onTap!(row),
              radius: 0,
              builder: (context, hovered) => Container(
                height: 40,
                decoration: BoxDecoration(
                  color: hovered ? AdminTokens.hover : null,
                  border: Border(bottom: BorderSide(color: t.line)),
                ),
                child: DefaultTextStyle(
                  style: AdminTokens.table,
                  child: _cells([
                    for (var i = 0; i < widget.columns.length; i++)
                      _align(i, widget.columns[i].cell(row)),
                  ]),
                ),
              ),
            ),
      ],
    );
  }
}

class _HeaderCell<T> extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.sorted,
    required this.ascending,
    required this.onTap,
  });

  final AdminColumn<T> column;
  final bool sorted;
  final bool ascending;
  final VoidCallback? onTap;

  Widget _label(BuildContext context, bool hovered) => Align(
        alignment:
            column.numeric ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Flexible, so a narrow column ellipsises its header instead of
            // painting the overflow stripes over the row beneath it.
            Flexible(
              child: Text(
                column.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: hovered || sorted
                    ? AdminTokens.tableHead
                        .copyWith(color: TestuTokens.of(context).ink)
                    : AdminTokens.tableHead,
              ),
            ),
            if (sorted) ...[
              const SizedBox(width: 5),
              Text(
                ascending ? '▲' : '▾',
                style: AdminTokens.mono(8, color: AdminTokens.focus),
              ),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return _label(context, false);
    return _Interactive(onTap: onTap, radius: 4, builder: _label);
  }
}

/// Quiet bordered select on a `MenuAnchor`. Replaces `DropdownButton`, whose
/// Material menu, ripple and underline belong to another design system.
class Select<T> extends StatelessWidget {
  const Select({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.enabled = true,
  });

  final T? value;

  /// `(value, label)`; a null value is the "all" row.
  final List<(T?, String)> items;
  final ValueChanged<T?> onChanged;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    var label = hint ?? '—';
    for (final (v, text) in items) {
      if (v == value) {
        label = text;
        break;
      }
    }
    return MenuAnchor(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(t.card2),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shadowColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(0),
        padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            side: BorderSide(color: t.line),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      menuChildren: [
        for (final (v, text) in items)
          MenuItemButton(
            onPressed: () => onChanged(v),
            style: MenuItemButton.styleFrom(
              foregroundColor: v == value ? t.ink : t.mut,
              textStyle: const TextStyle(fontFamily: 'Geist', fontSize: 11.5),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 32),
            ),
            child: Text(text),
          ),
      ],
      builder: (context, controller, _) => _Interactive(
        onTap: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
        semanticLabel: hint,
        builder: (context, hovered) => Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          decoration: BoxDecoration(
            color: hovered ? t.card2 : null,
            border: Border.all(color: t.line2),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 11.5,
                  // A locked team is still the manager's own team name:
                  // readable, not decorative.
                  color: enabled ? t.ink : t.mut,
                ),
              ),
              const SizedBox(width: 10),
              Text('▾', style: AdminTokens.mono(8, color: t.mut)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two to four exclusive options, always all visible — the period control.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;

  /// `(value, label)`.
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: t.line2),
        borderRadius: BorderRadius.circular(7),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const _Hairline(vertical: true),
                _Interactive(
                  onTap: () => onChanged(items[i].$1),
                  radius: 0,
                  builder: (context, hovered) {
                    final on = items[i].$1 == value;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 10),
                      color: on || hovered ? t.card2 : null,
                      alignment: Alignment.center,
                      child: Text(
                        items[i].$2,
                        style: TextStyle(
                          fontFamily: 'Geist',
                          fontSize: 11.5,
                          color: on ? t.ink : t.mut,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Static `card2` blocks in the shape of the content that is coming. No
/// shimmer, no spinner — a laptop console loads in under a second and a
/// spinning ring in the content area reads as breakage.
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.lines = 4, this.height});

  final int lines;
  final double? height;

  static const _widths = [0.6, 0.85, 0.7, 0.4];

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Semantics(
      label: L('Loading', 'Cargando'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < lines; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _widths[i % _widths.length],
                child: Container(
                  height: height ?? 14,
                  decoration: BoxDecoration(
                    color: t.card2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Empty states teach the interface: what is missing, and when it appears.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.eyebrow,
    required this.text,
    this.action,
  });

  final String eyebrow;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(eyebrow.toUpperCase(), style: AdminTokens.eyebrow),
            const SizedBox(height: 9),
            Text(text, style: AdminTokens.body.copyWith(color: t.mut)),
            if (action != null) ...[
              const SizedBox(height: 14),
              Align(alignment: Alignment.centerLeft, child: action!),
            ],
          ],
        ),
      ),
    );
  }
}

/// A panel that could not load: says so, and offers exactly one way out.
class ConsolePanelError extends StatelessWidget {
  const ConsolePanelError({
    super.key,
    required this.text,
    required this.onRetry,
  });

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L('COULD NOT LOAD', 'NO SE PUDO CARGAR'),
              style: AdminTokens.eyebrow.copyWith(color: AdminTokens.redText),
            ),
            const SizedBox(height: 9),
            Text(text, style: AdminTokens.body.copyWith(color: t.mut)),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TestuAct(L('Retry', 'Reintentar'), onTap: onRetry),
            ),
          ],
        ),
      ),
    );
  }
}
