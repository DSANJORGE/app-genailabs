import 'package:eme_app_package/eme_http.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_live.dart';
import 'package:genai_labs/testu/testu_sully.dart';
import 'package:genai_labs/testu/testu_theme.dart';
import 'package:genai_labs/testu/testu_widgets.dart';

/// A live reply's grammar on screen: `>> ` offers as chips, the not-found
/// sentence muted and sourceless, an uncited answer labelled "No source",
/// and the fixed failure lines never labelled.
void main() {
  Widget host(Widget child) => MaterialApp(
        theme: testuTheme(),
        home: Scaffold(body: ListView(children: [child])),
      );

  testWidgets('>> offers render as chips that send their text', (tester) async {
    String? sent;
    await tester.pumpWidget(host(SullyMessage.reply(
        'El Plan fija metas [Plan, p. 13].\n>> ¿Quieres ver las metas?',
        onFollowUp: (s) => sent = s)));
    expect(find.text('Open source'), findsOneWidget);
    expect(find.text('No source'), findsNothing);
    await tester.tap(find.text('¿Quieres ver las metas?'));
    expect(sent, '¿Quieres ver las metas?');
  });

  testWidgets('without onFollowUp there are no chips', (tester) async {
    await tester.pumpWidget(host(
        SullyMessage.reply('Texto [Plan, p. 1].\n>> ¿Seguimos?')));
    expect(find.text('¿Seguimos?'), findsNothing);
  });

  testWidgets('an uncited answer says No source', (tester) async {
    await tester.pumpWidget(host(SullyMessage.reply(
        'La opción A es correcta por lo que dice la rationale.')));
    expect(find.text('No source'), findsOneWidget);
    expect(find.text('Open source'), findsNothing);
  });

  testWidgets('the not-found line is neither sourced nor labelled',
      (tester) async {
    await tester.pumpWidget(host(SullyMessage.reply(
        '$sullyNotFound\n>> ¿Repasamos lo que sí cubre?',
        onFollowUp: (_) {})));
    expect(find.text(sullyNotFound), findsOneWidget);
    expect(find.text('No source'), findsNothing);
    expect(find.text('Open source'), findsNothing);
    expect(find.text('¿Repasamos lo que sí cubre?'), findsOneWidget);
  });

  testWidgets(
      'a not-found reply keeps no source block even with a fallback title',
      (tester) async {
    await tester.pumpWidget(host(SullyMessage.reply(
        '$sullyNotFound\n>> ¿Quieres que busque en otro tema?',
        fallbackTitle: 'Plan Estratégico',
        inDoc: 'Plan Estratégico',
        onFollowUp: (_) {})));
    expect(find.text('Ver fuente'), findsNothing);
    expect(find.text('View source'), findsNothing);
    expect(find.byType(TestuSourceBlock), findsNothing);
    expect(find.byType(TestuChip), findsOneWidget);
  });

  testWidgets(
      'inside a viewer, an uncited reply shows both the fallback source and No source',
      (tester) async {
    await tester.pumpWidget(host(SullyMessage.reply('Respuesta sin cita.',
        fallbackTitle: 'Doc', inDoc: 'Doc')));
    expect(find.byType(TestuSourceBlock), findsOneWidget);
    expect(find.text('No source'), findsOneWidget);
  });

  testWidgets('a cited reply inside the same viewer shows no label',
      (tester) async {
    await tester.pumpWidget(host(SullyMessage.reply(
        'Respuesta con cita [Doc, p. 2].',
        fallbackTitle: 'Doc',
        inDoc: 'Doc')));
    expect(find.byType(TestuSourceBlock), findsOneWidget);
    expect(find.text('No source'), findsNothing);
  });

  testWidgets('a reply with three >> lines renders only two chips',
      (tester) async {
    await tester.pumpWidget(host(SullyMessage.reply(
        'Texto [Plan, p. 1].\n>> Uno\n>> Dos\n>> Tres',
        onFollowUp: (_) {})));
    expect(find.byType(TestuChip), findsNWidgets(2));
  });

  testWidgets('failure lines carry no label', (tester) async {
    for (final line in [sullySlowReply(), sullyUnavailable(), sullyOffline()]) {
      await tester.pumpWidget(host(SullyMessage.reply(line)));
      expect(find.text('No source'), findsNothing, reason: line);
    }
  });

  test('sullyFailure: transport failure is offline, anything else unavailable',
      () {
    expect(sullyFailure(EmeHttpException(uri: Uri.parse('x'))), sullyOffline());
    expect(sullyFailure(EmeHttpException(uri: Uri.parse('x'), statusCode: 500)),
        sullyUnavailable());
    expect(sullyFailure(StateError('No tutor channel')), sullyUnavailable());
  });
}
