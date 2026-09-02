import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_icons.dart';
import 'testu_theme.dart';

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
      TestuButtonVariant.quiet => (const Color(0xFFD8D7D3), null, t.line2),
      TestuButtonVariant.onimg => (
          t.primaryAction,
          const Color(0x6E0A0A0B),
          const Color(0x38FFFFFF),
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
                    : primary ? t.onPrimaryAction : const Color(0xFFE9E8E4)),
          ),
        ),
      ),
    );
  }
}

/// Outlined status pill — never filled. Call sites pick the semantic colors
/// (gold #8A7A3A border, amber #7A5C1E, green #2F6A4C, gray line2).
class TestuPill extends StatelessWidget {
  const TestuPill(
    this.label, {
    super.key,
    required this.color,
    required this.borderColor,
  });

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
        color: trackColor ?? const Color(0xFF26262C),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0.0, 1.0),
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
        color: const Color(0xFF101013),
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
              style: const TextStyle(
                fontFamily: 'Geist',
                fontSize: 12.5,
                color: Color(0xFFE9E8E4),
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
  const TestuYouMsg({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 13),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1D22),
            border: Border.all(color: t.line2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text,
              style: const TextStyle(
                  fontFamily: 'Geist',
                  fontSize: 12.5,
                  color: Color(0xFFD6D4D0))),
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
          painter: TestuCheckPainter(progress: v, green: t.green),
        ),
      ),
    );
  }
}

class TestuCheckPainter extends CustomPainter {
  const TestuCheckPainter({required this.progress, required this.green});

  final double progress;
  final Color green;

  @override
  void paint(Canvas canvas, Size size) {
    final ms = progress * 1900;
    final center = size.center(Offset.zero);
    const ring = Color(0xFF2F6A4C);

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
