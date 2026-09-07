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
///
/// Public because the heatmap's pinned name column is interactive too, and a
/// second copy of this over there is how the two drifted apart (that one
/// painted its focus ring on hover as well).
class ConsoleInteractive extends StatefulWidget {
  const ConsoleInteractive({
    super.key,
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
  State<ConsoleInteractive> createState() => ConsoleInteractiveState();
}

class ConsoleInteractiveState extends State<ConsoleInteractive> {
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
      // One node per interactive element: the Semantics carries the name, the
      // button flag AND the tap, and the GestureDetector is excluded so it
      // cannot contribute a second, separately tappable node underneath.
      child: Semantics(
        button: enabled,
        label: widget.semanticLabel,
        onTap: widget.onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          excludeFromSemantics: true,
          child: child,
        ),
      ),
    );
  }
}

/// Horizontal scroll with a thumb you can see and drag. Used by [AdminTable]
/// when its columns outrun the card and by the heatmap grid, which has always
/// scrolled -- silently, which is how a reader misses a column.
class HScroll extends StatefulWidget {
  const HScroll({super.key, required this.child});

  final Widget child;

  @override
  State<HScroll> createState() => _HScrollState();
}

class _HScrollState extends State<HScroll> {
  final _controller = ScrollController();

  /// Whether there is anything to scroll. The gutter the thumb sits in is
  /// reserved only then -- the heatmap grid usually fits its card, and 10 px
  /// of empty space under it is a hole nobody asked for.
  bool _scrolls = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _onMetrics(ScrollMetricsNotification n) {
    final scrolls = n.metrics.maxScrollExtent > 0;
    if (scrolls != _scrolls) {
      // The notification arrives during layout; the rebuild waits for it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _scrolls = scrolls);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    // Material's default thumb is a bright bar across a dark console; this is
    // the same hairline vocabulary as everything else here.
    return ScrollbarTheme(
      data: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(4),
        radius: const Radius.circular(2),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? t.mut : t.line2,
        ),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      child: Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: _onMetrics,
          child: Padding(
            // Room for the thumb, so it never sits on the last row's hairline.
            padding: EdgeInsets.only(bottom: _scrolls ? 10 : 0),
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              child: widget.child,
            ),
          ),
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
  const Pulse(
      {super.key, required this.active, this.stamp = 0, required this.child});

  final bool active;

  /// [ConsoleRoute.stamp]: a new value on an already-active pulse means a
  /// second citation landed on the same element, and it has to ring again.
  final int stamp;
  final Widget child;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> {
  bool _ring = false;
  Timer? _hold;

  @override
  void initState() {
    super.initState();
    if (widget.active) _arm();
  }

  @override
  void didUpdateWidget(Pulse old) {
    super.didUpdateWidget(old);
    if (widget.active && (!old.active || widget.stamp != old.stamp)) _arm();
  }

  /// Ring on instantly, then fade out over 600 ms — the fade is the pulse.
  ///
  /// With `disableAnimations` there is no fade to carry it, and dropping the
  /// ring on the next frame would make it a flicker nobody sees. Reduced
  /// motion means less movement, not less feedback, so the ring is simply
  /// held still for 1.5 s instead.
  void _arm() {
    _hold?.cancel();
    _ring = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AdminTokens.dur(context, 600) != Duration.zero) {
        setState(() => _ring = false);
        return;
      }
      _hold = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _ring = false);
      });
    });
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
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
    this.titleAction,
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

  /// Sits at the right of the title row — the Iris toggle, today the only one.
  final Widget? titleAction;
  final Widget? endPanel;
  final VoidCallback onSignOut;

  /// Panel geometry: 360 px wide, and the narrowest content column it may
  /// leave behind. Under this the panel stops pushing and floats instead --
  /// at 1024 a pushed panel leaves 396 px, which is narrower than any table
  /// in the console can be drawn.
  static const double _panelW = 360;
  static const double _navW = 220;
  static const double _minContent = 640;

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
          final float =
              box.maxWidth - _navW - _panelW < _minContent;
          final panel = endPanel == null
              ? const SizedBox.shrink()
              : Container(
                  width: _panelW,
                  decoration: BoxDecoration(
                    color: t.card,
                    // A floating panel needs an edge that reads: one step up
                    // the line vocabulary (`line2` over the usual `line`),
                    // plus the console's only shadow. The shadow alone is not
                    // enough -- black on near-black is nothing, and
                    // flutter_test drops shadows entirely, so the goldens
                    // would show a column that looks clipped.
                    border: Border(
                        left: BorderSide(color: float ? t.line2 : t.line)),
                    boxShadow: float
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.45),
                              blurRadius: 18,
                              offset: const Offset(-2, 0),
                            ),
                          ]
                        : null,
                  ),
                  child: float
                      // The inner hairline: two lines a pixel apart is what
                      // separates "in front of" from "next to" on a surface
                      // with no depth of its own.
                      ? DecoratedBox(
                          decoration: BoxDecoration(
                            border:
                                Border(left: BorderSide(color: t.line)),
                          ),
                          child: endPanel,
                        )
                      : endPanel,
                );
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
              Expanded(
                child: float
                    // Over the content, not beside it: the panel is a
                    // companion to the screen, and squeezing the screen to
                    // fit it is how a table ends up 396 px wide.
                    ? Stack(
                        children: [
                          _content(context),
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: 0,
                            child: crossfade(panel),
                          ),
                        ],
                      )
                    : _content(context),
              ),
              // Crossfade rather than a hard cut: the panel is a companion,
              // and it arrives the way every other state change here does.
              if (!float) crossfade(panel),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: AdminTokens.title,
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (titleAction != null) ...[
                      const SizedBox(width: 16),
                      titleAction!,
                    ],
                  ],
                ),
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
            TestuPill(roleLabel(me.role), color: t.mut, borderColor: t.line2),
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
    return ConsoleInteractive(
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
    this.period = true,
    this.actions = const [],
  });

  final AnalyticsFilters filters;

  /// Topic id → display name.
  final Map<String, String> topics;
  final List<AdminTeam> teams;

  /// A manager sees their own team only: the select shows it and is inert.
  final String? lockTeam;

  /// Whether this screen reads the period at all. Dominio does not -- mastery
  /// is cumulative -- and a control that changes nothing is worse than no
  /// control.
  final bool period;
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
              if (period)
                Segmented<Period>(
                  value: filters.period,
                  items: [
                    (Period.d7, Period.d7.label),
                    (Period.d30, Period.d30.label),
                    (Period.d90, Period.d90.label),
                    // Before launch day "Piloto" would be a one-day window
                    // pretending to be a period: offer it once it exists.
                    if (!kPilotStart.isAfter(DateTime.now()))
                      (Period.pilot, Period.pilot.label),
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

/// The tutor's face: a 26 px circle, `card2` when the server has no avatar
/// for the persona. The reading header, the Iris toggle and the panel header
/// all wear the same one.
class PersonaAvatar extends StatelessWidget {
  const PersonaAvatar({super.key, this.url, this.size = 26});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: t.card2,
        shape: BoxShape.circle,
        border: Border.all(color: t.line),
        image: url == null
            ? null
            : DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover),
      ),
    );
  }
}

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PersonaAvatar(url: avatarUrl),
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

/// Two lines of [AdminTokens.eyebrow] at line height 1.25.
const double _eyebrowH = 24;

/// One headline number. Four of these sit hairline-separated in a
/// [StatRow] — deliberately not four cards.
///
/// **Only inside a [StatRow].** The sparkline is pushed to the floor of the
/// block with a [Spacer], which needs a bounded height; [StatRow]'s
/// `IntrinsicHeight` is what supplies it. In a bare unbounded Column this
/// throws, and that is the contract rather than an accident.
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
          // Two lines of eyebrow, always. In Spanish "MINUTOS EN LA APP" and
          // "CONCEPTOS ERRÓNEOS" wrap at 1024 while "ACTIVOS 7 D" does not,
          // and a label that changes height drops that block's number half a
          // line below its neighbours -- five headline figures that no longer
          // sit on one line.
          SizedBox(
            height: _eyebrowH,
            child: Text(label.toUpperCase(),
                // An explicit line height, so two lines are exactly
                // [_eyebrowH] whatever the font's own metrics say -- without
                // it the second line was cut off ("MINUTOS EN LA AP").
                style: AdminTokens.eyebrow.copyWith(height: 1.25),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 7),
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
          // The sparkline sits on the floor of the block, so a delta that
          // wraps costs the line above it and not the row's rhythm.
          if (spark != null) ...[
            const Spacer(),
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
    // An empty bar still says something: "Sin datos", to both readers.
    final reading = present.isEmpty
        ? _levelLabel(null)
        : [for (final k in present) '${_levelLabel(k)} ${levels[k]}'].join(', ');
    return Semantics(
      label: reading,
      child: Tooltip(
        // The same sentence the screen reader gets: four colours in a 6 px bar
        // are not a reading for anybody, sighted or not.
        message: reading,
        waitDuration: Duration.zero,
        textStyle: AdminTokens.mono(11),
        decoration: AdminTokens.tip,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SizedBox(
            height: height,
            child: present.isEmpty
                ? const ColoredBox(color: AdminTokens.levelNone)
                : Row(
                    // stretch, not the default centre: a ColoredBox with no
                    // child takes the SMALLEST size its constraints allow, so
                    // a loose cross axis paints every segment 0 px high -- the
                    // bar lays out at its full width and shows nothing at all.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  // See [LevelBar]: a centred cross axis paints every segment
                  // 0 px high.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
      decoration: AdminTokens.tip,
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

  /// Every cell keeps a 12 px right gutter, header and body alike. Without
  /// it a fixed-width column butts straight into the next one, and a numeric
  /// (right-aligned) cell reads as one word with the left-aligned cell after
  /// it: `2026-09-02Activo`.
  ///
  /// The gutter is added OUTSIDE [AdminColumn.width], not taken out of it:
  /// a fixed width is measured against the content that has to fit there
  /// (`2026-09-02` in mono is 79 px of the 80 px column), so charging it for
  /// the gutter would wrap every date onto two lines.
  static const _gutterW = 12.0;

  /// The narrowest a flexed column may be squeezed to before the table stops
  /// shrinking and starts scrolling. Below this a name column shows one
  /// letter and a Select shows none -- the Equipos table on Resumen lost its
  /// team names entirely with the Iris panel open at 1280.
  static const _minFlexW = 96.0;

  double get _minWidth {
    var w = 0.0;
    for (final c in widget.columns) {
      w += (c.width ?? _minFlexW) + _gutterW;
    }
    return w;
  }

  Widget _cells(List<Widget> children) => Row(
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            if (widget.columns[i].width case final w?)
              SizedBox(width: w + _gutterW, child: _gutter(children[i]))
            else
              Expanded(
                  flex: widget.columns[i].flex, child: _gutter(children[i])),
        ],
      );

  Widget _gutter(Widget child) => Padding(
      padding: const EdgeInsets.only(right: _gutterW), child: child);

  Widget _align(int i, Widget child) => Align(
        alignment: widget.columns[i].numeric
            ? Alignment.centerRight
            : Alignment.centerLeft,
        child: child,
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          final table = _table(context);
          if (!box.maxWidth.isFinite || box.maxWidth >= _minWidth) {
            return table;
          }
          // Everything still readable, one gesture away -- the same answer
          // the heatmap gives when its columns outrun the card.
          return HScroll(child: SizedBox(width: _minWidth, child: table));
        },
      );

  Widget _table(BuildContext context) {
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
            ConsoleInteractive(
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
              // A narrow column ellipsises its header ("Última activi…"), and
              // the full words then exist nowhere on the screen: the tooltip
              // is where they live.
              child: Tooltip(
                message: column.label,
                waitDuration: Duration.zero,
                textStyle: AdminTokens.mono(11),
                decoration: AdminTokens.tip,
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
            ),
            if (sorted) ...[
              const SizedBox(width: 5),
              Text(
                ascending ? '▲' : '▼',
                style: AdminTokens.mono(8, color: AdminTokens.focus),
              ),
            ],
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return _label(context, false);
    return ConsoleInteractive(onTap: onTap, radius: 4, builder: _label);
  }
}

/// Horizontal padding, caret and its gap: everything in a [Select] that is
/// not the label, and therefore what the label does not get.
const double _selectChrome = 46;

/// Quiet bordered select on a `MenuAnchor`. Replaces `DropdownButton`, whose
/// Material menu, ripple and underline belong to another design system.
class Select<T> extends StatelessWidget {
  const Select({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
    this.semanticLabel,
    this.enabled = true,
  });

  final T? value;

  /// `(value, label)`; a null value is the "all" row.
  final List<(T?, String)> items;
  final ValueChanged<T?> onChanged;

  /// What the control shows when nothing is picked -- a placeholder, not a
  /// name. In a table cell it says "Ninguno", which is no use to a screen
  /// reader, hence [semanticLabel].
  final String? hint;

  /// What this control IS ("Change team"), for assistive technology. Falls
  /// back to [hint] where the placeholder does name the control, which is
  /// what the context bar's "All topics" / "All teams" selects do.
  final String? semanticLabel;
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
      builder: (context, controller, _) => ConsoleInteractive(
        onTap: enabled
            ? () => controller.isOpen ? controller.close() : controller.open()
            : null,
        semanticLabel: semanticLabel ?? hint,
        builder: (context, hovered) => LayoutBuilder(
          builder: (context, box) {
            final style = TextStyle(
              fontFamily: 'Geist',
              fontSize: 11.5,
              // A locked team is still the manager's own team name: readable,
              // not decorative.
              color: enabled ? t.ink : t.mut,
            );
            final text = Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            );
            // "Operacione…" with the rest of the name nowhere on screen is
            // what a fixed table cell does to a Spanish team name. Measure it
            // the way the framework will paint it -- resolved style, the
            // reader's own text scale -- and hand the whole label to a tooltip
            // when it does not fit.
            final painter = TextPainter(
              text: TextSpan(
                  text: label,
                  style: DefaultTextStyle.of(context).style.merge(style)),
              textDirection: TextDirection.ltr,
              textScaler: MediaQuery.textScalerOf(context),
            )..layout();
            final clipped = box.maxWidth.isFinite &&
                painter.width > box.maxWidth - _selectChrome;
            painter.dispose();
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              decoration: BoxDecoration(
                color: hovered ? t.card2 : null,
                border: Border.all(color: t.line2),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // In a table cell the width is fixed and a Spanish team
                  // name is longer than it: the label gives way rather than
                  // painting overflow stripes over the row. In the context
                  // bar the select sits in a Wrap with no width to give way
                  // to, and a flexible child there is a layout error.
                  if (!box.maxWidth.isFinite)
                    text
                  else if (clipped)
                    Flexible(
                      child: Tooltip(
                        message: label,
                        waitDuration: Duration.zero,
                        textStyle: AdminTokens.mono(11),
                        decoration: AdminTokens.tip,
                        child: text,
                      ),
                    )
                  else
                    Flexible(child: text),
                  const SizedBox(width: 10),
                  Text('▼', style: AdminTokens.mono(8, color: t.mut)),
                ],
              ),
            );
          },
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
                ConsoleInteractive(
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

  /// Null when retrying cannot help — a scope rule is not a hiccup, and a
  /// button that always fails is worse than no button.
  final VoidCallback? onRetry;

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
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: TestuAct(L('Retry', 'Reintentar'), onTap: onRetry!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One numbered source under an Iris answer: the number the answer carries in
/// `focus`, then the fact's label. Tapping it opens the view the fact came
/// from, which is the whole promise of the panel — no figure without a way
/// back to where it was measured.
class CitationChip extends StatelessWidget {
  const CitationChip({
    super.key,
    required this.index,
    required this.citation,
    required this.onTap,
  });

  /// 1-based, matching the `[n]` marker in the answer.
  final int index;
  final Citation citation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return ConsoleInteractive(
      onTap: onTap,
      radius: 999,
      semanticLabel: '$index · ${citation.label}',
      // The chip's own text is the label word for word; leaving it in the
      // tree would announce the citation twice.
      builder: (context, hovered) => ExcludeSemantics(
        child: AnimatedContainer(
        duration: AdminTokens.dur(context, 200),
        curve: TestuTokens.curve,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 9),
        decoration: BoxDecoration(
          border:
              Border.all(color: hovered ? AdminTokens.focus : t.line2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: '$index',
              style: TextStyle(
                  color: AdminTokens.focus, fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' · ${citation.label}'),
          ]),
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 10.5,
            color: hovered ? t.ink : t.mut,
          ),
        ),
        ),
      ),
    );
  }
}

/// A quiet tappable chip — Iris's suggestion openers and follow-up
/// questions. `TestuPill`'s grammar, made interactive the console's way, so
/// it answers to Enter and shows the same focus ring as everything else here.
class ConsoleChip extends StatelessWidget {
  const ConsoleChip(this.label, {super.key, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return ConsoleInteractive(
      onTap: onTap,
      radius: 999,
      // The question itself is the name. Stated here rather than left to the
      // child Text, which is excluded so the chip is one node, not two.
      semanticLabel: label,
      builder: (context, hovered) => ExcludeSemantics(
        child: AnimatedContainer(
          duration: AdminTokens.dur(context, 200),
          curve: TestuTokens.curve,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 11),
          decoration: BoxDecoration(
            border: Border.all(color: hovered ? t.mut : t.line2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Geist',
              fontSize: 11,
              color: hovered ? t.ink : t.mut,
            ),
          ),
        ),
      ),
    );
  }
}

/// A bare glyph button — the Iris panel's ✕ today. `ConsoleInteractive` gives it the
/// console's hover, Enter/Space and focus ring; the 40 px box is the tap
/// target, deliberately much larger than the glyph inside it.
class ConsoleIconButton extends StatelessWidget {
  const ConsoleIconButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final String glyph;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    // The label goes through ConsoleInteractive, which is also what carries the tap
    // action: an outer Semantics would announce a button with nothing to
    // activate. Same wiring as CitationChip.
    return ConsoleInteractive(
      onTap: onTap,
      radius: 8,
      semanticLabel: label,
      // The glyph is decoration -- "Close" is the name, "✕" is not.
      builder: (context, hovered) => ExcludeSemantics(
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: Text(
              glyph,
              style: TextStyle(fontSize: 13, color: hovered ? t.ink : t.mut),
            ),
          ),
        ),
      ),
    );
  }
}
