import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:trivia_showdown_app/question.dart';

void main() {
  test('decodes the entities the API commonly returns', () {
    expect(
      decodeEntities('&quot;Hi&quot; it&#039;s R&amp;D'),
      '"Hi" it\'s R&D',
    );
    expect(
      decodeEntities('Beyonc&eacute; &ldquo;Halo&rdquo;'),
      'Beyoncé “Halo”',
    );
    expect(decodeEntities('plain text'), 'plain text');
  });

  test('fromJson maps fields, cleans text and keeps all four options', () {
    final q = Question.fromJson({
      'question': 'Who wrote &quot;Hamlet&quot;?',
      'correct_answer': 'Shakespeare',
      'incorrect_answers': ['Dickens', 'Austen', 'O&#039;Brien'],
    }, random: Random(1));

    expect(q.questionText, 'Who wrote "Hamlet"?');
    expect(q.correctAnswer, 'Shakespeare');
    expect(q.options, hasLength(4));
    expect(
      q.options,
      containsAll(['Shakespeare', 'Dickens', 'Austen', "O'Brien"]),
    );
  });

  test('fromJson rejects a record with missing fields', () {
    expect(() => Question.fromJson({'question': 'x'}), throwsFormatException);
  });
}
