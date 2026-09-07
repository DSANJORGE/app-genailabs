import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../testu/testu_i18n.dart';
import '../testu/testu_theme.dart';
import 'admin_models.dart';
import 'admin_theme.dart';

/// The console's `fl_chart` theme, as factories rather than a wrapper widget:
/// transparent backgrounds, 1 px `line` horizontal gridlines and nothing
/// else, mono axis labels, and tooltips that are `card2` boxes on a hairline
/// with the value in mono — the app's own anatomy, not fl_chart's defaults.
///
/// Every chart here also states its values as text in a tooltip, so a colour
/// is never the only way to read one (spec §5, accessibility).

const _t = TestuTokens.instance;

/// Mono axis label, 9.5 px +0.12em `faint`.
TextStyle get _axisStyle => AdminTokens
    .mono(9.5, color: AdminTokens.axis)
    .copyWith(letterSpacing: 1.14);

TextStyle get _tipStyle => AdminTokens.mono(11);

FlGridData _grid() => FlGridData(
      drawVerticalLine: false,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: AdminTokens.grid, strokeWidth: 1),
    );

AxisTitles get _noTitles => const AxisTitles();

Widget _axisText(String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: _axisStyle),
    );

/// `5/9` — the day label every chart axis and tooltip uses.
String dm(DateTime d) => '${d.day}/${d.month}';

/// What the previous-period ghost says on hover. It carries ITS OWN day:
/// without one, two tooltips on the same x read as two figures for the same
/// date, when the whole point of the ghost is that it is another window.
String compareTip(DayPoint day, String peopleLabel) =>
    '${dm(day.day)}  ${day.people} $peopleLabel · '
    '${L('previous period', 'periodo anterior')}';

/// The 300 ms first draw, then instant redraws.
///
/// fl_chart's charts are [ImplicitlyAnimatedWidget]s: they tween when the
/// DATA changes, not when they mount, so handing the first build a 300 ms
/// duration animates nothing. This mounts a flattened copy of the series
/// (every value × `scale` = 0) and swaps the real one in on the next frame —
/// that data change is what the 300 ms curve draws. Once it has run, the
/// duration drops to zero so a filter change redraws instantly.
///
/// Under `MediaQuery.disableAnimations` there is nothing to draw from: the
/// real data is mounted directly, at zero duration.
class _FirstDraw extends StatefulWidget {
  const _FirstDraw(this.builder);

  final Widget Function(BuildContext context, Duration duration, double scale)
      builder;

  @override
  State<_FirstDraw> createState() => _FirstDrawState();
}

class _FirstDrawState extends State<_FirstDraw> {
  static const _ms = 300;

  double _scale = 0;
  bool _settled = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _scale = 1);
      _timer = Timer(const Duration(milliseconds: _ms), () {
        if (mounted) setState(() => _settled = true);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draw = AdminTokens.dur(context, _ms);
    if (draw == Duration.zero) return widget.builder(context, draw, 1);
    return widget.builder(context, _settled ? Duration.zero : draw, _scale);
  }
}

/// The 28 px trend line inside a `StatBlock`: no axes, no grid, no touch —
/// the number above it is the value, this is only its shape.
LineChartData sparklineData(List<num> values) {
  final spots = [
    for (var i = 0; i < values.length; i++)
      FlSpot(i.toDouble(), values[i].toDouble()),
  ];
  return LineChartData(
    gridData: const FlGridData(show: false),
    titlesData: const FlTitlesData(show: false),
    borderData: FlBorderData(show: false),
    lineTouchData: const LineTouchData(enabled: false),
    minY: 0,
    lineBarsData: [
      LineChartBarData(
        spots: spots,
        color: AdminTokens.focus,
        barWidth: 1.4,
        isCurved: true,
        curveSmoothness: 0.2,
        preventCurveOverShooting: true,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: AdminTokens.focus.withValues(alpha: 0.12),
        ),
      ),
    ],
  );
}

/// People (line, `focus`) over answers (bars, muted), on one time axis. The
/// two series have different units, so the bars are scaled onto the people
/// axis and the right-hand labels carry the answers scale.
Widget activityChart({
  required List<DayPoint> series,
  List<DayPoint>? previous,
  required String peopleLabel,
  required String answersLabel,
}) {
  if (series.isEmpty) return const SizedBox.shrink();

  final maxPeople = series
      .map((d) => d.people)
      .followedBy((previous ?? const <DayPoint>[]).map((d) => d.people))
      .fold<int>(0, (a, b) => a > b ? a : b);
  final maxAnswers = series.map((d) => d.answers).fold<int>(0, (a, b) => a > b ? a : b);
  final topY = (maxPeople == 0 ? 1 : maxPeople) * 1.15;
  // Bars are drawn in people units; this is the conversion back and forth.
  double toPeopleScale(int answers) =>
      maxAnswers == 0 ? 0 : answers * topY / (maxAnswers * 1.15);

  final hasPrevious = previous != null && previous.isNotEmpty;

  return _FirstDraw((context, duration, scale) {
    final bars = BarChart(
      BarChartData(
        maxY: topY,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => _t.card2,
            tooltipBorder: BorderSide(color: _t.line),
            getTooltipItem: (group, _, _, _) => BarTooltipItem(
              '${series[group.x].answers} $answersLabel',
              _tipStyle,
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < series.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: toPeopleScale(series[i].answers) * scale,
                  color: _t.mut.withValues(alpha: 0.55),
                  width: 6,
                  borderRadius: BorderRadius.circular(1),
                ),
              ],
            ),
        ],
      ),
      duration: duration,
      curve: TestuTokens.curve,
    );

    final line = LineChart(
      LineChartData(
        maxY: topY,
        minY: 0,
        // `BarChartAlignment.spaceAround` centres group i at (i + 0.5) / n of
        // the plot width. Half a slot of padding at each end puts the line's
        // x = i — and the bottom label for day i — over that centre.
        minX: -0.5,
        maxX: series.length - 0.5,
        gridData: _grid(),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: _noTitles,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              // The axis top is maxPeople x 1.15 -- a number a hair above the
              // last gridline, so labelling it prints "16" over "15".
              maxIncluded: false,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(v.round().toString(),
                    style: _axisStyle, textAlign: TextAlign.right),
              ),
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: maxAnswers > 0,
              reservedSize: 38,
              maxIncluded: false,
              getTitlesWidget: (v, _) => Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  (topY == 0 ? 0 : v * maxAnswers * 1.15 / topY).round().toString(),
                  style: _axisStyle,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: (series.length / 6).ceilToDouble().clamp(1, 30),
              // minX/maxX are half-slot padding, not days.
              minIncluded: false,
              maxIncluded: false,
              getTitlesWidget: (v, _) {
                final i = v.round();
                if (i < 0 || i >= series.length) return const SizedBox.shrink();
                return _axisText(dm(series[i].day));
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => _t.card2,
            tooltipBorder: BorderSide(color: _t.line),
            getTooltipItems: (spots) => [
              for (final s in spots)
                // barIndex 0 is the previous-period ghost whenever there is
                // one; reading `series` for it would print this period's
                // numbers under the compare line.
                if (hasPrevious && s.barIndex == 0)
                  LineTooltipItem(
                    compareTip(
                      previous[s.x.round().clamp(0, previous.length - 1)],
                      peopleLabel,
                    ),
                    _tipStyle,
                  )
                else
                  LineTooltipItem(
                    '${dm(series[s.x.round()].day)}  '
                    '${series[s.x.round()].people} $peopleLabel  ·  '
                    '${series[s.x.round()].answers} $answersLabel',
                    _tipStyle,
                  ),
            ],
          ),
        ),
        lineBarsData: [
          if (hasPrevious)
            LineChartBarData(
              spots: [
                for (var i = 0; i < previous.length && i < series.length; i++)
                  FlSpot(i.toDouble(), previous[i].people * scale),
              ],
              color: AdminTokens.compare,
              barWidth: 1.2,
              dotData: const FlDotData(show: false),
            ),
          LineChartBarData(
            spots: [
              for (var i = 0; i < series.length; i++)
                FlSpot(i.toDouble(), series[i].people * scale),
            ],
            color: AdminTokens.focus,
            barWidth: 1.8,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AdminTokens.focus.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
      duration: duration,
      curve: TestuTokens.curve,
    );

    // The bars sit under the line and inside the same left/right gutters the
    // line reserves for its axis labels, so the two grids line up.
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(34, 0, 38, 26),
          child: bars,
        ),
        line,
      ],
    );
  });
}

/// One muted bar per day of any single `DayPoint` counter.
Widget dailyBars(
  List<DayPoint> series, {
  required num Function(DayPoint) value,
  Color? color,
}) {
  if (series.isEmpty) return const SizedBox.shrink();
  final fill = color ?? AdminTokens.focus;
  final top = series
      .map((d) => value(d).toDouble())
      .fold<double>(0, (a, b) => a > b ? a : b);

  return LayoutBuilder(
    builder: (context, box) {
      // The rod grows with the card: a fixed 8 px bar reads as a stick on a
      // week of data across a 950 px card.
      final width = box.maxWidth.isFinite
          ? ((box.maxWidth - 34) / series.length * 0.42).clamp(6.0, 22.0)
          : 8.0;
      return _FirstDraw((context, duration, scale) => BarChart(
        BarChartData(
          maxY: top == 0 ? 1 : top * 1.15,
          gridData: _grid(),
          borderData: FlBorderData(show: false),
          alignment: BarChartAlignment.spaceAround,
          titlesData: FlTitlesData(
            topTitles: _noTitles,
            rightTitles: _noTitles,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                // See activityChart: the padded axis top would print over the
                // last gridline's label.
                maxIncluded: false,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(v.round().toString(), style: _axisStyle),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: (series.length / 6).ceilToDouble().clamp(1, 30),
                getTitlesWidget: (v, _) {
                  final i = v.round();
                  if (i < 0 || i >= series.length) {
                    return const SizedBox.shrink();
                  }
                  return _axisText(dm(series[i].day));
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _t.card2,
              tooltipBorder: BorderSide(color: _t.line),
              getTooltipItem: (group, _, _, _) => BarTooltipItem(
                '${dm(series[group.x].day)}  '
                '${value(series[group.x])}',
                _tipStyle,
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < series.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: value(series[i]) * scale,
                    color: fill,
                    width: width,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ],
              ),
          ],
        ),
        duration: duration,
        curve: TestuTokens.curve,
      ));
    },
  );
}

/// Correct against incorrect per day — the app's own week-card pair, stacked
/// so the column height is the day's total answers.
Widget correctIncorrectBars(
    List<({String label, int correct, int incorrect})> days) {
  if (days.isEmpty) return const SizedBox.shrink();
  final top = days
      .map((d) => (d.correct + d.incorrect).toDouble())
      .fold<double>(0, (a, b) => a > b ? a : b);

  return _FirstDraw((context, duration, scale) => BarChart(
        BarChartData(
          maxY: top == 0 ? 1 : top * 1.15,
          gridData: _grid(),
          borderData: FlBorderData(show: false),
          alignment: BarChartAlignment.spaceAround,
          titlesData: FlTitlesData(
            topTitles: _noTitles,
            rightTitles: _noTitles,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                // See activityChart: the padded axis top would print over the
                // last gridline's label.
                maxIncluded: false,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(v.round().toString(), style: _axisStyle),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: (days.length / 7).ceilToDouble().clamp(1, 30),
                getTitlesWidget: (v, _) {
                  final i = v.round();
                  if (i < 0 || i >= days.length) {
                    return const SizedBox.shrink();
                  }
                  return _axisText(days[i].label);
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => _t.card2,
              tooltipBorder: BorderSide(color: _t.line),
              getTooltipItem: (group, _, _, _) => BarTooltipItem(
                '${days[group.x].label}  '
                '${days[group.x].correct} ${L('correct', 'correctas')}  ·  '
                '${days[group.x].incorrect} ${L('incorrect', 'incorrectas')}',
                _tipStyle,
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < days.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: (days[i].correct + days[i].incorrect) * scale,
                    width: 10,
                    borderRadius: BorderRadius.circular(1),
                    color: AdminTokens.seriesNegative,
                    rodStackItems: [
                      BarChartRodStackItem(
                        0,
                        days[i].correct * scale,
                        AdminTokens.seriesPositive,
                      ),
                      BarChartRodStackItem(
                        days[i].correct * scale,
                        (days[i].correct + days[i].incorrect) * scale,
                        AdminTokens.seriesNegative,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
        duration: duration,
        curve: TestuTokens.curve,
      ));
}

/// When the organisation studies: 7 rows × 24 columns of 14 px cells, tinted
/// `focus` by share of the busiest hour. The count is in every cell's
/// tooltip, so the tint is never the only reading.
///
/// `cells` is sparse — the server sends only the hours it has, never 168
/// triples — and its weekday is 0-based with Monday first.
Widget hoursHeatmap(List<(int wd, int h, int n)> cells) {
  final counts = <int, int>{};
  for (final (wd, h, n) in cells) {
    counts[wd * 24 + h] = (counts[wd * 24 + h] ?? 0) + n;
  }
  final max = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
  final dayNames = [
    L('Mon', 'Lun'),
    L('Tue', 'Mar'),
    L('Wed', 'Mié'),
    L('Thu', 'Jue'),
    L('Fri', 'Vie'),
    L('Sat', 'Sáb'),
    L('Sun', 'Dom'),
  ];

  // The grid is 24 columns of whatever the card can spare, not a fixed 418 px
  // block sitting in the left third of a 980 px card. Height follows width so
  // the cells stay cells rather than turning into ribbons.
  const labelW = 34.0;
  const gap = 2.0;
  return LayoutBuilder(
    builder: (context, box) {
      final w = box.maxWidth.isFinite
          ? ((box.maxWidth - labelW) / 24 - gap).clamp(12.0, 44.0)
          : 14.0;
      // 7 rows plus the hour labels, inside whatever height the card allows:
      // a card with a fixed height must not be overflowed by its own chart.
      final room = box.maxHeight.isFinite
          ? ((box.maxHeight - 18) / 7 - gap).clamp(8.0, 20.0)
          : 20.0;
      // Not clamp(12, room): a very short card makes `room` smaller than the
      // floor, and clamp asserts when its bounds cross.
      final h = w > room ? room : w;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const SizedBox(width: labelW),
              for (var hour = 0; hour < 24; hour += 3)
                SizedBox(
                  width: 3 * (w + gap),
                  child: Text('$hour', style: _axisStyle),
                ),
            ],
          ),
          const SizedBox(height: 4),
          // `wd` is the server's own weekday: Monday = 0 through Sunday = 6
          // (`(Calendar.DAY_OF_WEEK + 5) % 7` in activity.groovy). Reading it
          // as 1-7 loses Monday entirely and labels every other day one row
          // early.
          for (var wd = 0; wd < 7; wd++)
            Padding(
              padding: const EdgeInsets.only(bottom: gap),
              child: Row(
                children: [
                  SizedBox(
                    width: labelW,
                    child: Text(dayNames[wd], style: _axisStyle),
                  ),
                  for (var hour = 0; hour < 24; hour++)
                    Padding(
                      padding: const EdgeInsets.only(right: gap),
                      child: _HeatCell(
                        n: counts[wd * 24 + hour] ?? 0,
                        max: max,
                        width: w,
                        height: h,
                        label:
                            '${dayNames[wd]} ${hour.toString().padLeft(2, '0')}:00',
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    },
  );
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.n,
    required this.max,
    required this.label,
    required this.width,
    required this.height,
  });

  final int n;
  final int max;
  final String label;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    // 0.08 keeps an empty hour visible as a cell rather than a hole.
    final alpha = max == 0 || n == 0 ? 0.0 : 0.08 + 0.82 * (n / max);
    return Tooltip(
      message: '$label · $n',
      waitDuration: Duration.zero,
      textStyle: _tipStyle,
      decoration: AdminTokens.tip,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: alpha == 0
              ? AdminTokens.levelTint(null)
              : AdminTokens.focus.withValues(alpha: alpha),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
