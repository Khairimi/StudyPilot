import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/logic/priority_engine.dart';
import 'package:study_app/studypilot/models/models.dart';

import 'fixtures.dart';

int score(TeamTask t, [DateTime? at]) => PriorityEngine.score(t, at ?? now).score;

void main() {
  group('deadline bands (medium priority = 15, no effort/subtasks)', () {
    final cases = <String, (DateTime?, int)>{
      'overdue 2 days': (inDays(-2), 60),
      'due today': (inDays(0), 55),
      'due tomorrow': (inDays(1), 50),
      'due in 2 days': (inDays(2), 40),
      'due in 3 days': (inDays(3), 40),
      'due in 4 days': (inDays(4), 30),
      'due in 7 days': (inDays(7), 30),
      'due in 8 days': (inDays(8), 20),
      'no deadline': (null, 15),
    };
    cases.forEach((name, c) {
      test(name, () => expect(score(task('t', due: c.$1)), c.$2));
    });
  });

  test('stated priority points', () {
    expect(score(task('t', priority: SpPriority.urgent)), 35);
    expect(score(task('t', priority: SpPriority.high)), 25);
    expect(score(task('t', priority: SpPriority.medium)), 15);
    expect(score(task('t', priority: SpPriority.low)), 5);
  });

  test('effort thresholds; unestimated counts as 3h (no points)', () {
    expect(score(task('t', hours: 8)), 15 + 12);
    expect(score(task('t', hours: 5)), 15 + 8);
    expect(score(task('t', hours: 4.9)), 15);
    expect(score(task('t', hours: 0)), 15);
    expect(score(task('t', hours: -4)), 15);
  });

  test('open subtasks: +3 each, capped at 10, only for to-do/in-progress', () {
    Subtask s(String id, {bool done = false}) => Subtask(id: id, title: id, completed: done);
    expect(score(task('t', subtasks: [s('a'), s('b'), s('c', done: true)])), 15 + 6);
    expect(score(task('t', subtasks: [for (var i = 0; i < 5; i++) s('$i')])), 15 + 10);
    expect(
      score(task('t', status: SpTaskStatus.inReview, subtasks: [s('a'), s('b')])),
      15,
    );
  });

  test('completed tasks score 0; active scores clamp to 5..100', () {
    expect(score(task('t', status: SpTaskStatus.completed, due: inDays(-5))), 0);
    final maxed = task('t',
        priority: SpPriority.urgent,
        due: inDays(-1),
        hours: 10,
        subtasks: [for (var i = 0; i < 4; i++) Subtask(id: '$i', title: '$i')]);
    expect(score(maxed), 100); // raw 45+35+12+10 = 102
    expect(score(task('t', priority: SpPriority.low)), PriorityEngine.minActiveScore);
  });

  test('uses calendar days, not time of day', () {
    final lateToday = DateTime(2026, 11, 10, 23, 59);
    expect(score(task('t', due: lateToday), DateTime(2026, 11, 10, 0, 1)), 55);
    final midnightTomorrow = DateTime(2026, 11, 11);
    expect(score(task('t', due: midnightTomorrow), DateTime(2026, 11, 10, 23, 59)), 50);
  });

  test('day counting is stable across a daylight-saving change', () {
    // 8 March 2026 is a US DST switch; result must still be 2 days.
    final r = PriorityEngine.score(task('t', due: DateTime(2026, 3, 10)), DateTime(2026, 3, 8, 12));
    expect(r.reasons.first, 'Due in 2 days');
  });

  test('reasons explain every point and are deterministic', () {
    final t = task('t', priority: SpPriority.high, due: inDays(1), hours: 6);
    final a = PriorityEngine.score(t, now);
    final b = PriorityEngine.score(t, now);
    expect(a.reasons, ['Due tomorrow', 'High priority', 'Moderate effort (~6h)']);
    expect(a.factors.fold<int>(0, (s, f) => s + f.points), a.score);
    expect(b.score, a.score);
    expect(b.reasons, a.reasons);
  });

  test('rank: score desc, then earliest deadline (none last), then oldest, then id', () {
    final tasks = [
      task('none', priority: SpPriority.high), // 25
      task('later', due: inDays(5), priority: SpPriority.low), // 15+5 = 20
      task('soon', due: inDays(4), priority: SpPriority.low), // 20, earlier deadline
      task('urgent', due: inDays(0), priority: SpPriority.urgent), // 75
      task('b-old', createdAt: DateTime(2026, 1, 1)), // 15
      task('a-new', createdAt: DateTime(2026, 2, 1)), // 15
      task('done', status: SpTaskStatus.completed), // 0
    ];
    final ids = PriorityEngine.rank(tasks, now).map((t) => t.id).toList();
    expect(ids, ['urgent', 'none', 'soon', 'later', 'b-old', 'a-new', 'done']);
    expect(PriorityEngine.rank(tasks.reversed, now).map((t) => t.id), ids);
  });
}
