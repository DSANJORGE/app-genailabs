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
    {int page = 1, String? cite, LiveDoc? doc}) {
  HapticFeedback.selectionClick();
  // Live: a citation whose title matches no loaded document still opens a
  // server document, not the offline demo's aviation manual.
  doc ??= testuLive ? liveDocs.values.firstOrNull : null;
  final sub = doc != null
      ? L('Reference document', 'Documento de referencia')
      : (cite ??
              CL('Human Rights Policy', 'Política de Derechos Humanos',
                  'Aircraft Ground Handling and Servicing',
                  'Manipulación y Servicio de Aeronaves en Tierra'))
          .replaceFirst(RegExp(r'^FAA AC 00-34A\s*·\s*'), '');
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xA8000000),
    builder: (_) => _PdfSheet(page: page, sub: '$sub · p. $page', doc: doc),
  );
}

class _PdfSheet extends StatefulWidget {
  const _PdfSheet({required this.page, required this.sub, this.doc});

  final int page;
  final String sub;
  final LiveDoc? doc;

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

  // Real rendered width of the page column (set by _pageList's
  // LayoutBuilder during the first build) — the sheet is width-capped and
  // splits in landscape, so deriving this from the screen guesses wrong.
  double _pageListW = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pageW = _pageListW - 24;
      final off = (widget.page - 1) * (pageW / widget.aspect + 10);
      _scroll.jumpTo(off.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeout?.cancel();
    _scroll.dispose();
    _chatScroll.dispose();
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
        if (!mounted || !_waiting) return;
        _timeout?.cancel();
        setState(() {
          _waiting = false;
          _chat.add(SullyMessage.reply(s,
              bottomPadding: 12,
              fallbackTitle: widget.doc!.title,
              fallbackPage: widget.page));
        });
        _down();
      }

      _sub ??= sullyReplies().listen(says);
      setState(() => _waiting = true);
      _timeout?.cancel();
      _timeout = Timer(const Duration(seconds: 90), () {
        if (_waiting) says(sullySlowReply());
      });
      askSullyFree(text).catchError((_) => says(sullyUnavailable()));
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
    return Container(
      height: h,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: t.line2)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 14, bottom: 16),
            decoration: BoxDecoration(
              color: t.line2,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 0, 12, 13),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: t.line)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.card2,
                    border: Border.all(color: t.line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'PDF',
                    style: TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: t.mut,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
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
                          fontSize: 14,
                          letterSpacing: -0.14,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.sub,
                        style: kMeta,
                      ),
                    ],
                  ),
                ),
                TestuPressable(
                  onTap: () => Navigator.of(context).pop(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Text('✕',
                        style: TextStyle(fontSize: 15, color: t.mut)),
                  ),
                ),
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
          color: const Color(0xFF26272B),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            itemCount: widget.pages,
            itemBuilder: (context, i) => _Page(
                index: i + 1,
                pages: widget.pages,
                aspect: widget.aspect,
                title: widget.title,
                src: widget.src(i + 1)),
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
      required this.src});

  final int index;
  final int pages;
  final double aspect;
  final String title;
  final String src;

  @override
  Widget build(BuildContext context) {
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
            AspectRatio(
              aspectRatio: aspect,
              child: Container(
                color: const Color(0xFFF2F1EC),
                child: Image(image: testuImage(src), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xCC0A0A0B),
                  borderRadius: BorderRadius.circular(4),
                ),
                // Expand glyph = visible fullscreen affordance (whole page
                // taps to zoom, but a hidden gesture isn't an "option").
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    'p. $index / $pages',
                    style: const TextStyle(
                      fontFamily: 'GeistMono',
                      fontSize: 9,
                      color: Color(0xFFD8D7D3),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const TestuIcon(TestuGlyph.expand,
                      size: 9, color: Color(0xFFD8D7D3)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _zoom(BuildContext context) =>
      showTestuZoom(context, asset: src, label: '$title · p. $index');
}

/// Full-screen pinch-zoom lightbox — PDF pages and question media share it.
void showTestuZoom(BuildContext context,
    {required String asset, required String label}) {
  HapticFeedback.selectionClick();
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: const Color(0xF20A0A0B),
      pageBuilder: (context, animation, secondaryAnimation) {
        final t = TestuTokens.of(context);
        return Scaffold(
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
                    TestuPressable(
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text('✕',
                            style: TextStyle(fontSize: 16, color: t.mut)),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(
                    maxScale: 5,
                    child: Center(child: Image(image: testuImage(asset))),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
