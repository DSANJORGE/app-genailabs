import 'package:eme_app_package/models/topic.dart';
import 'package:eme_app_package/models/tutorial.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:genai_labs/testu/testu_live.dart';
import 'package:genai_labs/testu/testu_topics.dart';

SectionProgress _s(String id, int correct, int total) =>
    SectionProgress(id, 'S$id')
      ..correct = correct
      ..total = total;

void main() {
  test('weakest = lowest share right, ties to more wrong, null when clean', () {
    expect(TutorProgress('t', [_s('1', 2, 2), _s('2', 1, 3)], null).weakest?.id,
        '2');
    // 1/2 and 2/4 tie on share; 2/4 has more wrong.
    expect(TutorProgress('t', [_s('1', 1, 2), _s('2', 2, 4)], null).weakest?.id,
        '2');
    expect(TutorProgress('t', [_s('1', 3, 3)], null).weakest, isNull);
    expect(TutorProgress('t', const [], null).weakest, isNull);
  });

  test('topic tally: distinct questions, latest attempt wins, weakest rule', () {
    final a = _s('1', 1, 2)..latest.addAll({'1': true, '2': false});
    final b = _s('2', 0, 0);
    final topic = Topic(
      id: 't', title: 'T', description: '', thumbnail: '',
      totalTutorials: 1, completedTutorials: 0, answersForgotten: 0,
      forgottenPeriod: 0, totalSections: 2, completedSections: 0,
      progress: TutorialProgress(
          beginnerProgress: 0, competentProgress: 0, expertProgress: 0),
    );
    final p = TopicProgress(topic, 'tut', [a, b], const [], a);
    expect(p.answered, 2);
    expect(p.mastered, 1);
    expect(p.weakest?.id, '1');
  });

  test('masteryOf thresholds', () {
    expect(masteryOf(0, 0).status, '');
    expect(masteryOf(1, 3).expert, isFalse); // beginner
    expect(masteryOf(2, 3).expert, isFalse); // competent
    expect(masteryOf(9, 10).expert, isTrue);
  });
}
