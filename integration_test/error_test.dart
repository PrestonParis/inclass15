import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:trivia_showdown_app/main.dart';

/// Run with --dart-define=TRIVIA_URL=https://opentdb.invalid/api.php to point
/// the app at a host that does not exist and capture the error state.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('unreachable server shows an error with Retry', (tester) async {
    await tester.pumpWidget(const TriviaShowdownApp());
    for (var i = 0; i < 150 && find.text('Retry').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Retry'), findsOneWidget);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await binding.takeScreenshot('E9_error_state_retry');
  });
}
