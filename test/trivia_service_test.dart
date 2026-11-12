import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trivia_showdown_app/trivia_service.dart';

Map<String, dynamic> sampleQuestion(int i) => {
  'question': 'Question $i',
  'correct_answer': 'Right $i',
  'incorrect_answers': ['A', 'B', 'C'],
};

TriviaService serviceReturning(int status, String body) =>
    TriviaService(client: MockClient((_) async => http.Response(body, status)));

Matcher throwsTrivia(String text) => throwsA(
  isA<TriviaException>().having((e) => e.message, 'message', contains(text)),
);

void main() {
  test('requests the activity endpoint and returns five questions', () async {
    late Uri requested;
    final service = TriviaService(
      client: MockClient((req) async {
        requested = req.url;
        return http.Response(
          jsonEncode({
            'response_code': 0,
            'results': List.generate(5, sampleQuestion),
          }),
          200,
        );
      }),
    );

    final questions = await service.fetchQuestions();
    expect(questions, hasLength(5));
    expect(requested.queryParameters, {
      'amount': '5',
      'category': '9',
      'difficulty': 'easy',
      'type': 'multiple',
    });
  });

  test('non-200 HTTP status is an error', () {
    expect(
      serviceReturning(500, 'oops').fetchQuestions(),
      throwsTrivia('HTTP 500'),
    );
  });

  test('HTTP 200 with a non-zero response_code is still an error', () {
    final body = jsonEncode({'response_code': 5, 'results': []});
    expect(
      serviceReturning(200, body).fetchQuestions(),
      throwsTrivia('too many requests'),
    );
  });

  test('empty results are an error', () {
    final body = jsonEncode({'response_code': 0, 'results': []});
    expect(
      serviceReturning(200, body).fetchQuestions(),
      throwsTrivia('No trivia questions'),
    );
  });

  test('malformed JSON is an error', () {
    expect(
      serviceReturning(200, '<html>').fetchQuestions(),
      throwsTrivia('not valid JSON'),
    );
  });

  test('network failure is an error', () {
    final service = TriviaService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    expect(service.fetchQuestions(), throwsTrivia('Could not reach'));
  });
}
