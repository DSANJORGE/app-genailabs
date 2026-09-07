import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_icons.dart';
import 'testu_theme.dart';

/// A bundled asset key, or an absolute URL from the server (its generated
/// images are served without auth).
ImageProvider testuImage(String src) =>
    src.startsWith('http') ? NetworkImage(src) : AssetImage(src);

/// True past the Dynamic Type size where a label and a pill stop fitting on
/// one line — iOS XXL and up. Below it the approved v6 layout is untouched;
/// above it, rows built for a phone-width line stack instead of overflowing
/// or breaking a word in half.
bool testuBigText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(100) > 120;

/// Press feedback per spec: opacity .75 + scale .985 + selectionClick haptic.
class TestuPressable extends StatefulWidget {
  const TestuPressable({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<TestuPressable> createState() => _TestuPressableState();
}

class _TestuPressableState extends State<TestuPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? 0.985 : 1,
        duration: const Duration(milliseconds: 90),
        curve: TestuTokens.curve,
        child: AnimatedOpacity(
          opacity: _down ? 0.75 : 1,
          duration: const Duration(milliseconds: 90),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Full-width button. `primary` = THE white CTA (one per screen), `quiet` =
/// 1px line2 outline, `onimg` = quiet variant readable on photography.
enum TestuButtonVariant { primary, quiet, onimg }

class TestuButton extends StatelessWidget {
  const TestuButton(
    this.label, {
    super.key,
    this.variant = TestuButtonVariant.quiet,
    this.onTap,
    this.color,
    this.borderColor,
  });

  final String label;
  final TestuButtonVariant variant;
  final VoidCallback? onTap;

  /// Overrides for off-palette states (e.g. the red sign-out).
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    var (Color fg, Color? bg, Color? borderColor) = switch (variant) {
      TestuButtonVariant.primary => (t.onPrimaryAction, t.primaryAction, null),
      TestuButtonVariant.quiet => (t.ink, null, t.line2),
      TestuButtonVariant.onimg => (
          t.primaryAction,
          const Color(0x6E0A0A0B),
          t.onImgLine,
        ),
    };
    // Hard rule (app-wide): a button whose action isn't available yet never
    // wears its active colors — no white CTA until requirements are met.
    // Grammar: line2 fill, faint label.
    if (onTap == null) {
      fg = t.faint;
      bg = variant == TestuButtonVariant.primary ? t.line2 : null;
      borderColor = variant == TestuButtonVariant.primary ? null : t.line2;
    }
    fg = color ?? fg;
    borderColor = this.borderColor ?? borderColor;
    Widget box = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      decoration: BoxDecoration(
        color: bg,
        border: borderColor == null ? null : Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Geist',
          fontWeight: FontWeight.w700,
          fontSize: 13,
          letterSpacing: 0.65, // +0.05em
          color: fg,
        ),
      ),
    );
    if (variant == TestuButtonVariant.onimg) {
      box = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: box,
        ),
      );
    }
    return TestuPressable(onTap: onTap, child: box);
  }
}

/// Small in-card action (`.act`): 12px/700, line2 outline, 7px radius.
/// `primary` makes it the screen's white CTA.
class TestuAct extends StatelessWidget {
  const TestuAct(
    this.label, {
    super.key,
    this.primary = false,
    this.onTap,
    this.borderColor,
    this.color,
  });

  final String label;
  final bool primary;
  final VoidCallback? onTap;

  /// Overrides for the "done" state (green ✓ ghost after the CTA handoff).
  final Color? borderColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    // Same disabled rule as TestuButton: unmet action = no active colors.
    final disabled = onTap == null && color == null && borderColor == null;
    return TestuPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 16),
        decoration: BoxDecoration(
          color: primary ? (disabled ? t.line2 : t.primaryAction) : null,
          border: Border.all(
              color: borderColor ??
                  (primary && !disabled ? t.primaryAction : t.line2)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Geist',
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.6, // +0.05em
            color: color ??
                (disabled
                    ? t.faint
                    : primary ? t.onPrimaryAction : t.ink),
          ),
        ),
      ),
    );
  }
}

/// Outlined status pill — never filled. One tone per meaning (spec): gold =
/// Review soon, green = Stable/Strong/Connected, amber = At risk/Building/
/// Required, red = Beginner/severe, gray = Not started/Optional. The raw
/// constructor exists for the live mastery record, which carries its tone.
class TestuPill extends StatelessWidget {
  const TestuPill(
    this.label, {
    super.key,
    required this.color,
    required this.borderColor,
  });

  TestuPill.gold(this.label, {super.key})
      : color = TestuTokens.instance.gold,
        borderColor = TestuTokens.instance.goldBorder;
  TestuPill.green(this.label, {super.key})
      : color = TestuTokens.instance.greenText,
        borderColor = TestuTokens.instance.greenBorder;
  TestuPill.amber(this.label, {super.key})
      : color = TestuTokens.instance.amber,
        borderColor = TestuTokens.instance.amberBorder;
  TestuPill.red(this.label, {super.key})
      : color = TestuTokens.instance.redText,
        borderColor = TestuTokens.instance.redBorder;
  TestuPill.gray(this.label, {super.key})
      : color = TestuTokens.instance.mut,
        borderColor = TestuTokens.instance.line2;

  final String label;
  final Color color;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Geist',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3, // +0.03em
          color: color,
        ),
      ),
    );
  }
}

/// Mono uppercase eyebrow — pass text already uppercased.
class TestuEyebrow extends StatelessWidget {
  const TestuEyebrow(
    this.text, {
    super.key,
    this.color,
    this.fontSize = 9.5,
    this.letterSpacing = 1.71, // +0.18em
  });

  /// Card section label (`.dcard h4`) — same widget, one step down.
  TestuEyebrow.h4(this.text, {super.key})
      : color = TestuTokens.instance.faint,
        fontSize = 9,
        letterSpacing = 1.26; // +0.14em

  /// Name kicker over a tutor bubble, fact labels, question kickers.
  TestuEyebrow.kicker(this.text, {super.key, Color? color})
      : color = color ?? TestuTokens.instance.faint,
        fontSize = 9,
        letterSpacing = 1.44; // +0.16em

  /// Smallest label: inner-group headers (SKILLS), stat labels, tags.
  TestuEyebrow.tag(this.text, {super.key, Color? color})
      : color = color ?? TestuTokens.instance.faint,
        fontSize = 8.5,
        letterSpacing = 1.02; // +0.12em

  final String text;
  final Color? color;
  final double fontSize;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'GeistMono',
        fontWeight: FontWeight.w500,
        fontSize: fontSize,
        letterSpacing: letterSpacing,
        color: color ?? t.mut,
      ),
    );
  }
}

/// 2px hairline progress: dark track + orange fill.
class TestuHairline extends StatelessWidget {
  const TestuHairline(this.fraction, {super.key, this.trackColor});

  final double fraction;
  final Color? trackColor;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 2,
        color: trackColor ?? t.track,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
          // heightFactor: the fill has no child, so without a tight height
          // it collapses to 0px and the track shows empty.
          heightFactor: 1,
          child: ColoredBox(color: t.orange),
        ),
      ),
    );
  }
}

/// Card: card fill, 1px line border, 14px radius, flat. Optional 2px left
/// accent (amber/red — at most once each per screen, per spec).
class TestuCard extends StatelessWidget {
  const TestuCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = const EdgeInsets.fromLTRB(16, 15, 16, 16),
  });

  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(14),
      ),
      // Non-uniform Border can't take a radius, so the accent is a clipped strip.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Stack(
          children: [
            if (accent != null)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: accent),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// House composer pill — THE text-entry module, used identically everywhere
/// something is sent (session chat, thread replies, tutor ask bar). Send
/// affordance lives inside the pill and only activates when there is content.
/// Future message kinds (file, voice, transcript) extend this module, not
/// its call sites.
class TestuComposer extends StatefulWidget {
  const TestuComposer({
    super.key,
    required this.hint,
    this.controller,
    this.onSend,
    this.onTap,
  });

  final String hint;

  /// Optional external controller (session owns one for its chat flow).
  final TextEditingController? controller;

  /// Called with trimmed non-empty text; the field clears itself when the
  /// controller is internal.
  final ValueChanged<String>? onSend;

  /// Facade mode: whole pill is one pressable, field is inert. Used where
  /// the composer is a door to a conversation, not the conversation itself.
  final VoidCallback? onTap;

  @override
  State<TestuComposer> createState() => _TestuComposerState();
}

class _TestuComposerState extends State<TestuComposer> {
  TextEditingController? _own;
  TextEditingController get _ctl =>
      widget.controller ?? (_own ??= TextEditingController());

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    if (widget.controller == null) _ctl.clear();
    widget.onSend?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final pill = Container(
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        color: t.field,
        border: Border.all(color: t.line2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctl,
              enabled: widget.onTap == null,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 12.5,
                color: t.ink,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: widget.hint,
                hintStyle: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12.5,
                  color: t.faint,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _ctl,
            builder: (_, v, _) {
              final active =
                  widget.onTap == null && v.text.trim().isNotEmpty;
              return TestuPressable(
                onTap: active ? _send : null,
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  // Idle = just the arrow (no filled circle — the pill is
                  // everywhere, a grey disc in every one reads noisy); the
                  // white circle appears only once there's text to send.
                  decoration: BoxDecoration(
                    color: active ? t.primaryAction : null,
                    shape: BoxShape.circle,
                  ),
                  child: TestuIcon(TestuGlyph.send,
                      size: 14,
                      color: active ? t.onPrimaryAction : t.faint),
                ),
              );
            },
          ),
        ],
      ),
    );
    if (widget.onTap == null) return pill;
    return TestuPressable(onTap: widget.onTap, child: pill);
  }
}

/// User chat bubble — right-aligned, shared by every Sully chat surface
/// (resource sheets, PDF viewer) so sent messages look identical app-wide.
class TestuYouMsg extends StatelessWidget {
  const TestuYouMsg(
      {super.key, required this.text, this.fontSize = 12.5, this.alignEnd = true});

  final String text;

  /// The app's chat size by default; the console's Iris panel passes its own
  /// so a question and its answer read at one size.
  final double fontSize;

  /// Hung on the right, as chat does; the console's panel sets it left, in
  /// line with the answers.
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 13),
          decoration: BoxDecoration(
            color: t.raised,
            border: Border.all(color: t.line2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text,
              style: TextStyle(
                  fontFamily: 'Geist',
                  fontSize: fontSize,
                  height: 1.5,
                  color: t.inkSoft)),
        ),
      ),
    );
  }
}

/// Green check + pulse ring, 76×76 — THE success feedback, shared by every
/// confirmation surface (schedule sheet, report sheets). Timing mirrors the
/// approved prototype: check draws .25–.5s, pulse ring expands .3–1.9s.
class TestuCheckPulse extends StatelessWidget {
  const TestuCheckPulse({super.key});

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return SizedBox(
      width: 76,
      height: 76,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1900),
        builder: (_, v, _) => CustomPaint(
          painter: TestuCheckPainter(
              progress: v, green: t.green, ring: t.greenBorder),
        ),
      ),
    );
  }
}

class TestuCheckPainter extends CustomPainter {
  const TestuCheckPainter(
      {required this.progress, required this.green, required this.ring});

  final double progress;
  final Color green;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = progress * 1900;
    final center = size.center(Offset.zero);

    final pulse = ((ms - 300) / 1600).clamp(0.0, 1.0);
    if (pulse > 0 && pulse < 1) {
      canvas.drawCircle(
        center,
        36 * (1 + 0.65 * pulse),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = ring.withValues(alpha: 0.9 * (1 - pulse)),
      );
    }

    canvas.drawCircle(
      center,
      36,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = ring,
    );

    final draw = Curves.easeOut.transform(((ms - 250) / 500).clamp(0.0, 1.0));
    if (draw > 0) {
      final path = Path()
        ..moveTo(24, 39)
        ..lineTo(34, 49)
        ..lineTo(53, 29);
      final metric = path.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * draw),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = green,
      );
    }
  }

  @override
  bool shouldRepaint(TestuCheckPainter old) => old.progress != progress;
}

/// Conversational chip — follow-ups under a tutor message, report reasons,
/// canned questions. Pill, Geist 11.5. `primary` = the white recommendation
/// (one per screen); `selected` = picked but not yet sent (light border +
/// raised tint, the same grammar as a chosen answer option).
class TestuChip extends StatelessWidget {
  const TestuChip(
    this.label, {
    super.key,
    this.primary = false,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final bool primary;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return TestuPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
        decoration: BoxDecoration(
          color: primary
              ? t.primaryAction
              : selected
                  ? t.raised
                  : null,
          border: Border.all(
              color: primary
                  ? t.primaryAction
                  : selected
                      ? t.selectedBorder
                      : t.line2),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Geist',
            fontSize: 11.5,
            fontWeight: primary
                ? FontWeight.w700
                : selected
                    ? FontWeight.w600
                    : FontWeight.w400,
            color: primary
                ? t.onPrimaryAction
                : selected
                    ? t.ink
                    : t.inkDim,
          ),
        ),
      ),
    );
  }
}

/// 44×44 tap target around a 15px house glyph — every ✕ / ‹ / ↻ / ☰ in a
/// header. `onImage` = the blurred scrim circle used over photography.
class TestuIconButton extends StatelessWidget {
  const TestuIconButton(
    this.glyph, {
    super.key,
    required this.onTap,
    this.size = 15,
    this.color,
    this.onImage = false,
  });

  final TestuGlyph glyph;
  final VoidCallback onTap;
  final double size;
  final Color? color;
  final bool onImage;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    Widget icon = TestuIcon(glyph, size: size, color: color ?? t.mut);
    if (onImage) {
      icon = ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.scrim,
              shape: BoxShape.circle,
              border: Border.all(color: t.onImgLine),
            ),
            child: TestuIcon(glyph, size: size, color: color ?? t.ink),
          ),
        ),
      );
    }
    return TestuPressable(
      onTap: onTap,
      child: SizedBox(width: 44, height: 44, child: Center(child: icon)),
    );
  }
}

/// Document-type badge (PDF / VID / DOC): mono label in a card2 box.
class TestuDocBadge extends StatelessWidget {
  const TestuDocBadge(this.kind, {super.key, this.size = 36});

  final String kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.card2,
        border: Border.all(color: t.line),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(kind,
          style: TextStyle(
              fontFamily: 'GeistMono',
              fontWeight: FontWeight.w500,
              fontSize: 9.5,
              letterSpacing: 0.38,
              color: t.mut)),
    );
  }
}

/// Grab handle at the top of every sheet body.
class TestuGrabber extends StatelessWidget {
  const TestuGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 16),
        decoration: BoxDecoration(
          color: t.line2,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// THE bottom-sheet chrome (spec: 22px top radius, card fill, hairline
/// edge, 66% backdrop, 88% height cap, Material's 640px landscape cap,
/// backdrop-tap closes unless [dismissible] is false). Bodies start with a
/// [TestuGrabber] and own their scrolling.
Future<T?> showTestuSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double maxHeight = 0.88,
  bool dismissible = true,
}) {
  final t = TestuTokens.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    backgroundColor: t.card,
    barrierColor: t.barrier,
    shape: RoundedRectangleBorder(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      side: BorderSide(color: t.line2),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * maxHeight,
      maxWidth: 640,
    ),
    builder: builder,
  );
}

/// One row of a picker sheet: optional mono [tag] column (PDF / VIDEO),
/// the label, optional mono [trailing] (p. 12), orange when [selected].
typedef TestuSheetRow = ({
  String? tag,
  String label,
  String? trailing,
  bool selected,
  bool indent,
  VoidCallback onTap,
});

/// THE picker sheet — sources, table of contents, language. A mono
/// eyebrow title over tappable rows; a row pops the sheet, then acts.
Future<void> showTestuListSheet(
  BuildContext context, {
  required String title,
  required List<TestuSheetRow> rows,
  double maxHeight = 0.7,
}) {
  final t = TestuTokens.of(context);
  final selected = rows.indexWhere((r) => r.selected);
  return showTestuSheet<void>(
    context,
    maxHeight: maxHeight,
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TestuGrabber(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: TestuEyebrow(title),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              // Open with the current row two lines from the top.
              controller: ScrollController(
                  initialScrollOffset:
                      (selected - 2).clamp(0, rows.length) * 44.0),
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = rows[i];
                return TestuPressable(
                  onTap: () {
                    Navigator.of(ctx).pop();
                    r.onTap();
                  },
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(r.indent ? 36 : 20, 12, 20, 12),
                    child: Row(children: [
                      if (r.tag != null)
                        SizedBox(
                          width: 44,
                          child: TestuEyebrow.kicker(r.tag!, color: t.orange),
                        ),
                      Expanded(
                        child: Text(
                          r.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Geist',
                              fontSize: 13,
                              color: r.selected ? t.orange : t.inkSoft),
                        ),
                      ),
                      if (r.trailing != null) ...[
                        const SizedBox(width: 12),
                        Text(r.trailing!,
                            style: TextStyle(
                                fontFamily: 'GeistMono',
                                fontSize: 10,
                                color: r.selected ? t.orange : t.mut)),
                      ] else if (r.selected)
                        TestuIcon(TestuGlyph.check, size: 13, color: t.orange),
                    ]),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// THE centred dialog (spec: only for moments a sheet can't carry — the
/// confidence consent, a one-field prompt). Card fill, 18px radius, hairline
/// edge, same backdrop as sheets. No Material AlertDialog anywhere.
Future<T?> showTestuDialog<T>(
  BuildContext context, {
  required Widget child,
  bool dismissible = true,
}) {
  final t = TestuTokens.of(context);
  return showDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierColor: t.barrier,
    builder: (_) => Dialog(
      backgroundColor: t.card,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: t.line2),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    ),
  );
}

/// Field chrome shared by every free-standing text input (sign-in, the
/// report note, go-to-page): [fill] one step under its surface, hairline
/// border, ink focus ring, 10px radius.
InputDecoration testuFieldDecoration(TestuTokens t,
        {String? hint, Color? fill, double fontSize = 15}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontFamily: 'Geist',
        fontSize: fontSize,
        color: t.faint,
      ),
      filled: true,
      fillColor: fill ?? t.card,
      contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.line2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.primaryAction),
      ),
    );

/// Loading placeholder for a list row: thumb box + two text bars in card2.
/// Static on purpose — product surfaces load into a task; nobody should
/// watch a shimmer. Also the reduced-motion answer.
class TestuSkeletonRow extends StatelessWidget {
  const TestuSkeletonRow({super.key, this.thumb = 58, this.pill = true});

  final double thumb;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    Widget bar(double w, [double h = 10]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: t.card2,
            borderRadius: BorderRadius.circular(h / 2),
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      child: Row(children: [
        if (thumb > 0) ...[
          Container(
            width: thumb,
            height: thumb,
            decoration: BoxDecoration(
              color: t.card2,
              borderRadius: BorderRadius.circular(thumb > 40 ? 12 : 8),
            ),
          ),
          const SizedBox(width: 13),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bar(180, 12),
              const SizedBox(height: 8),
              bar(120),
              if (pill) ...[const SizedBox(height: 8), bar(96, 18)],
            ],
          ),
        ),
      ]),
    );
  }
}
