import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'testu_i18n.dart';
import 'testu_theme.dart';
import 'testu_widgets.dart';

const _pages = 11; // assets/docs/pages/p-NN.jpg — rendered FAA AC 00-34A
const _pageAspect = 1284 / 1667;

/// In-app source viewer: bottom sheet of pre-rendered PDF pages, opened
/// scrolled to the cited page. Blue "Open source" links land here.
void showTestuPdf(BuildContext context, {int page = 1, String? cite}) {
  HapticFeedback.selectionClick();
  final sub = (cite ??
          L('Aircraft Ground Handling and Servicing',
              'Manipulación y Servicio de Aeronaves en Tierra'))
      .replaceFirst(RegExp(r'^FAA AC 00-34A\s*·\s*'), '');
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0xA8000000),
    builder: (_) => _PdfSheet(page: page, sub: '$sub · p. $page'),
  );
}

class _PdfSheet extends StatefulWidget {
  const _PdfSheet({required this.page, required this.sub});

  final int page;
  final String sub;

  @override
  State<_PdfSheet> createState() => _PdfSheetState();
}

class _PdfSheetState extends State<_PdfSheet> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final pageW = MediaQuery.sizeOf(context).width - 24;
      final off = (widget.page - 1) * (pageW / _pageAspect + 10);
      _scroll.jumpTo(off.clamp(0, _scroll.position.maxScrollExtent));
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
                        'FAA AC 00-34A',
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
          Expanded(
            child: Container(
              color: const Color(0xFF26272B),
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 12),
                itemCount: _pages,
                itemBuilder: (context, i) => _Page(index: i + 1),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
                top: 8,
                bottom: 10 + MediaQuery.paddingOf(context).bottom),
            color: t.card,
            child: Text(
              L('Tap a page to zoom · scroll for more',
                  'Toca una página para ampliar · desplázate para ver más'),
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontFamily: 'Geist', fontSize: 10, color: t.mut),
            ),
          ),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.index});

  final int index;

  String get _asset =>
      'assets/docs/pages/p-${index.toString().padLeft(2, '0')}.jpg';

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
              aspectRatio: _pageAspect,
              child: Container(
                color: const Color(0xFFF2F1EC),
                child: Image.asset(_asset, fit: BoxFit.cover),
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
                child: Text(
                  'p. $index / $_pages',
                  style: const TextStyle(
                    fontFamily: 'GeistMono',
                    fontSize: 9,
                    color: Color(0xFFD8D7D3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _zoom(BuildContext context) =>
      showTestuZoom(context, asset: _asset, label: 'FAA AC 00-34A · p. $index');
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
                    child: Center(child: Image.asset(asset)),
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
