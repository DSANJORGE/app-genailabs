import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_charts.dart';
import 'package:genai_labs/admin/admin_heatmap.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_theme.dart';
import 'package:genai_labs/admin/admin_ui.dart';
import 'package:genai_labs/testu/testu_icons.dart';
import 'package:genai_labs/testu/testu_theme.dart';

Widget _app(Widget child) => MaterialApp(
      theme: testuTheme(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('AdminTable sorts numerically when a numeric header is tapped',
      (tester) async {
    const rows = [('b', 2), ('a', 10)];
    await tester.pumpWidget(_app(AdminTable<(String, int)>(
      columns: [
        AdminColumn('Name', (r) => Text(r.$1), sortKey: (r) => r.$1),
        AdminColumn('Count', (r) => Text('${r.$2}'),
            sortKey: (r) => r.$2, numeric: true),
      ],
      rows: rows,
    )));

    double y(String s) => tester.getTopLeft(find.text(s)).dy;
    expect(y('2') < y('10'), isTrue, reason: 'unsorted keeps the given order');

    await tester.tap(find.text('Count'));
    await tester.pumpAndSettle();

    expect(y('10') < y('2'), isTrue,
        reason: '10 must sort above 2 numerically, not lexicographically');
  });

  testWidgets('LevelBar sizes each segment by its count', (tester) async {
    await tester.pumpWidget(_app(const LevelBar(
      {'beginner': 1, 'competent': 1, 'expert': 2},
    )));

    Expanded seg(String level) =>
        tester.widget<Expanded>(find.byKey(ValueKey('level.$level')));
    expect(seg('expert').flex, 2);
    expect(seg('competent').flex, 1);
    expect(seg('beginner').flex, 1);
  });

  testWidgets('Segmented reports the tapped value', (tester) async {
    String? got;
    await tester.pumpWidget(_app(Segmented<String>(
      value: 'a',
      items: const [('a', 'A'), ('b', 'B')],
      onChanged: (v) => got = v,
    )));

    await tester.tap(find.text('B'));
    await tester.pump();
    expect(got, 'b');
  });

  testWidgets('showToast shows the text and removes it after 4 s',
      (tester) async {
    await tester.pumpWidget(_app(Builder(
      builder: (c) => GestureDetector(
        onTap: () => showToast(c, 'Exportado'),
        child: const Text('go'),
      ),
    )));

    await tester.tap(find.text('go'));
    await tester.pump();
    expect(find.text('Exportado'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(find.text('Exportado'), findsNothing);
  });

  testWidgets('AdminScaffold lays out nav, title and every component',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final nav = ConsoleNav();
    addTearDown(nav.dispose);
    final filters = AnalyticsFilters();
    addTearDown(filters.dispose);
    final series = [
      for (var i = 0; i < 7; i++)
        DayPoint(DateTime(2026, 9, 1 + i),
            people: 3 + i, answers: 20 + i * 4, minutes: 12 + i),
    ];

    await tester.pumpWidget(MaterialApp(
      theme: testuTheme(),
      home: AdminScaffold(
        org: 'Minsur',
        me: AdminMe('l1', 'l@minsur.test', 'Lider Norte', 'manager',
            const {'analytics_view'}, const []),
        sections: const [('resumen', 'Resumen'), ('actividad', 'Actividad')],
        nav: nav,
        title: 'Resumen',
        onSignOut: () {},
        contextBar: ContextBar(
          filters: filters,
          topics: const {'seguridad': 'Seguridad'},
          teams: [AdminTeam(id: 'norte', name: 'Norte')],
        ),
        endPanel: const Padding(
          padding: EdgeInsets.all(16),
          child: Skeleton(lines: 2),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Reading(
              personaName: 'Iris',
              sentences: ['Cuatro personas necesitan apoyo esta semana.'],
            ),
            const SizedBox(height: 20),
            StatRow(const [
              StatBlock(
                label: 'Activos',
                value: '12',
                delta: '+3 que la semana pasada',
                deltaPositive: true,
                spark: [1, 3, 2, 5, 4, 6, 7],
              ),
              StatBlock(label: 'Respuestas', value: '240', highlight: true),
            ]),
            const SizedBox(height: 20),
            ChartCard(
              eyebrow: 'Actividad',
              legend: [
                (AdminTokens.focus, 'Personas'),
                (AdminTokens.compare, 'Periodo anterior'),
              ],
              footnote: 'Personas activas por día.',
              child: activityChart(
                series: series,
                previous: series,
                peopleLabel: 'personas',
                answersLabel: 'respuestas',
              ),
            ),
            const SizedBox(height: 20),
            ChartCard(
              eyebrow: 'Minutos',
              child: dailyBars(series, value: (d) => d.minutes),
            ),
            const SizedBox(height: 20),
            ChartCard(
              eyebrow: 'Aciertos',
              child: correctIncorrectBars(const [
                (label: 'L', correct: 8, incorrect: 2),
                (label: 'M', correct: 6, incorrect: 4),
              ]),
            ),
            const SizedBox(height: 20),
            ChartCard(
              eyebrow: 'Horas',
              height: 160,
              child: hoursHeatmap(const [(1, 9, 4), (3, 15, 9)]),
            ),
            const SizedBox(height: 20),
            const Quad(cc: 14, cu: 4, ic: 3, iu: 1),
            const SizedBox(height: 20),
            const Funnel([('Invitados', 40), ('Activos', 12)]),
            const SizedBox(height: 20),
            const LevelLegend(),
            const SizedBox(height: 20),
            Pulse(active: true, child: crossfade(const Text('contenido'))),
            const SizedBox(height: 20),
            const EmptyState(
              eyebrow: 'Sin datos',
              text: 'Nadie ha respondido todavía.',
            ),
            const SizedBox(height: 20),
            ConsolePanelError(text: 'No se pudo cargar.', onRetry: () {}),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Minsur'), findsOneWidget);
    expect(find.text('Resumen'), findsNWidgets(2)); // nav item + page title
    expect(find.text('Sign out'), findsOneWidget); // flutter_test_config pins EN
    expect(find.text('contenido'), findsOneWidget);

    // The nav routes without a screen around it.
    await tester.tap(find.text('Actividad'));
    await tester.pumpAndSettle();
    expect(nav.value.section, 'actividad');
  });

  testWidgets('activityChart aligns its line to its bars and draws from zero',
      (tester) async {
    final series = [
      for (var i = 0; i < 7; i++)
        DayPoint(DateTime(2026, 9, 1 + i), people: 3 + i, answers: 20 + i),
    ];
    await tester.pumpWidget(_app(SizedBox(
      height: 220,
      child: activityChart(
        series: series,
        peopleLabel: 'personas',
        answersLabel: 'respuestas',
      ),
    )));

    LineChart line() => tester.widget<LineChart>(find.byType(LineChart));

    // BarChartAlignment.spaceAround centres group i at (i + 0.5) / n, so the
    // line has to carry half a slot of padding at each end or day i's point
    // sits off day i's bar.
    expect(line().data.minX, -0.5);
    expect(line().data.maxX, 6.5);

    // fl_chart tweens on data change, not on mount: the first frame has to be
    // the flat baseline, or the 300 ms draw never runs.
    expect(line().data.lineBarsData.last.spots.map((s) => s.y),
        everyElement(0.0));

    await tester.pump();
    expect(line().data.lineBarsData.last.spots.first.y, 3.0);
    expect(line().duration, const Duration(milliseconds: 300));

    await tester.pumpAndSettle();
    expect(line().duration, Duration.zero);
  });

  // Reduced motion means less movement, not less feedback: with no fade to
  // carry it, the ring has to stand still long enough to be noticed instead
  // of blinking out on the next frame.
  testWidgets('with animations off the pulse ring is held, not flashed',
      (tester) async {
    Color ring() {
      final d = tester
          .widget<AnimatedContainer>(find
              .descendant(
                  of: find.byType(Pulse),
                  matching: find.byType(AnimatedContainer))
              .first)
          .decoration as BoxDecoration;
      return d.border!.top.color;
    }

    await tester.pumpWidget(_app(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: const Pulse(active: true, child: SizedBox(width: 40, height: 40)),
    )));

    await tester.pump();
    expect(ring(), AdminTokens.focus);

    await tester.pump(const Duration(milliseconds: 1600));
    expect(ring(), Colors.transparent);
  });


  // Assistive technology presses ONE node per control. A GestureDetector or a
  // visible label left in the tree under the labelled node gives a screen
  // reader a second, differently-named thing to press for the same control.
  testWidgets('every console control is exactly one semantics node',
      (tester) async {
    int tapNodes(SemanticsNode node) {
      var n = node.getSemanticsData().hasAction(SemanticsAction.tap) ? 1 : 0;
      node.visitChildren((child) {
        n += tapNodes(child);
        return true;
      });
      return n;
    }

    final handle = tester.ensureSemantics();
    for (final (widget, name) in <(Widget, String)>[
      (
        ConsoleIconButton(
            glyph: TestuGlyph.close, label: 'Close', onTap: () {}),
        'Close',
      ),
      (
        CitationChip(
          index: 1,
          citation:
              Citation('f1', 'Sin actividad: Jorge', 'x', 'person', const {}),
          onTap: () {},
        ),
        '1 · Sin actividad: Jorge',
      ),
      (ConsoleChip('Compare the teams', onTap: () {}), 'Compare the teams'),
      // A control that carries no semanticLabel of its own: its visible text
      // IS its name, and it has to end up on the node that answers the tap
      // rather than on a sibling underneath it.
      (
        Segmented<String>(
          value: 'a',
          items: const [('a', 'Piloto')],
          onChanged: (_) {},
        ),
        'Piloto',
      ),
    ]) {
      await tester.pumpWidget(_app(Center(child: widget)));
      await tester.pump();
      final node = tester.getSemantics(find.bySemanticsLabel(name));
      expect(node.label, name);
      expect(tapNodes(node), 1,
          reason: '${widget.runtimeType} announces more than one thing to tap');
    }
    handle.dispose();
  });

  // A row is one control made of several cells: the node that answers the
  // tap has to carry the row's own words, or a screen reader announces a
  // nameless button and the name arrives as a separate, unpressable thing.
  testWidgets('a control with no semanticLabel is named by its own text',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(AdminTable<(String, String)>(
      columns: [
        AdminColumn('Name', (r) => Text(r.$1)),
        AdminColumn('Team', (r) => Text(r.$2)),
      ],
      rows: const [('Ana Quispe', 'Norte')],
      onTap: (_) {},
    )));
    await tester.pump();

    final node = tester.getSemantics(find.text('Ana Quispe'));
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
        reason: 'the named node is the one that opens the row');
    expect(node.label, contains('Ana Quispe'));
    handle.dispose();
  });

  // ...and a control that lives inside a row stays its own, separately
  // pressable node -- Colaboradores puts a Select in two of its cells -- and
  // it announces what it DOES. The hint is a placeholder ("Ninguno"), which
  // is what a row with no team would otherwise have been called.
  testWidgets('a control inside a row is its own node, named by its job',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(AdminTable<String>(
      columns: [
        AdminColumn('Name', (r) => Text(r)),
        AdminColumn(
          'Team',
          (r) => Select<String>(
            // A value IS set: the name must still be the control's job, not
            // the placeholder and not the value.
            value: 'norte',
            hint: 'None',
            semanticLabel: 'Change team',
            items: const [('norte', 'Norte')],
            onChanged: (_) {},
          ),
        ),
      ],
      rows: const ['Ana Quispe'],
      onTap: (_) {},
    )));
    await tester.pump();

    // The node's name is the label plus the value it is showing, so match on
    // the label rather than on the whole string.
    final select =
        tester.getSemantics(find.bySemanticsLabel(RegExp('Change team')));
    expect(select.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    expect(select.label, contains('Change team'));
    expect(select.label, isNot(contains('None')));
    handle.dispose();
  });

  // A ColoredBox with no child takes the SMALLEST size its constraints allow.
  // Inside a Row with the default (centred) cross axis that is 0 px high, so
  // every stacked bar in the console -- the heatmap's summary strip and team
  // rows, the Niveles column of four tables, the theme split -- laid out at
  // full width and painted nothing at all.
  testWidgets('LevelBar paints its segments at the bar height', (tester) async {
    await tester.pumpWidget(_app(const SizedBox(
      width: 120,
      child: LevelBar({'beginner': 1, 'competent': 3}),
    )));

    final segments = find.descendant(
        of: find.byType(LevelBar), matching: find.byType(ColoredBox));
    expect(segments, findsNWidgets(2));
    for (final e in segments.evaluate()) {
      final box = e.renderObject! as RenderBox;
      expect(box.size.height, 6, reason: 'a 0 px segment paints nothing');
      expect(box.size.width, greaterThan(0));
    }
  });

  testWidgets('StackedBar paints its segments at the bar height',
      (tester) async {
    await tester.pumpWidget(_app(SizedBox(
      width: 120,
      child: StackedBar([
        (AdminTokens.focus, 'Concepto', 4),
        (AdminTokens.compare, 'Fuente', 2),
      ]),
    )));

    final segments = find.descendant(
        of: find.byType(StackedBar), matching: find.byType(ColoredBox));
    expect(segments, findsNWidgets(2));
    for (final e in segments.evaluate()) {
      expect((e.renderObject! as RenderBox).size.height, 10);
    }
  });

  // Spanish wraps "MINUTOS EN LA APP" at 1024 and leaves "ACTIVOS 7 D" on one
  // line: without a reserved label box the two numbers below them sit half a
  // line apart, and the stat row stops being a row.
  testWidgets('a stat label that wraps still leaves the numbers in line',
      (tester) async {
    await tester.pumpWidget(_app(const SizedBox(
      width: 360,
      child: StatRow([
        StatBlock(label: 'Activos 7 d', value: '12'),
        StatBlock(label: 'Minutos en la aplicación', value: '1 764'),
      ]),
    )));

    expect(tester.getTopLeft(find.text('12')).dy,
        tester.getTopLeft(find.text('1 764')).dy);
  });

  testWidgets('an ellipsised header keeps its words in a tooltip',
      (tester) async {
    await tester.pumpWidget(_app(SizedBox(
      width: 200,
      child: AdminTable<int>(
        columns: [
          AdminColumn('Última actividad', (r) => Text('$r'), width: 60),
          AdminColumn('Nombre', (r) => Text('n$r')),
        ],
        rows: const [1],
      ),
    )));

    // The cell shows "Última acti…"; the words themselves have to exist
    // somewhere on the screen.
    expect(find.byTooltip('Última actividad'), findsOneWidget);
  });

  testWidgets('a screen that ignores the period is not offered one',
      (tester) async {
    final filters = AnalyticsFilters();
    addTearDown(filters.dispose);

    Widget bar({required bool period}) => _app(ContextBar(
          filters: filters,
          topics: const {},
          teams: const [],
          period: period,
        ));

    await tester.pumpWidget(bar(period: true));
    expect(find.byType(Segmented<Period>), findsOneWidget);

    await tester.pumpWidget(bar(period: false));
    await tester.pumpAndSettle();
    expect(find.byType(Segmented<Period>), findsNothing);
    expect(find.text('7 d'), findsNothing);
    // The filters it DOES read are still there.
    expect(find.text('All topics'), findsOneWidget);
    expect(find.text('All teams'), findsOneWidget);
  });


  // With the Iris panel open at 1280 the content column is 652 px, and the
  // Equipos table's flexed name column was squeezed to 9 px: a table with no
  // team names in it.
  testWidgets('a table too narrow for its columns scrolls, not collapses',
      (tester) async {
    await tester.pumpWidget(_app(SizedBox(
      width: 300,
      child: AdminTable<int>(
        columns: [
          AdminColumn('Nombre', (r) => Text('a$r')),
          AdminColumn('Equipo', (r) => Text('b$r')),
          AdminColumn('Niveles', (r) => Text('c$r'), width: 150),
        ],
        rows: const [1],
      ),
    )));

    // 96 + 96 + 150, each with its 12 px gutter: the third column starts
    // beyond the box instead of everything sharing 138 px.
    expect(tester.getTopLeft(find.text('Niveles')).dx, greaterThan(200));

    // And it scrolls, with a thumb that says so.
    expect(find.byType(Scrollbar), findsOneWidget);
    await tester.drag(find.text('Nombre'), const Offset(-80, 0));
    await tester.pumpAndSettle();
    // The horizontal one: the body has its own vertical scroller under the
    // pinned header.
    final scroller = tester.widget<SingleChildScrollView>(
        find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal));
    expect(scroller.controller!.offset, greaterThan(0));
    expect(tester.getTopLeft(find.text('Niveles')).dx, lessThan(200),
        reason: 'the last column comes into view');
  });

  testWidgets('a column header drags wider, and double-click hands it back',
      (tester) async {
    await tester.pumpWidget(_app(SizedBox(
      width: 600,
      child: AdminTable<int>(
        columns: [
          AdminColumn('Nombre', (r) => Text('a$r')),
          AdminColumn('Equipo', (r) => Text('b$r')),
        ],
        rows: const [1],
      ),
    )));
    final before = tester.getTopLeft(find.text('Equipo')).dx;
    // The handle lives in the first column's 12 px right gutter.
    final handle = Offset(before - 6, 16);
    await tester.dragFrom(handle, const Offset(80, 0));
    await tester.pumpAndSettle();
    // 80 minus the gesture's own touch slop.
    final after = tester.getTopLeft(find.text('Equipo')).dx;
    expect(after, greaterThan(before + 50));
    expect(tester.getTopLeft(find.text('b1')).dx, closeTo(after, 1),
        reason: 'the body follows the header');

    // The handle moved with the column: it sits in the gutter left of the
    // second header wherever that now is.
    await tester.tapAt(Offset(after - 6, 16));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(Offset(after - 6, 16));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Equipo')).dx, closeTo(before, 1));
  });

  // The heatmap's own copy of this primitive painted its focus ring on hover
  // as well; the shared one does not, and the pinned name column now uses it.
  testWidgets('a heatmap row label hovers like every other console control',
      (tester) async {
    await tester.pumpWidget(_app(HeatmapGrid(
      cols: const [HeatCol('Tema', 'Uno')],
      rowHeader: 'Persona',
      onRow: (_) {},
      rows: const [
        HeatRow(id: 'u:1', label: 'Ana Quispe', cells: [
          HeatCell(title: 'Ana · Uno', level: 'beginner', mastered: 1, answered: 4),
        ]),
      ],
    )));

    BoxDecoration? labelBox() {
      final boxes = find.ancestor(
          of: find.text('Ana Quispe'), matching: find.byType(DecoratedBox));
      if (boxes.evaluate().isEmpty) return null;
      return tester.widget<DecoratedBox>(boxes.first).decoration
          as BoxDecoration;
    }

    expect(labelBox()?.color, isNull, reason: 'nothing painted at rest');

    // What a mouse-driven desktop session sets on the first pointer move.
    // `FocusableActionDetector.onShowHoverHighlight` is gated on it, which is
    // why the heatmap's own copy of this primitive used a bare MouseRegion.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Ana Quispe')));
    await tester.pumpAndSettle();

    expect(labelBox()?.color, AdminTokens.hover);
    expect(labelBox()?.border, isNull,
        reason: 'the ring belongs to keyboard focus, not to the mouse');
  });


  // The tooltip appears exactly when the label stops fitting, and "exactly"
  // is one constant: _selectChrome, the padding + gap + caret a Select spends
  // on everything that is not its label. Sized at the boundary, so a drift in
  // any of the three flips one of these two.
  testWidgets('the Select tooltip turns on where the label stops fitting',
      (tester) async {
    const label = 'Operaciones Pisco';

    // Measured the way the control measures it: the resolved style, inside
    // the same theme. A bare TextSpan misses what DefaultTextStyle adds.
    late double labelW;
    await tester.pumpWidget(_app(Builder(builder: (context) {
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: DefaultTextStyle.of(context).style.merge(
              const TextStyle(fontFamily: 'Geist', fontSize: 11.5)),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      labelW = painter.width;
      painter.dispose();
      return const SizedBox.shrink();
    })));

    Future<void> pumpAt(double width) async {
      await tester.pumpWidget(_app(Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: Select<String>(
            value: 'a',
            items: const [('a', label)],
            onChanged: (_) {},
          ),
        ),
      )));
      await tester.pumpAndSettle();
    }

    // 46 px of chrome plus the label, and two pixels of room: it fits.
    await pumpAt(labelW + 48);
    expect(find.byTooltip(label), findsNothing);

    // Two pixels short of it: it does not.
    await pumpAt(labelW + 44);
    expect(find.byTooltip(label), findsOneWidget);
  });


  // Material's Tooltip hangs off the centre of its child: for a bar row that
  // is mid-card, 400 px from the label the reader is on. The console's sits
  // beside the pointer.
  testWidgets('a console tooltip opens beside the pointer, not under the widget',
      (tester) async {
    await tester.pumpWidget(_app(const SizedBox(
      width: 600,
      child: BarRow(label: 'Aplicación práctica', value: 5, max: 5),
    )));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    final at = tester.getTopLeft(find.byType(BarRow)) + const Offset(30, 10);
    await mouse.moveTo(at);
    await tester.pumpAndSettle();

    final tip = find.text('Aplicación práctica · 5');
    expect(tip, findsOneWidget, reason: 'the whole label and the count');
    final box = tester.getTopLeft(
        find.ancestor(of: tip, matching: find.byType(Container)).first);
    expect(box.dx, closeTo(at.dx + 14, 1));
    expect(box.dy, closeTo(at.dy + 18, 1));
  });

  // The same handle as AdminTable, inside the grid's horizontal scroller --
  // the drag has to beat the scroll view for the pointer.
  testWidgets('a heatmap column drags wider, and its cells follow',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(SizedBox(
      width: 700,
      child: HeatmapGrid(
        cols: const [HeatCol('Tema', 'Uno'), HeatCol('Tema', 'Dos')],
        rowHeader: 'Persona',
        onRow: (_) {},
        rows: const [
          HeatRow(id: 'u:1', label: 'Ana Quispe', cells: [
            HeatCell(title: 'Ana · Uno', level: 'beginner', mastered: 1, answered: 4),
            HeatCell(title: 'Ana · Dos', level: 'expert', mastered: 4, answered: 4),
          ]),
        ],
      ),
    )));
    final before = tester.getTopLeft(find.text('Dos')).dx;
    // 4 px gap, then the middle of the 8 px handle at the cell's right edge.
    final grip = Offset(before - 8, tester.getCenter(find.text('Uno')).dy);
    await tester.dragFrom(grip, const Offset(80, 0));
    await tester.pumpAndSettle();

    final after = tester.getTopLeft(find.text('Dos')).dx;
    expect(after, greaterThan(before + 50));
    final cell = tester.getSize(find.bySemanticsLabel(RegExp(r'Ana · Uno')));
    expect(cell.width, closeTo(after - 4 - tester.getTopLeft(find.text('Uno')).dx, 1),
        reason: 'the body column is the header column');
    handle.dispose();
  });
}
