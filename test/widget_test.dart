import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trivia_showdown_app/main.dart';
import 'package:trivia_showdown_app/trivia_service.dart';

void main() {
  testWidgets(
    'one answer per question, score counts once, final score and simulation',
    (tester) async {
      final body = jsonEncode({
        'response_code': 0,
        'results': List.generate(
          5,
          (i) => {
            'question': 'Q$i',
            'correct_answer': 'Right$i',
            'incorrect_answers': ['W1', 'W2', 'W3'],
          },
        ),
      });
      final service = TriviaService(
        client: MockClient((_) async => http.Response(body, 200)),
      );

      await tester.pumpWidget(TriviaShowdownApp(service: service));
      await tester.pumpAndSettle();

      for (var i = 0; i < 5; i++) {
        expect(find.text('Question ${i + 1} of 5'), findsOneWidget);
        await tester.tap(find.text('Right$i'));
        await tester.pump();
        // Tapping again (or tapping a wrong answer) must not change the score.
        await tester.tap(find.text('Right$i'));
        await tester.tap(find.text('W1'));
        await tester.pump();
        expect(find.text('Score: ${i + 1}'), findsOneWidget);
        await tester.tap(find.byType(ElevatedButton).last);
        await tester.pumpAndSettle();
      }

      expect(find.text('Final Score: 5 / 5'), findsOneWidget);
      await tester.tap(find.text('Simulate Score Sync'));
      await tester.pump(const Duration(seconds: 2));
      expect(
        find.text('Simulated sync complete; no backend request was sent.'),
        findsOneWidget,
      );
      expect(find.textContaining('"score": 5'), findsOneWidget);
    },
  );

  testWidgets('error state shows a message and Retry recovers', (tester) async {
    var calls = 0;
    final service = TriviaService(
      client: MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('down', 503);
        return http.Response(
          jsonEncode({
            'response_code': 0,
            'results': [
              {
                'question': 'Q',
                'correct_answer': 'A',
                'incorrect_answers': ['B', 'C', 'D'],
              },
            ],
          }),
          200,
        );
      }),
    );

    await tester.pumpWidget(TriviaShowdownApp(service: service));
    await tester.pumpAndSettle();
    expect(find.text('Server error: HTTP 503.'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Question 1 of 1'), findsOneWidget);
  });
}
