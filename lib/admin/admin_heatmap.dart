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

/// 28 px tall, wide enough for `12/14` in mono plus a Spanish subtopic name
/// on two lines above it.
const double _cellW = 60;
const double _cellH = 28;
const double _gap = 4;
const double _rowH = _cellH + _gap;
const double _topicH = 20;
/// Two lines of an 11 px column name, with room for a descender: at 36 the
/// second line of "Contraseñas" was sliced in half.
const double _headH = 44;
const double _labelW = 190;

class HeatmapGrid extends StatelessWidget {
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
    // ponytail: one horizontal scroll view holding the header AND the body,
    // with the name column pinned outside it. Two synchronised controllers
    // would buy a vertically sticky header too — which this screen does not
    // need, since the whole page is one scroller and the grid is never taller
    // than a laptop viewport at Minsur's cohort size.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: _labelW, child: _labels(t)),
        Expanded(
          child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: _grid(t)),
        ),
      ],
    );
  }

  Widget _labels(TestuTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: _topicH),
      SizedBox(
        height: _headH,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(rowHeader, style: AdminTokens.tableHead),
          ),
        ),
      ),
      Container(height: 1, color: t.line),
      for (final r in rows) SizedBox(height: _rowH, child: _label(t, r)),
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
      onTap: () => onRow(r.id),
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

  Widget _grid(TestuTokens t) {
    final width = cols.length * (_cellW + _gap);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: _topicH,
          child: Row(
            children: [
              for (final (name, span) in _topics)
                SizedBox(
                  width: span * (_cellW + _gap),
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
              for (final c in cols)
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, _gap, 7),
                  child: SizedBox(
                    width: _cellW,
                    child: Tooltip(
                      message: c.name,
                      waitDuration: Duration.zero,
                      textStyle: AdminTokens.mono(11),
                      decoration: AdminTokens.tip,
                      child: Text(
                        c.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AdminTokens.tableHead,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, width: width, color: t.line),
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
                      onTap: r.id.isEmpty ? null : () => onRow(r.id),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One cell, with its own hover state: hovering 400 cells must rebuild one of
/// them, not the grid.
class _Cell extends StatefulWidget {
  const _Cell({required this.cell, required this.group, required this.onTap});

  final HeatCell? cell;
  final bool group;
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
          child: SizedBox(width: _cellW, height: _cellH, child: body),
        ),
      ),
    );

    if (cell == null) return out;

    out = Tooltip(
      richMessage: WidgetSpan(alignment: PlaceholderAlignment.middle, child: _Tip(cell)),
      waitDuration: Duration.zero,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
      decoration: AdminTokens.tip,
      child: out,
    );
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
