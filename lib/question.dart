import 'dart:math';

import 'package:html/parser.dart' as html_parser;

/// Turns HTML entities from the API (&quot;, &#039;, &amp;, &eacute;, ...)
/// into the characters they stand for.
String decodeEntities(String value) {
  if (!value.contains('&')) return value;
  return html_parser.parseFragment(value).text ?? value;
}

class Question {
  final String questionText;
  final String correctAnswer;
  final List<String> options;

  Question({
    required this.questionText,
    required this.correctAnswer,
    required this.options,
  });

  /// Maps one item from the API's `results` list into a Question.
  /// Throws a [FormatException] if a required field is missing or the wrong type.
  factory Question.fromJson(Map<String, dynamic> json, {Random? random}) {
    final question = json['question'];
    final correct = json['correct_answer'];
    final incorrect = json['incorrect_answers'];
    if (question is! String || correct is! String || incorrect is! List) {
      throw const FormatException('A question was missing required fields.');
    }

    final cleanCorrect = decodeEntities(correct);
    final options = [
      ...incorrect.map((answer) => decodeEntities(answer.toString())),
      cleanCorrect,
    ]..shuffle(random);

    return Question(
      questionText: decodeEntities(question),
      correctAnswer: cleanCorrect,
      options: options,
    );
  }
}
