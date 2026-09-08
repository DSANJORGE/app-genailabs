import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_icons.dart';
import 'testu_live.dart';
import 'testu_sully.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';
import 'testu_client.dart';

const _pages = 11; // assets/docs/pages/p-NN.jpg — rendered FAA AC 00-34A
const _pageAspect = 1284 / 1667;
const _a4 = 1 / 1.414; // live documents: server-rendered PDF pages

/// In-app source viewer: bottom sheet of rendered PDF pages, opened scrolled
/// to the cited page. Blue "Open source" links land here. [doc] = a live
/// reference document from the server; null = the offline demo's FAA manual.
void showTestuPdf(BuildContext context,
    {int page = 1,
    String? cite,
    LiveDoc? doc,
    List<Rect> rects = const []}) {
  HapticFeedback.selectionClick();
  final sub = doc != null
      ? L('Reference document', 'Documento de referencia')
      : (cite ??
              CL('Human Rights Policy', 'Política de Derechos Humanos',
                  'Aircraft Ground Handling and Servicing',
                  'Manipulación y Servicio de Aeronaves en Tierra'))
          .replaceFirst(RegExp(r'^FAA AC 00-34A\s*·\s*'), '');
  showTestuSheet<void>(
    context,
    builder: (_) => _PdfSheet(page: page, sub: sub, doc: doc, rects: rects),
  );
}

class _PdfSheet extends StatefulWidget {
  const _PdfSheet(
      {required this.page,
      required this.sub,
      this.doc,
      this.rects = const []});

  final int page;
  final String sub;
  final LiveDoc? doc;

  /// Page-relative boxes of the cited passage on [page] (orange wash).
  final List<Rect> rects;

  String get title => doc?.title ?? 'FAA AC 00-34A';
  int get pages => doc?.pages ?? _pages;
  double get aspect => doc == null ? _pageAspect : _a4;
  String src(int page) =>
      doc?.pageUrl(page) ??
      'assets/docs/pages/p-${page.toString().padLeft(2, '0')}.jpg';

  @override
  State<_PdfSheet> createState() => _PdfSheetState();
}

class _PdfSheetState extends State<_PdfSheet> {
  final _scroll = ScrollController();
  final _chat = <Widget>[];
  final _chatScroll = ScrollController();
  StreamSubscription<String>? _sub;
  bool _waiting = false;
  Timer? _timeout;
  bool _late = false;

  // Real rendered width of the page column (set by _pageList's
  // LayoutBuilder during the first build) — the sheet is width-capped and
  // splits in landscape, so deriving this from the screen guesses wrong.
  double _pageListW = 0;

  /// Page under the middle of the viewport — the header's "p. N / M".
  late int _cur = widget.page;

  /// The passage currently washed orange: the opening citation, then the
  /// latest one the tutor made about this document.
  late ({int page, List<Rect> rects}) _hl =
      (page: widget.page, rects: widget.rects);

  /// A citation of this document: mark its passage and scroll there.
  void _mark(Cite c) {
    setState(() => _hl = (page: c.page, rects: c.rects));
    _goTo(c.page);
  }

  /// Quarter turns applied to every page (scanned sideways, landscape
  /// tables): the header's ↻ button.
  int _turns = 0;

  /// Aspect of a page as shown — swapped when turned on its side.
  double get _aspect => _turns.isOdd ? 1 / widget.aspect : widget.aspect;

  void _rotate() {
    HapticFeedback.selectionClick();
    final page = _cur;
    setState(() => _turns = (_turns + 1) % 4);
    // Row pitch changes with the aspect: keep the same page under the eye.
    if (_scroll.hasClients) _scroll.jumpTo((page - 1) * _pitch);
  }

  /// Table of contents (server `chapters` "p. N Title" lines) as a sheet;
  /// a row scrolls the viewer to its page.
  void _showToc() {
    final toc = widget.doc!.toc;
    HapticFeedback.selectionClick();
    // The entry the current page falls in.
    var here = -1;
    for (final (i, e) in toc.indexed) {
      if (e.page <= _cur) here = i;
    }
    showTestuListSheet(
      context,
      title: L('CONTENTS', 'ÍNDICE'),
      rows: [
        for (final (i, e) in toc.indexed)
          (
            tag: null,
            label: e.name,
            trailing: 'p. ${e.page}',
            selected: i == here,
            // ponytail: un-numbered lines are sub-entries → indented.
            indent: !RegExp(r'^(\d|Capítulo|Chapter)').hasMatch(e.name),
            onTap: () => _goTo(e.page),
          ),
      ],
    );
  }

  /// Row pitch: page height + the 10px gap below it.
  double get _pitch => (_pageListW - 24) / _aspect + 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.jumpTo(_offsetOf(widget.page));
    });
    _scroll.addListener(() {
      final mid = _scroll.offset + _scroll.position.viewportDimension / 2;
      final p = (mid / _pitch).floor().clamp(0, widget.pages - 1) + 1;
      if (p != _cur) setState(() => _cur = p);
    });
  }

  double _offsetOf(int page) =>
      ((page - 1) * _pitch).clamp(0, _scroll.position.maxScrollExtent);

  /// Scrolls to [page]: the header tap, and the tutor's citations.
  void _goTo(int page) {
    if (!_scroll.hasClients) return;
    HapticFeedback.selectionClick();
    _scroll.animateTo(_offsetOf(page.clamp(1, widget.pages)),
        duration: const Duration(milliseconds: 350), curve: TestuTokens.curve);
  }

  // Owned by the sheet: disposing it as the dialog pops (still animating
  // out) trips the framework's `_dependents.isEmpty` assertion.
  final _pageField = TextEditingController();

  Future<void> _askPage() async {
    final field = _pageField..clear();
    final t = TestuTokens.of(context);
    final s = await showTestuDialog<String>(
      context,
      child: Builder(
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TestuEyebrow(widget.title.toUpperCase()),
            const SizedBox(height: 6),
            Text(L('Go to page', 'Ir a la página'), style: kSheetTitle),
            const SizedBox(height: 14),
            TextField(
              controller: field,
              autofocus: true,
              keyboardType: TextInputType.number,
              style: TextStyle(
                  fontFamily: 'GeistMono', fontSize: 15, color: t.ink),
              decoration: testuFieldDecoration(t,
                  hint: '1 – ${widget.pages}', fill: t.field),
              onSubmitted: (v) => Navigator.of(ctx).pop(v),
            ),
            const SizedBox(height: 14),
            // The number pad has no return key; this is its submit.
            TestuButton(L('Go', 'Ir'),
                variant: TestuButtonVariant.primary,
                onTap: () => Navigator.of(ctx).pop(field.text)),
          ],
        ),
      ),
    );
    final page = int.tryParse(s ?? '');
    if (page != null) _goTo(page);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    _scroll.dispose();
    _chatScroll.dispose();
    _pageField.dispose();
    super.dispose();
  }

  /// Free text lands in a chat strip above the composer — the document
  /// never leaves view (continuous-tutor rule). Live: the tutor answers
  /// over the socket, citing this document's pages. Offline: canned reply.
  void _send(String text) {
    setState(() => _chat.add(TestuYouMsg(text: text)));
    if (widget.doc != null) {
      // One reply per question: the tutor's answer, the agent error the
      // server posts instead (already worded as "not available"), the
      // send failure, or the 90 s timeout — whichever comes first.
      void says(String s) {
        if (!mounted || !(_waiting || _late)) return;
        _late = false;
        _timeout?.cancel();
        final key = GlobalKey();
        setState(() {
          _waiting = false;
          _chat.removeWhere((w) => w.key == _typing);
          _chat.add(SullyMessage.reply(s,
              key: key,
              bottomPadding: 12,
              fallbackTitle: widget.doc!.title,
              fallbackPage: _cur,
              inDoc: widget.doc!.title,
              onOpenSource: _openSource,
              onFollowUp: _send));
        });
        // Read from the top of the answer, not its tail.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = key.currentContext;
          if (ctx != null) {
            Scrollable.ensureVisible(ctx,
                alignment: 0, duration: const Duration(milliseconds: 350));
          }
        });
        // The cited page comes into view on its own; "View source" repeats it.
        final c = splitCite(s);
        if (c.title == widget.doc!.title) _mark(c);
      }

      _sub ??= sullyReplies().listen(says);
      setState(() {
        _waiting = true;
        _late = false;
        _chat.add(const SullyMessage.typing(key: _typing));
      });
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: 90), () {
        if (!_waiting) return;
        says(sullySlowReply());
        // ponytail: the next tutor message is taken as the late answer.
        _late = true;
      });
      askSullyFree(text).catchError((Object e) => says(sullyFailure(e)));
    } else {
      setState(() => _chat.add(SullyMessage.text(
          L(
              "I'm on p. ${widget.page} with you — the section your question "
                  'cited. The rule on this page: chocks only after engines '
                  'are shut down and anti-collision lights are off.',
              'Estoy contigo en la p. ${widget.page} — la sección que citaba '
                  'tu pregunta. La regla de esta página: calzos solo con '
                  'motores apagados y luces anticolisión apagadas.'),
          delay: 850,
          sourceLine: 'FAA AC 00-34A',
          bottomPadding: 12)));
    }
    _down();
  }

  static const _typing = ValueKey('typing');

  /// This document cited → move here; another → open it on top.
  void _openSource(Cite c) => c.title == widget.doc!.title
      ? _mark(c)
      : openTestuSource(context, c);

  void _down() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chatScroll.hasClients) {
        _chatScroll.animateTo(_chatScroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: TestuTokens.curve);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final h = MediaQuery.sizeOf(context).height * 0.88;
    return SizedBox(
      height: h,
      child: Column(
        children: [
          const TestuGrabber(),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 0, 4, 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              children: [
                const TestuDocBadge('PDF'),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Sora',
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          letterSpacing: -0.15,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 1),
                      TestuPressable(
                        onTap: _askPage,
                        child: Text(
                          '${widget.sub} · p. $_cur / ${widget.pages}',
                          style: kMeta,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.doc?.toc.isNotEmpty ?? false)
                  TestuIconButton(TestuGlyph.list, onTap: _showToc),
                TestuIconButton(TestuGlyph.rotate, onTap: _rotate),
                TestuIconButton(TestuGlyph.close,
                    onTap: () => Navigator.of(context).pop()),
              ],
            ),
          ),
          if (MediaQuery.sizeOf(context).width >
              MediaQuery.sizeOf(context).height)
            // Landscape: pages + chat side by side — stacking them leaves
            // the document a sliver (continuous-tutor rule as a split).
            Expanded(
              child: Row(children: [
                Expanded(flex: 3, child: _pageList()),
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        16, 10, 16, 12 + MediaQuery.paddingOf(context).bottom),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_chat.isNotEmpty)
                            Flexible(
                              child: ListView(
                                controller: _chatScroll,
                                shrinkWrap: true,
                                children: List.of(_chat),
                              ),
                            )
                          else
                            _hint(t),
                          const SizedBox(height: 4),
                          _composer(),
                        ]),
                  ),
                ),
              ]),
            )
          else ...[
            Expanded(child: _pageList()),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  18, 10, 18, 12 + MediaQuery.paddingOf(context).bottom),
              color: t.card,
              child: Column(
                children: [
                  if (_chat.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      margin: const EdgeInsets.only(bottom: 4),
                      child: ListView(
                        controller: _chatScroll,
                        shrinkWrap: true,
                        children: List.of(_chat),
                      ),
                    )
                  else
                    Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _hint(t)),
                  _composer(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pageList() => LayoutBuilder(builder: (context, bc) {
        _pageListW = bc.maxWidth;
        return Container(
          // Reading surface: the same grey as the hairline track, so pages
          // and their shadows lift off it.
          color: TestuTokens.of(context).track,
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            // Fixed row height: exact offsets for go-to-page, and no silent
            // scroll "correction" when ↻ changes every row's height.
            itemExtent: _pitch,
            itemCount: widget.pages,
            itemBuilder: (context, i) => _Page(
                index: i + 1,
                pages: widget.pages,
                aspect: widget.aspect,
                title: widget.title,
                src: widget.src(i + 1),
                turns: _turns,
                rects: i + 1 == _hl.page ? _hl.rects : const []),
          ),
        );
      });

  Widget _hint(TestuTokens t) => Text(
        L('Tap a page to zoom · scroll for more',
            'Toca una página para ampliar · desplázate para ver más'),
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Geist', fontSize: 10, color: t.mut),
      );

  // Sully rides along inside the open source too (app-wide
  // continuous-tutor rule) — live input, see _send.
  Widget _composer() => TestuComposer(
        hint: L('Ask ${client.tutor} about this document…',
            'Pregunta a ${client.tutor} sobre este documento…'),
        onSend: _send,
      );
}

class _Page extends StatelessWidget {
  const _Page(
      {required this.index,
      required this.pages,
      required this.aspect,
      required this.title,
      required this.src,
      this.turns = 0,
      this.rects = const []});

  final int index;
  final int pages;
  final double aspect;
  final String title;
  final String src;

  /// Quarter turns (the viewer's rotate button).
  final int turns;

  /// Page-relative boxes of the cited passage (empty = no wash).
  final List<Rect> rects;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return GestureDetector(
      onTap: () => _zoom(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 10,
                offset: Offset(0, 2)),
          ],
        ),
        child: Stack(
          children: [
            TestuPageImage(src: src, aspect: aspect, turns: turns, rects: rects),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: BoxDecoration(
                  color: t.scrim,
                  borderRadius: BorderRadius.circular(4),
                ),
                // Expand glyph = visible fullscreen affordance (whole page
                // taps to zoom, but a hidden gesture isn't an "option").
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    'p. $index / $pages',
                    style: TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 9,
                      color: t.inkSoft,
                    ),
                  ),
                  const SizedBox(width: 5),
                  TestuIcon(TestuGlyph.expand, size: 9, color: t.inkSoft),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _zoom(BuildContext context) => showTestuZoom(context,
      asset: src,
      label: '$title · p. $index',
      aspect: aspect,
      turns: turns,
      rects: rects);
}

/// A rendered page: image at [aspect], turned [turns] quarters, with the
/// cited passage washed orange. The wash rotates with the page.
class TestuPageImage extends StatelessWidget {
  const TestuPageImage(
      {super.key,
      required this.src,
      required this.aspect,
      this.turns = 0,
      this.rects = const []});

  final String src;
  final double aspect;
  final int turns;
  final List<Rect> rects;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return AspectRatio(
      aspectRatio: turns.isOdd ? 1 / aspect : aspect,
      child: RotatedBox(
        quarterTurns: turns,
        child: AspectRatio(
          aspectRatio: aspect,
          child: Stack(fit: StackFit.expand, children: [
            Container(
              color: t.paper,
              child: Image(image: testuImage(src), fit: BoxFit.contain),
            ),
            if (rects.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: _Wash(rects, t.orange)),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Full-screen pinch-zoom lightbox — PDF pages and question media share it.
/// With [aspect] the page keeps its wash and rotation (PDF); without, the
/// raw image (question media). ↻ turns it a quarter each tap.
void showTestuZoom(BuildContext context,
    {required String asset,
    required String label,
    double? aspect,
    int turns = 0,
    List<Rect> rects = const []}) {
  HapticFeedback.selectionClick();
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: const Color(0xF20A0A0B),
      pageBuilder: (context, animation, secondaryAnimation) {
        var q = turns;
        return StatefulBuilder(
          builder: (context, setState) => Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            label,
                            style: kLabel,
                          ),
                        ),
                      ),
                      TestuIconButton(TestuGlyph.rotate,
                          onTap: () => setState(() => q = (q + 1) % 4)),
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: TestuIconButton(TestuGlyph.close,
                            onTap: () => Navigator.of(context).pop()),
                      ),
                    ],
                  ),
                  Expanded(
                    child: InteractiveViewer(
                      maxScale: 5,
                      child: Center(
                        child: aspect != null
                            ? TestuPageImage(
                                src: asset,
                                aspect: aspect,
                                turns: q,
                                rects: rects)
                            : RotatedBox(
                                quarterTurns: q,
                                child: Image(image: testuImage(asset))),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Orange wash over the cited passage: one box per text line, in page
/// fractions (the server's `[[hl …]]`), drawn over the rendered page.
class _Wash extends CustomPainter {
  const _Wash(this.rects, this.color);

  final List<Rect> rects;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.32);
    for (final r in rects) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(r.left * size.width - 2, r.top * size.height - 1,
              r.width * size.width + 4, r.height * size.height + 2),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_Wash old) => old.rects != rects || old.color != color;
}
