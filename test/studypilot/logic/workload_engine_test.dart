import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/logic/workload_engine.dart';
import 'package:study_app/studypilot/models/models.dart';

import 'fixtures.dart';

List<WorkloadConflict> detect(List<TeamTask> tasks, {Workspace? ws, double? threshold}) =>
    WorkloadEngine.detectConflicts(ws ?? workspace(), tasks, now, thresholdHours: threshold);

void main() {
  test('no conflicts for a balanced team', () {
    expect(
      detect([
        task('1', assignee: 'ana', due: inDays(1), hours: 4),
        task('2', assignee: 'ben', due: inDays(2), hours: 4),
        task('3', assignee: 'cai', due: inDays(5), hours: 4),
      ]),
      isEmpty,
    );
  });

  group('deadline congestion', () {
    test('3 tasks due within 2 days → high, with suggestion', () {
      final c = detect([
        task('a1', assignee: 'ana', due: inDays(0), hours: 2, priority: SpPriority.urgent),
        task('a2', assignee: 'ana', due: inDays(1), hours: 2, priority: SpPriority.high),
        task('a3', assignee: 'ana', due: inDays(2), hours: 2, priority: SpPriority.low),
        task('b1', assignee: 'ben', hours: 6),
      ]);
      expect(c, hasLength(1));
      expect(c.single.type, ConflictType.deadlineCongestion);
      expect(c.single.severity, SpSeverity.high);
      expect(c.single.memberId, 'ana');
      expect(c.single.taskIds, ['a1', 'a2', 'a3']);
      expect(c.single.dueSoonCount, 3);
      // Lowest-priority conflicting task → least-loaded other member (cai, 0h).
      expect(c.single.suggestedTaskId, 'a3');
      expect(c.single.suggestedAssigneeId, 'cai');
      expect(c.single.reasons.last, contains('owner approval'));
    });

    test('2 tasks due soon is not congestion; overdue tasks count', () {
      expect(detect([
        task('a1', assignee: 'ana', due: inDays(0)),
        task('a2', assignee: 'ana', due: inDays(1)),
        task('a3', assignee: 'ana', due: inDays(3)),
      ]), isEmpty);
      final c = detect([
        task('a1', assignee: 'ana', due: inDays(-3)),
        task('a2', assignee: 'ana', due: inDays(-1)),
        task('a3', assignee: 'ana', due: inDays(2)),
      ]);
      expect(c.single.type, ConflictType.deadlineCongestion);
    });
  });

  group('capacity overload', () {
    test('>= threshold → medium; >= 1.5x → high', () {
      final medium = detect([
        task('a1', assignee: 'ana', hours: 8, due: inDays(10)),
        task('a2', assignee: 'ana', hours: 7, due: inDays(12)),
      ]);
      expect(medium.single.type, ConflictType.capacityOverload);
      expect(medium.single.severity, SpSeverity.medium);
      expect(medium.single.assignedHours, 15);

      final high = detect([
        task('a1', assignee: 'ana', hours: 12),
        task('a2', assignee: 'ana', hours: 11),
      ]);
      expect(high.single.severity, SpSeverity.high);
    });

    test('just under threshold is fine; custom threshold respected', () {
      expect(detect([task('a1', assignee: 'ana', hours: 14.5)]), isEmpty);
      expect(detect([task('a1', assignee: 'ana', hours: 10)], threshold: 10), hasLength(1));
      expect(detect([task('a1', assignee: 'ana', hours: 10)], ws: workspace(threshold: 10)), hasLength(1));
    });

    test('congestion takes precedence and overload is added as a reason', () {
      final c = detect([
        task('a1', assignee: 'ana', due: inDays(0), hours: 6),
        task('a2', assignee: 'ana', due: inDays(1), hours: 6),
        task('a3', assignee: 'ana', due: inDays(2), hours: 6),
      ]);
      expect(c.single.type, ConflictType.deadlineCongestion);
      expect(c.single.reasons, hasLength(3));
      expect(c.single.reasons[1], contains('threshold: 15h'));
    });
  });

  group('reassignment suggestions', () {
    test('never pushes a teammate over the threshold', () {
      final c = detect([
        task('a1', assignee: 'ana', hours: 10),
        task('a2', assignee: 'ana', hours: 8),
        task('b1', assignee: 'ben', hours: 10),
        task('c1', assignee: 'cai', hours: 12),
      ]);
      // Moving 8h or 10h would put ben (10h) or cai (12h) at/over 15h.
      expect(c.single.hasSuggestion, isFalse);
      expect(c.single.reasons.last, contains('No teammate has spare capacity'));
    });

    test('congested teammates are not suggested', () {
      final c = detect([
        for (var i = 0; i < 3; i++) task('a$i', assignee: 'ana', due: inDays(i)),
        for (var i = 0; i < 3; i++) task('b$i', assignee: 'ben', due: inDays(i)),
      ], ws: workspace(members: ['ana', 'ben']));
      expect(c, hasLength(2));
      expect(c.every((x) => !x.hasSuggestion), isTrue);
    });

    test('single-member workspace gets no suggestion', () {
      final c = detect([task('a1', assignee: 'ana', hours: 20)], ws: workspace(members: ['ana']));
      expect(c.single.hasSuggestion, isFalse);
    });
  });

  test('ignores completed, unassigned, other-workspace and non-member tasks', () {
    final c = detect([
      task('done', assignee: 'ana', hours: 20, status: SpTaskStatus.completed),
      task('free', hours: 20),
      task('other', assignee: 'ana', hours: 20, workspaceId: 'ws2'),
      task('gone', assignee: 'former-member', hours: 20),
    ]);
    expect(c, isEmpty);
  });

  test('member workloads report hours and ratio', () {
    final w = WorkloadEngine.memberWorkloads(workspace(), [
      task('a1', assignee: 'ana', hours: 6),
      task('a2', assignee: 'ana'), // unestimated → 3h
    ], now);
    expect(w.map((m) => m.userId), ['ana', 'ben', 'cai']);
    expect(w.first.activeHours, 9);
    expect(w.first.loadRatio, closeTo(0.6, 1e-9));
    expect(w[1].activeHours, 0);
  });

  test('deterministic: same output for shuffled input, sorted by severity', () {
    final tasks = [
      task('a1', assignee: 'ana', hours: 16),
      for (var i = 0; i < 3; i++) task('c$i', assignee: 'cai', due: inDays(i)),
    ];
    final first = detect(tasks);
    final second = detect(tasks.reversed.toList());
    expect(first.map((c) => c.id), ['deadlineCongestion-cai', 'capacityOverload-ana']);
    expect(second.map((c) => c.id), first.map((c) => c.id));
    expect(second.map((c) => c.suggestedTaskId), first.map((c) => c.suggestedTaskId));
  });
}
