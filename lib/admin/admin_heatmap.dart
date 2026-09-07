import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import '../testu/testu_widgets.dart';
import 'admin_theme.dart';
import 'admin_ui.dart';

/// The console's person x subtopic grid (spec analytics-v1 §5, §6.3): sticky
/// first column, 28 px cells, level tint, the count on hover, click opens the
/// row's page.
///
/// It knows nothing about mastery, teams or the API — it lays out [HeatCol]s,
/// [HeatRow]s and [HeatCell]s and reports which row was activated. Every word
/// a reader sees (the row label, the tooltip title, the level name, the
/// sentence under it) is composed by the caller, so the grid never has to
/// grow a vocabulary of its own.

/// One column: a subtopic, and the topic it belongs to. Consecutive columns
/// sharing a [topic] are spanned by one topic header.
class HeatCol {
  const HeatCol(this.topic, this.name);
  final String topic, name;
}

/// One cell. A person cell paints [level] as a tint and shows
/// `mastered/answered` on hover; a group cell (one with [levels]) paints the
/// team's [LevelBar] for that subtopic instead.
class HeatCell {
  const HeatCell({
    required this.title,
    this.level,
    this.levelLabel,
    this.detail,
    this.mastered = 0,
    this.answered = 0,
    this.questions = 0,
    this.levels,
    this.highlight = false,
  });

  /// "Ana Quispe · Phishing" — the tooltip's first line.
  final String title;
  final String? level;

  /// What the level is called, for the tooltip pill and the semantics.
  final String? levelLabel;

  /// The sentence under the pill, already worded by the caller.
  final String? detail;
  final int mastered, answered, questions;

  /// People per level. Present only on a group row, and what makes it one.
  final Map<String, int>? levels;

  /// The weakest column, underlined in `focus` — the one the reading names.
  final bool highlight;
}

/// One row: a person, a team, or the summary strip. [cells] is positional
/// against the column list; a null cell is a subtopic this row never touched.
class HeatRow {
  const HeatRow({
    required this.id,
    required this.label,
    required this.cells,
    this.group = false,
  });

  /// What [HeatmapGrid.onRow] hands back.
  final String id;
  final String label;
  final List<HeatCell?> cells;

  /// A team aggregate or the summary strip: quieter label, bars for cells.
  final bool group;
}

/// 28 px tall. The width is the card's to give: at least 76 (the longest
/// single word in a Minsur subtopic title -- "Fundamentos," "ransomware",
/// "Inteligencia" -- at 11 px, so a header breaks between words and never
/// inside one), at most 132, and otherwise an even share of the card. Eight
/// subtopics at a fixed 60 px left a third of the card empty while every
/// column name was cut to "Fundamen / tos, cultu…"; fourteen scroll.
const double _minCellW = 76;
const double _maxCellW = 132;
const double _cellH = 28;
const double _gap = 4;
const double _rowH = _cellH + _gap;
const double _topicH = 20;
/// Three lines of an 11 px column name, with room for a descender: the long
/// Spanish titles ("Fundamentos, cultura y gestión de incidentes") need the
/// third line even at the widest cell.
const double _headH = 58;
const double _labelW = 190;

class HeatmapGrid extends StatefulWidget {
  const HeatmapGrid({
    super.key,
    required this.cols,
    required this.rows,
    required this.onRow,
    this.rowHeader = '',
  });

  final List<HeatCol> cols;
  final List<HeatRow> rows;
  final void Function(String rowId) onRow;

  /// What the pinned first column is a list of ("Persona", "Equipo").
  final String rowHeader;

  @override
  State<HeatmapGrid> createState() => _HeatmapGridState();
}

class _HeatmapGridState extends State<HeatmapGrid> {
  /// The header and the body scroll sideways as one: each controller follows
  /// the other, so the column names stay over their cells while the body
  /// scrolls down under them.
  final _head = ScrollController();
  final _body = ScrollController();

  /// Column widths the reader has dragged, by index; the rest share the card.
  /// The same handle as [AdminTable], double-click hands the column back.
  final _dragged = <int, double>{};

  List<HeatCol> get cols => widget.cols;
  List<HeatRow> get rows => widget.rows;

  @override
  void initState() {
    super.initState();
    _head.addListener(() => _follow(_head, _body));
    _body.addListener(() => _follow(_body, _head));
  }

  @override
  void dispose() {
    _head.dispose();
    _body.dispose();
    super.dispose();
  }

  void _follow(ScrollController from, ScrollController to) {
    if (to.hasClients && (to.offset - from.offset).abs() > 0.5) {
      to.jumpTo(from.offset);
    }
  }

  /// Consecutive columns under one topic: `(name, span)`.
  List<(String, int)> get _topics {
    final out = <(String, int)>[];
    for (final c in cols) {
      if (out.isNotEmpty && out.last.$1 == c.topic) {
        out[out.length - 1] = (c.topic, out.last.$2 + 1);
      } else {
        out.add((c.topic, 1));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    if (cols.isEmpty || rows.isEmpty) return const SizedBox.shrink();
    final t = TestuTokens.of(context);
    return LayoutBuilder(builder: (context, box) {
      final cellW = box.maxWidth.isFinite
          ? ((box.maxWidth - _labelW) / cols.length - _gap)
              .clamp(_minCellW, _maxCellW)
          : _minCellW;
      final widths = [for (var i = 0; i < cols.length; i++) _dragged[i] ?? cellW];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: _labelW, child: _labelHead(t)),
              Expanded(
                child: HScroll(
                  controller: _head,
                  child: _gridHead(t, widths, cellW),
                ),
              ),
            ],
          ),
          // The body scrolls under the pinned header once it outruns the
          // viewport; at its end the wheel goes on to the page. The thumb
          // lives on the header, where it never scrolls out of sight.
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: AdminTokens.bodyMax(context)),
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: _labelW,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final r in rows)
                          SizedBox(height: _rowH, child: _label(t, r)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: HScroll(
                      controller: _body,
                      thumb: false,
                      child: _gridBody(widths),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _labelHead(TestuTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: _topicH),
      SizedBox(
        height: _headH,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(widget.rowHeader, style: AdminTokens.tableHead),
          ),
        ),
      ),
      Container(height: 1, color: t.line),
    ],
  );

  Widget _label(TestuTokens t, HeatRow r) {
    final text = Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Text(
          r.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: r.group
              ? TextStyle(fontFamily: 'Geist', fontSize: 11, color: t.mut)
              : AdminTokens.table,
        ),
      ),
    );
    // The summary strip is a reading, not a destination.
    if (r.id.isEmpty) return text;
    return ConsoleInteractive(
      onTap: () => widget.onRow(r.id),
      radius: 4,
      builder: (context, hovered) => DecoratedBox(
        decoration: BoxDecoration(
          color: hovered ? AdminTokens.hover : null,
          borderRadius: BorderRadius.circular(4),
        ),
        child: text,
      ),
    );
  }

  Widget _gridHead(TestuTokens t, List<double> widths, double cellW) {
    final width = widths.fold(0.0, (a, w) => a + w + _gap);
    // Each topic header spans the columns under it, at whatever widths they
    // have been dragged to.
    final spans = <(String, double)>[];
    var col = 0;
    for (final (name, span) in _topics) {
      var w = 0.0;
      for (var i = 0; i < span; i++) {
        w += widths[col++] + _gap;
      }
      spans.add((name, w));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _topicH,
          child: Row(
            children: [
              for (final (name, w) in spans)
                SizedBox(
                  width: w,
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Geist', fontSize: 11, color: t.ink),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: _headH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < cols.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: _gap),
                  child: SizedBox(
                    width: widths[i],
                    height: _headH,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 7,
                          child: ConsoleTip(
                            message: cols[i].name,
                            child: Text(
                              cols[i].name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: AdminTokens.tableHead.copyWith(height: 1.25),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: 8,
                          child: ColumnResizer(
                            onStart: () => _dragged[i] ??= widths[i],
                            onDrag: (dx) => setState(() => _dragged[i] =
                                (_dragged[i]! + dx).clamp(40.0, 400.0)),
                            onReset: () => setState(() => _dragged.remove(i)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, width: width, color: t.line),
      ],
    );
  }

  Widget _gridBody(List<double> widths) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final r in rows)
            SizedBox(
              height: _rowH,
              child: Row(
                children: [
                  for (var i = 0; i < cols.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: _gap),
                      child: _Cell(
                        cell: i < r.cells.length ? r.cells[i] : null,
                        group: r.group,
                        width: widths[i],
                        onTap: r.id.isEmpty ? null : () => widget.onRow(r.id),
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
}

/// One cell, with its own hover state: hovering 400 cells must rebuild one of
/// them, not the grid.
class _Cell extends StatefulWidget {
  const _Cell({
    required this.cell,
    required this.group,
    required this.width,
    required this.onTap,
  });

  final HeatCell? cell;
  final bool group;
  final double width;
  final VoidCallback? onTap;

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    final cell = widget.cell;
    final ring = _hovered || _focused;

    final Widget face = cell != null && widget.group
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: LevelBar(cell.levels ?? const {}),
          )
        : Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AdminTokens.levelTint(cell?.level),
              borderRadius: BorderRadius.circular(4),
              // The ring is inset on the tint rather than around the cell, so
              // hover never nudges the column by a pixel.
              border: ring ? Border.all(color: t.ink) : null,
            ),
            // Default is the tint alone; the numbers arrive on hover, so a
            // wall of cells reads as a shape before it reads as arithmetic.
            child: !ring
                ? null
                : Text(
                    cell == null || cell.answered == 0
                        ? '\u2014'
                        : '${cell.mastered}/${cell.answered}',
                    style: AdminTokens.mono(10.5, color: cell == null ? t.faint : t.ink),
                  ),
          );

    // The weakest column carries a `focus` underline, painted OVER the cell
    // rather than taking height off it -- a Column here shortened the face,
    // and a group row's 6 px LevelBar rendered half height in the one column
    // the reader is meant to look at.
    final Widget body = cell != null && cell.highlight
        ? Stack(
            children: [
              Positioned.fill(child: face),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 2,
                child: Container(color: AdminTokens.focus),
              ),
            ],
          )
        : face;

    // Hover rides a plain MouseRegion rather than FocusableActionDetector's
    // onShowHoverHighlight: that one is gated on the focus highlight mode, so
    // it stays silent until something else has already told the framework a
    // mouse is driving — and the count is the cell's only label.
    Widget out = FocusableActionDetector(
      enabled: widget.onTap != null,
      onShowFocusHighlight: (v) => setState(() => _focused = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onTap?.call(),
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) => widget.onTap?.call(),
        ),
      },
      child: MouseRegion(
        cursor: widget.onTap == null
            ? SystemMouseCursors.basic
            : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: SizedBox(width: widget.width, height: _cellH, child: body),
        ),
      ),
    );

    if (cell == null) return out;

    out = ConsoleTip(message: _semantics(cell), rich: _Tip(cell), child: out);
    // excludeSemantics: a group cell wraps a LevelBar, which publishes its own
    // distribution label -- without this the screen reader says it twice.
    return Semantics(
      label: _semantics(cell),
      button: widget.onTap != null,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: out,
    );
  }

  /// A tint plus a hover count is nothing to a screen reader: every cell says
  /// who, which subtopic, what level and how many. A group cell has no
  /// person's counts to read out — its own distribution is the reading.
  String _semantics(HeatCell cell) {
    final parts = <String>[
      cell.title,
      if (cell.levels != null)
        cell.detail ?? ''
      else ...[
        if (cell.levelLabel != null) cell.levelLabel!,
        '${cell.mastered}/${cell.answered}',
        if (cell.questions > 0)
          '${cell.questions} ${L('questions', 'preguntas')}',
      ],
    ];
    return parts.where((p) => p.isNotEmpty).join(' · ');
  }
}

/// The level as pill text. `beginner` swaps the fill red for the app's text
/// red: it is the one of the three that misses 4.5:1 at pill size (see
/// AdminTokens.redText), and the tooltip is exactly where the level is read
/// as a word rather than seen as a tint.
Color _pillInk(String? level) =>
    level == 'beginner' ? AdminTokens.redText : AdminTokens.level(level);

/// The tooltip body: who and where, the level as a pill, then the sentence.
class _Tip extends StatelessWidget {
  const _Tip(this.cell);

  final HeatCell cell;

  @override
  Widget build(BuildContext context) {
    final t = TestuTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  cell.title,
                  style: TextStyle(fontFamily: 'Geist', fontSize: 11.5, color: t.ink),
                ),
              ),
              if (cell.levelLabel != null) ...[
                const SizedBox(width: 8),
                TestuPill(
                  cell.levelLabel!,
                  color: _pillInk(cell.level),
                  borderColor: _pillInk(cell.level).withValues(alpha: 0.45),
                ),
              ],
            ],
          ),
          if (cell.detail != null) ...[
            const SizedBox(height: 5),
            Text(
              cell.detail!,
              style: TextStyle(
                fontFamily: 'Geist',
                fontSize: 10.5,
                height: 1.4,
                color: t.mut,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
