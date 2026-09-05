import 'dart:async';

import 'package:flutter/material.dart';

import 'testu_i18n.dart';
import 'testu_live.dart';
import 'testu_pdf.dart';
import 'testu_theme.dart';
import 'testu_client.dart';

/// Sully chat bubble, shared by every screen: 26px avatar, mono client.tutor.toUpperCase()
/// label, 13.5px body. Shows typing dots for [delay] ms before revealing the
/// message (0 = immediate), with optional [extra] widget and [sourceLine]
/// citation below the text.
class SullyMessage extends StatefulWidget {
  const SullyMessage({
    super.key,
    required this.spans,
    this.extra,
    this.delay = 850,
    this.onGrew,
    this.sourceLine,
    this.sourcePage = 1,
    this.bottomPadding = 0,
    this.avatar = true,
  });

  /// Plain-string convenience; no typing delay unless asked for.
  SullyMessage.text(
    String text, {
    super.key,
    this.delay = 0,
    this.sourceLine,
    this.bottomPadding = 0,
    this.avatar = true,
  })  : spans = [TextSpan(text: text)],
        sourcePage = 1,
        extra = null,
        onGrew = null;

  /// A live tutor reply: its trailing `[Title, p. N]` citation (the
  /// server's reference-excerpt format) becomes the source line, opening
  /// that document at that page. Inside a document, an uncited reply still
  /// names that document ([fallbackTitle], at [fallbackPage]): the tutor
  /// always shows its source, as in the session.
  SullyMessage.reply(String reply,
      {Key? key,
      double bottomPadding = 0,
      bool avatar = true,
      String? fallbackTitle,
      int fallbackPage = 1})
      : this._cite(_withFallback(splitCite(reply), fallbackTitle, fallbackPage),
            key: key, bottomPadding: bottomPadding, avatar: avatar);

  static ({String text, String? title, int page}) _withFallback(
          ({String text, String? title, int page}) c,
          String? title,
          int page) =>
      c.title != null || title == null
          ? c
          : (text: c.text, title: title, page: page);

  SullyMessage._cite(({String text, String? title, int page}) c,
      {super.key, this.bottomPadding = 0, this.avatar = true})
      : spans = [TextSpan(text: c.text)],
        sourceLine = c.title,
        sourcePage = c.page,
        delay = 0,
        extra = null,
        onGrew = null;

  /// Page the source link opens (live citations only).
  final int sourcePage;

  /// False = name kicker only, no face — for screens whose header already
  /// carries the tutor's avatar (the tutor tab).
  final bool avatar;

  final List<InlineSpan> spans;
  final Widget? extra;

  /// Milliseconds of typing dots before the message appears; 0 = immediate.
  final int delay;

  /// Called when the message replaces the dots (the bubble grows).
  final VoidCallback? onGrew;

  /// Citation line rendered under the text with an "Open source" link.
  final String? sourceLine;

  final double bottomPadding;

  @override
  State<SullyMessage> createState() => _SullyMessageState();
}

class _SullyMessageState extends State<SullyMessage> {
  late bool _revealed = widget.delay == 0;
  Timer? _reveal;

  @override
  void initState() {
    super.initState();
    if (!_revealed) {
      _reveal = Timer(Duration(milliseconds: widget.delay), () {
        if (mounted) {
          setState(() => _revealed = true);
          widget.onGrew?.call();
        }
      });
    }
  }

  @override
  void dispose() {
    _reveal?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.avatar) ...[
            ClipOval(
              child: Image.asset(client.tutorAvatar,
                  width: 26, height: 26, fit: BoxFit.cover),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            // Readable measure: on a landscape phone an unbounded bubble runs
            // 120+ characters per line; every Sully surface shares this cap.
            child: Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  client.tutor.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'GeistMono',
                    fontSize: 9,
                    letterSpacing: 1.44, // +0.16em
                    color: t.faint,
                  ),
                ),
                const SizedBox(height: 5),
                if (!_revealed)
                  const _TypingDots()
                else ...[
                  Text.rich(
                    TextSpan(children: widget.spans),
                    style: const TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 13.5,
                      height: 1.62,
                      color: Color(0xFFD6D4D0),
                    ),
                  ),
                  if (widget.sourceLine != null) ...[
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text:
                                '${L('Source', 'Fuente')}: ${widget.sourceLine} · '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => showTestuPdf(context,
                                page: widget.sourcePage,
                                cite: widget.sourceLine,
                                doc: liveDocs[widget.sourceLine]),
                            child: Text(
                              L('Open source', 'Abrir fuente'),
                              style: TextStyle(
                                fontFamily: 'Geist',
                                fontSize: 10.5,
                                color: t.blue,
                                decoration: TextDecoration.underline,
                                decorationColor: const Color(0xFF3D5C7D),
                              ),
                            ),
                          ),
                        ),
                      ]),
                      style: TextStyle(
                          fontFamily: 'Geist', fontSize: 10.5, color: t.faint),
                    ),
                  ],
                  if (widget.extra != null) widget.extra!,
                ],
              ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fallback lines every live chat surface (session, tutor tab) says in the
/// tutor's voice when the backend is off, slow, or unreachable.
String sullyDemoReply() => L(
    'In this demo I can only answer the suggested questions — in the live app, ask me anything about the material.',
    'En esta demo solo puedo responder las preguntas sugeridas — en la app real, pregúntame lo que quieras sobre el material.');
String sullySlowReply() => L(
    '${client.tutor} is taking longer than usual. Try again in a moment.',
    '${client.tutor} está tardando más de lo normal. Inténtalo de nuevo en un momento.');
String sullyUnavailable() => L(
    '${client.tutor} is not available right now.',
    '${client.tutor} no está disponible ahora mismo.');

/// True for what the server posts on the channel when the agent fails
/// instead of answering: the exception text (`org.openedit.OpenEditException:
/// OpenAI error: HTTP/1.1 502 Bad Gateway`) or its rendered
/// "Error on AI Agent" notice. Every chat surface shows [sullyUnavailable]
/// for these rather than the raw error.
bool isSullyError(String reply) => _sullyError.hasMatch(reply);
final _sullyError =
    RegExp(r'Error on AI Agent|OpenEditException|OpenAI error|Exception: ');

/// Typing indicator shown while a message is pending.
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Opacity(
                opacity: _blink((_c.value - i * 0.16) % 1.0),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration:
                      BoxDecoration(color: t.faint, shape: BoxShape.circle),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 0% .25 → 35% 1 → 70% .25, like the prototype's blink keyframes.
  double _blink(double p) {
    if (p < 0.35) return 0.25 + 0.75 * (p / 0.35);
    if (p < 0.70) return 1.0 - 0.75 * ((p - 0.35) / 0.35);
    return 0.25;
  }
}
