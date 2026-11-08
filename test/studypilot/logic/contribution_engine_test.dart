import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/logic/contribution_engine.dart';
import 'package:study_app/studypilot/models/models.dart';

import 'fixtures.dart';

TeamTask done(String id, String who, {double hours = 3, DateTime? due, DateTime? at, String project = 'p1'}) =>
    task(id,
        assignee: who,
        hours: hours,
        due: due,
        projectId: project,
        status: SpTaskStatus.completed,
        completedAt: at);

Map<String, MemberContribution> calc(List<TeamTask> tasks, {Workspace? ws, String? projectId}) => {
      for (final c in ContributionEngine.calculate(ws ?? workspace(), tasks, projectId: projectId))
        c.userId: c,
    };

void main() {
  test('nothing completed → everyone 0%, on-time rate unknown', () {
    final r = calc([task('a', assignee: 'ana')]);
    expect(r.values.map((c) => c.contributionPercent), [0, 0, 0]);
    expect(r['ana']!.activeCount, 1);
    expect(r['ana']!.onTimeRate, isNull);
  });

  test('50% task-count share + 50% hours share', () {
    final r = calc([
      done('a1', 'ana', hours: 9),
      done('b1', 'ben', hours: 1),
      done('b2', 'ben', hours: 1),
      done('b3', 'ben', hours: 1),
    ], ws: workspace(members: ['ana', 'ben']));
    // ana: 0.5*(1/4) + 0.5*(9/12) = 0.5 ; ben: 0.5*(3/4) + 0.5*(3/12) = 0.5
    expect(r['ana']!.contributionPercent, 50);
    expect(r['ben']!.contributionPercent, 50);
    expect(r['ana']!.completedHours, 9);
  });

  test('percentages always sum to exactly 100 (largest remainder, tie by id)', () {
    final r = calc([done('a', 'ana'), done('b', 'ben'), done('c', 'cai')]);
    expect(r['ana']!.contributionPercent, 34);
    expect(r['ben']!.contributionPercent, 33);
    expect(r['cai']!.contributionPercent, 33);
    expect(r.values.fold<int>(0, (s, c) => s + c.contributionPercent), 100);
  });

  test('on-time uses the deadline calendar day', () {
    final r = calc([
      done('ok', 'ana', due: DateTime(2026, 11, 5, 9), at: DateTime(2026, 11, 5, 22)),
      done('late', 'ana', due: DateTime(2026, 11, 5), at: DateTime(2026, 11, 6, 1)),
      done('nodue', 'ana', at: DateTime(2026, 11, 6)),
    ]);
    expect(r['ana']!.onTimeEligible, 2);
    expect(r['ana']!.onTimeCount, 1);
    expect(r['ana']!.onTimeRate, 0.5);
  });

  test('excludes unassigned, non-member and other-workspace tasks; filters project', () {
    final tasks = [
      done('a1', 'ana'),
      done('p2', 'ben', project: 'p2'),
      task('free', status: SpTaskStatus.completed),
      done('gone', 'former-member'),
      task('other', assignee: 'cai', workspaceId: 'ws2', status: SpTaskStatus.completed),
    ];
    final all = calc(tasks);
    expect(all['ana']!.contributionPercent, 50);
    expect(all['ben']!.contributionPercent, 50);
    expect(all['cai']!.contributionPercent, 0);

    final p1 = calc(tasks, projectId: 'p1');
    expect(p1['ana']!.contributionPercent, 100);
    expect(p1['ben']!.completedCount, 0);
  });

  test('progress is the completed share and handles empty sets', () {
    expect(ContributionEngine.progress([]), 0);
    expect(
      ContributionEngine.progress([done('a', 'ana'), task('b'), task('c'), done('d', 'ben')]),
      0.5,
    );
  });

  test('deterministic for shuffled input', () {
    final tasks = [done('a', 'ana', hours: 5), done('b', 'ben', hours: 2), done('c', 'cai', hours: 1)];
    final x = calc(tasks).map((k, v) => MapEntry(k, v.contributionPercent));
    final y = calc(tasks.reversed.toList()).map((k, v) => MapEntry(k, v.contributionPercent));
    expect(y, x);
    expect(x.values.fold<int>(0, (s, v) => s + v), 100);
  });

  group('shareOf (zero-hours fallback)', () {
    test('no completed tasks → 0', () {
      expect(
          ContributionEngine.shareOf(
              completedCount: 0, totalCompletedCount: 0, completedHours: 0, totalCompletedHours: 0),
          0);
    });

    test('zero total hours → task-count share only (no NaN)', () {
      final s = ContributionEngine.shareOf(
          completedCount: 1, totalCompletedCount: 4, completedHours: 0, totalCompletedHours: 0);
      expect(s, 0.25);
      expect(s.isNaN, isFalse);
    });

    test('normal case keeps the 50/50 formula', () {
      // 0.5 * (1/4) + 0.5 * (9/12)
      expect(
          ContributionEngine.shareOf(
              completedCount: 1, totalCompletedCount: 4, completedHours: 9, totalCompletedHours: 12),
          0.5);
    });
  });

  test('missing estimates keep the 3h default (equal to count shares)', () {
    final r = calc([done('a1', 'ana', hours: 0), done('b1', 'ben', hours: 0), done('b2', 'ben', hours: 0)],
        ws: workspace(members: ['ana', 'ben']));
    expect(r['ana']!.completedHours, 3);
    expect(r['ben']!.completedHours, 6);
    expect(r['ana']!.contributionPercent, 33);
    expect(r['ben']!.contributionPercent, 67);
  });
}
