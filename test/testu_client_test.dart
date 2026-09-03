import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_client.dart';
import 'package:genai_labs/testu/testu_live.dart';
import 'package:genai_labs/testu/testu_splash.dart';

void main() {
  test('the default build is the Minsur client, live', () {
    expect(client.name, 'Minsur');
    expect(client.lang, 'es');
    expect(testuLive, isTrue);
  });

  testWidgets('the launch intro spells the client wordmark in its brand colour',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: TestuSplash(onDone: () {})));
    await tester.pump(const Duration(milliseconds: 1500));
    for (final ch in client.wordmark.split('')) {
      expect(find.text(ch), findsWidgets);
    }
    final letter = tester.widget<Text>(find.text(client.wordmark[0]).first);
    expect(letter.style!.color, client.brand);
    await tester.pumpWidget(const SizedBox());
  });
}
