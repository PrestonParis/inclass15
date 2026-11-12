import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trivia_showdown_app/main.dart';

/// Drives a live round against Open Trivia DB and captures labeled evidence.
/// Run with:  flutter drive --driver=test_driver/integration_test.dart \
///              --target=integration_test/round_test.dart
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(String name) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await binding.takeScreenshot(name);
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 150; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (finder.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Timed out waiting for $finder');
  }

  List<ElevatedButton> optionButtons(WidgetTester tester) => tester
      .widgetList<ElevatedButton>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(ElevatedButton),
        ),
      )
      .toList();

  testWidgets('live five-question round', (tester) async {
    await tester.pumpWidget(const TriviaShowdownApp());
    await tester.pump();
    await shot('E1_loading');

    await waitFor(tester, find.text('Question 1 of 5'));
    await tester.pumpAndSettle();
    await shot('E2_question_loaded');

    var savedCorrect = false;
    var savedWrong = false;
    for (var i = 0; i < 5; i++) {
      await waitFor(tester, find.text('Question ${i + 1} of 5'));
      await tester.pumpAndSettle();
      final options = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(ElevatedButton),
      );
      expect(optionButtons(tester), hasLength(4));
      await tester.tap(options.first);
      await tester.pumpAndSettle();

      final correct = find.text('Correct!').evaluate().isNotEmpty;
      if (correct && !savedCorrect) {
        savedCorrect = true;
        await shot('E3_correct_green_q${i + 1}');
      } else if (!correct && !savedWrong) {
        savedWrong = true;
        await shot('E4_incorrect_red_q${i + 1}');
        // Repeat taps on other options must not change the score.
        await tester.tap(options.at(1));
        await tester.tap(options.at(2));
        await tester.pumpAndSettle();
        await shot('E5_repeat_taps_ignored_q${i + 1}');
      }

      await tester.tap(
        find.text(i < 4 ? 'Next Question →' : 'View Final Score'),
      );
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('Final Score:'), findsOneWidget);
    await shot('E6_final_score');

    await tester.tap(find.text('Simulate Score Sync'));
    await tester.pump(const Duration(milliseconds: 300));
    await shot('E7a_simulating_sync');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    await shot('E7b_simulated_sync_confirmation');

    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Play Again'));
    await tester.pump();
    await waitFor(tester, find.text('Question 1 of 5'));
    await tester.pumpAndSettle();
    await shot('E8_replay_new_round');
  });
}
