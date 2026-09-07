import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsAction, SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/admin/admin_charts.dart';
import 'package:genai_labs/admin/admin_models.dart';
import 'package:genai_labs/admin/admin_nav.dart';
import 'package:genai_labs/admin/admin_theme.dart';
import 'package:genai_labs/admin/admin_ui.dart';
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
        ConsoleIconButton(glyph: '✕', label: 'Close', onTap: () {}),
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
}
