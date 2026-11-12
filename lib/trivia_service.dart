import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'question.dart';

/// Default endpoint from the activity page. Can be overridden for testing the
/// error state with: flutter run --dart-define=TRIVIA_URL=https://example.invalid
const String triviaUrl = String.fromEnvironment(
  'TRIVIA_URL',
  defaultValue: 'https://opentdb.com/api.php?amount=5&category=9&difficulty=easy&type=multiple',
);

/// A readable error for the UI.
class TriviaException implements Exception {
  final String message;
  const TriviaException(this.message);

  @override
  String toString() => message;
}

/// Handles the network request and JSON validation so the screen only deals
/// with a list of questions or a [TriviaException].
class TriviaService {
  final http.Client _client;
  final Uri _uri;
  final Duration timeout;

  TriviaService({
    http.Client? client,
    String url = triviaUrl,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client(),
       _uri = Uri.parse(url);

  Future<List<Question>> fetchQuestions() async {
    final http.Response response;
    try {
      response = await _client.get(_uri).timeout(timeout);
    } on TimeoutException {
      throw const TriviaException(
        'The trivia server took too long to respond. Check your connection and try again.',
      );
    } catch (_) {
      throw const TriviaException(
        'Could not reach the trivia server. Check your connection and try again.',
      );
    }

    // 1. Transport level: did the HTTP request succeed?
    if (response.statusCode != 200) {
      throw TriviaException('Server error: HTTP ${response.statusCode}.');
    }

    // 2. Parse the body.
    final Object? data;
    try {
      data = json.decode(response.body);
    } on FormatException {
      throw const TriviaException(
        'The server sent a response that was not valid JSON.',
      );
    }
    if (data is! Map<String, dynamic>) {
      throw const TriviaException(
        'The server response had an unexpected shape.',
      );
    }

    // 3. API level: did Open Trivia DB actually return questions?
    final code = data['response_code'];
    if (code != 0) {
      throw TriviaException(_apiCodeMessage(code));
    }

    final results = data['results'];
    if (results is! List || results.isEmpty) {
      throw const TriviaException(
        'No trivia questions were returned. Please try again.',
      );
    }

    try {
      return results
          .map((item) => Question.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      throw const TriviaException(
        'Some question data was incomplete, so the round was not started.',
      );
    }
  }

  static String _apiCodeMessage(Object? code) {
    switch (code) {
      case 1:
        return 'Trivia API code 1: not enough questions for this request.';
      case 2:
        return 'Trivia API code 2: the request had an invalid parameter.';
      case 5:
        return 'Trivia API code 5: too many requests. Wait about 5 seconds and try again.';
      default:
        return 'Trivia API returned response code $code. Please try again.';
    }
  }
}
