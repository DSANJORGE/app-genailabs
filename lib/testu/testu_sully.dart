import 'dart:async';

import 'package:flutter/material.dart';
import 'package:eme_app_package/eme_http.dart' show EmeHttpException;

import 'testu_i18n.dart';
import 'testu_live.dart';
import 'testu_md.dart';
import 'testu_pdf.dart';
import 'testu_resources.dart';
import 'testu_theme.dart';
import 'testu_client.dart';
import 'testu_widgets.dart';

/// Opens the source a citation names: a live video at its time, else the
/// PDF at its page. Viewers that already show that source pass their own
/// [SullyMessage.onOpenSource] and move instead of stacking a second sheet.
void openTestuSource(BuildContext context, Cite c) {
  final doc = liveDocs[c.title];
  // Live: a citation that matches no loaded document (docs still loading,
  // fetch failed, title mismatch) says so instead of opening the offline
  // demo's aviation manual or some other document's page N.
  // ponytail: no retry/refetch; add one when citations regularly beat
  // loadDocuments.
  if (testuLive && doc == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(L('Source not available yet.',
            'La fuente aún no está disponible.'))));
    return;
  }
  if (doc != null && doc.isVideo) {
    showTestuVideo(context, doc, at: c.at ?? Duration.zero);
  } else {
    showTestuPdf(context,
        page: c.page, cite: c.title, doc: doc, rects: c.rects);
  }
}

/// " · p. N" for a page, " · m:ss" for a time; nothing for a video cited
/// without a time (the server's page label means nothing there).
String whereOf(Ref r) => r.at != null
    ? ' · ${fmtClock(r.at!)}'
    : liveDocs[r.title]?.isVideo == true
        ? ''
        : ' · p. ${r.page}';

/// The reply cited several places: pick one. Primary source first, then
/// the others, each "PDF/VIDEO  Title · p. N | m:ss".
void showTestuSources(
    BuildContext context, Cite c, void Function(Cite) open) {
  showTestuListSheet(
    context,
    title: L('SOURCES', 'FUENTES'),
    maxHeight: 0.6,
    rows: [
      for (final r in [c.ref, ...c.others])
        (
          tag: liveDocs[r.title]?.isVideo == true ? 'VIDEO' : 'PDF',
          label: '${r.title}${whereOf(r)}',
          trailing: null,
          selected: false,
          indent: false,
          onTap: () => open(c.to(r)),
        ),
    ],
  );
}

/// The tutor's citation, everywhere the tutor speaks: orange rule, the
/// quoted passage (when there is one), then "Source · p. N · Open source".
class TestuSourceBlock extends StatelessWidget {
  const TestuSourceBlock(
      {super.key,
      this.quote,
      required this.meta,
      required this.label,
      required this.onTap});

  final String? quote;
  final String meta;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 2, 0, 2),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: t.orange, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (quote != null) ...[
            Text(
              '“$quote”',
              style: TextStyle(
                fontFamily: 'Sora',
                fontSize: 12.5,
                height: 1.62,
                color: t.inkSoft,
              ),
            ),
            const SizedBox(height: 7),
          ],
          Text.rich(
            TextSpan(children: [
              TextSpan(text: '$meta · '),
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: onTap,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Geist',
                      fontSize: 10.5,
                      color: t.blue,
                      decoration: TextDecoration.underline,
                      decorationColor: t.blue.withValues(alpha: 0.45),
                    ),
                  ),
                ),
              ),
            ]),
            style: kMeta,
          ),
        ],
      ),
    );
  }
}

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
    this.sourceAt,
    this.sourceQuote,
    this.sourceOthers = const [],
    this.sourceRects = const [],
    this.inDoc,
    this.onOpenSource,
    this.followups = const [],
    this.onFollowUp,
    this.muted = false,
    this.unsourced = false,
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
        sourceAt = null,
        sourceQuote = null,
        sourceOthers = const [],
        sourceRects = const [],
        inDoc = null,
        onOpenSource = null,
        followups = const [],
        onFollowUp = null,
        muted = false,
        unsourced = false,
        extra = null,
        onGrew = null;

  /// Typing dots while a live reply is pending. Key it so the reply that
  /// takes its slot gets a fresh State (else it inherits never-ending dots).
  const SullyMessage.typing(
      {super.key, this.bottomPadding = 12, this.avatar = true})
      : spans = const [],
        delay = 600000,
        sourceLine = null,
        sourcePage = 1,
        sourceAt = null,
        sourceQuote = null,
        sourceOthers = const [],
        sourceRects = const [],
        inDoc = null,
        onOpenSource = null,
        followups = const [],
        onFollowUp = null,
        muted = false,
        unsourced = false,
        extra = null,
        onGrew = null;

  /// A live tutor reply: its trailing `[Title, p. N]` citation (the
  /// server's reference-excerpt format) becomes the source line, opening
  /// that document at that page. Inside a document, an uncited reply still
  /// names that document ([fallbackTitle], at [fallbackPage]): the tutor
  /// always shows its source, as in the session. `>> ` offers become chips
  /// when [onFollowUp] is given; tapping one sends that text.
  SullyMessage.reply(String reply,
      {Key? key,
      double bottomPadding = 0,
      bool avatar = true,
      String? fallbackTitle,
      int fallbackPage = 1,
      String? inDoc,
      void Function(Cite)? onOpenSource,
      void Function(String)? onFollowUp})
      : this._cite(_withFallback(splitCite(reply), fallbackTitle, fallbackPage),
            key: key,
            bottomPadding: bottomPadding,
            avatar: avatar,
            inDoc: inDoc,
            onOpenSource: onOpenSource,
            onFollowUp: onFollowUp);

  static Cite _withFallback(Cite c, String? title, int page) =>
      c.title != null || title == null || c.notFound
          ? c
          : Cite(
              text: c.text,
              quote: c.quote,
              title: title,
              page: page,
              followups: c.followups,
              fromFallback: true);

  SullyMessage._cite(Cite c,
      {super.key,
      this.bottomPadding = 0,
      this.avatar = true,
      this.inDoc,
      this.onOpenSource,
      this.onFollowUp})
      : spans = mdSpans(c.text),
        sourceLine = c.title,
        sourcePage = c.page,
        sourceAt = c.at,
        sourceQuote = c.quote,
        sourceOthers = c.others,
        sourceRects = c.rects,
        followups = c.followups,
        muted = c.notFound,
        // Shown, never hidden: a live answer with no source says so, even
        // when a viewer's fallback fills in the open page as sourceLine so
        // the block still renders (c.fromFallback) — the block alone would
        // otherwise look like a real citation. The demo's canned lines and
        // the fixed failure lines have none by design.
        unsourced = testuLive &&
            (c.title == null || c.fromFallback) &&
            !c.notFound &&
            !isSullyFallback(c.text),
        delay = 0,
        extra = null,
        onGrew = null;

  /// Page the source link opens (live citations only).
  final int sourcePage;

  /// Time the source link seeks to (video citations only).
  final Duration? sourceAt;

  /// Verbatim passage the server quoted from the cited page.
  final String? sourceQuote;

  /// Further places the reply cited: the link offers them in a sheet.
  final List<Ref> sourceOthers;

  /// Page-relative boxes of the passage, painted over the PDF page.
  final List<Rect> sourceRects;

  /// Title of the document this bubble sits in (viewer sheets): a citation
  /// of it says "View source" (move there); anything else "Open source".
  final String? inDoc;

  /// Source link handler; null = open the cited document in a new sheet.
  final void Function(Cite)? onOpenSource;

  /// `>> ` offers from the reply, rendered as chips under the source block.
  final List<String> followups;

  /// Tapping a follow-up chip sends its text as the next question; null
  /// hides the chips (a surface without a composer).
  final void Function(String)? onFollowUp;

  /// The not-found sentence: dimmed prose, no source block, no label.
  final bool muted;

  /// A live reply with no citation and no admission: a small "No source"
  /// label under the text.
  final bool unsourced;

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

  Cite get _cite => Cite(
        quote: widget.sourceQuote,
        title: widget.sourceLine,
        page: widget.sourcePage,
        at: widget.sourceAt,
        others: widget.sourceOthers,
        rects: widget.sourceRects,
      );

  String get _where => whereOf(_cite.ref);

  /// One source → open it; several → the sources sheet, then open the pick.
  void _open(BuildContext context) => widget.sourceOthers.isEmpty
      ? _go(context, _cite)
      : showTestuSources(context, _cite, (c) => _go(context, c));

  void _go(BuildContext context, Cite c) => widget.onOpenSource != null
      ? widget.onOpenSource!(c)
      : openTestuSource(context, c);

  String get _label {
    final n = 1 + widget.sourceOthers.length;
    final inDoc = widget.inDoc == widget.sourceLine;
    if (n == 1) {
      return inDoc ? L('View source', 'Ver fuente') : L('Open source', 'Abrir fuente');
    }
    return inDoc
        ? L('View sources ($n)', 'Ver fuentes ($n)')
        : L('Open sources ($n)', 'Abrir fuentes ($n)');
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
                TestuEyebrow.kicker(client.tutor.toUpperCase()),
                const SizedBox(height: 5),
                if (!_revealed)
                  const _TypingDots()
                else ...[
                  Text.rich(
                    TextSpan(children: widget.spans),
                    style: widget.muted ? kChat.copyWith(color: t.mut) : kChat,
                  ),
                  if (widget.unsourced) ...[
                    const SizedBox(height: 6),
                    Text(L('No source', 'Sin fuente'), style: kMeta),
                  ],
                  if (widget.sourceLine != null) ...[
                    const SizedBox(height: 10),
                    TestuSourceBlock(
                      quote: widget.sourceQuote,
                      meta: '${widget.sourceLine}$_where',
                      label: _label,
                      onTap: () => _open(context),
                    ),
                  ],
                  // ponytail: chips stay after a tap (sending twice is
                  // harmless); a vanishing row when a learner reports it.
                  if (widget.onFollowUp != null && widget.followups.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          // The template asks for at most 2 offers; a rogue
                          // reply naming more still renders only 2 chips.
                          for (final f in widget.followups.take(2))
                            TestuChip(f, onTap: () => widget.onFollowUp!(f)),
                        ],
                      ),
                    ),
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

/// Fallback lines every live chat surface (session, tutor tab, viewers)
/// says in the tutor's voice. Three distinct failures, never one blur:
/// the request could not leave the phone ([sullyOffline]), the server or
/// the agent failed ([sullyUnavailable]), nothing came back within 90 s
/// ([sullySlowReply]).
String sullyDemoReply() => L(
    'In this demo I can only answer the suggested questions — in the live app, ask me anything about the material.',
    'En esta demo solo puedo responder las preguntas sugeridas — en la app real, pregúntame lo que quieras sobre el material.');
String sullySlowReply() => L(
    '${client.tutor} is taking longer than usual. Try again in a moment.',
    '${client.tutor} está tardando más de lo normal. Inténtalo de nuevo en un momento.');
String sullyUnavailable() => L(
    '${client.tutor} is not available right now.',
    '${client.tutor} no está disponible ahora mismo.');
String sullyOffline() => L(
    'No connection. Check your network and try again.',
    'Sin conexión. Revisa tu red e inténtalo de nuevo.');

/// The line for a failed send: a transport failure (no status code) is the
/// phone's network; an HTTP error, a missing tutor channel or anything
/// else is the server.
String sullyFailure(Object e) =>
    e is EmeHttpException && e.statusCode == null
        ? sullyOffline()
        : sullyUnavailable();

/// True for the app's own fixed lines above, which carry no source and
/// must not be labelled as if they were answers.
bool isSullyFallback(String s) =>
    s == sullyDemoReply() ||
    s == sullySlowReply() ||
    s == sullyUnavailable() ||
    s == sullyOffline();

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
