import 'package:study_app/studypilot/core/domain_enums.dart';
import 'package:study_app/studypilot/logic/task_math.dart';
import 'package:study_app/studypilot/models/team_task.dart';
import 'package:study_app/studypilot/models/workspace.dart';

class MemberContribution {
  final String userId;
  final SpRole role;
  final int assignedCount;
  final int completedCount;
  final int activeCount;
  final double completedHours;
  final double activeHours;

  /// Completed tasks that had both a deadline and a completion time.
  final int onTimeEligible;
  final int onTimeCount;

  /// Share of the team's completed work, 0–100. All members' values sum to
  /// exactly 100 when anything is completed, otherwise all are 0.
  final int contributionPercent;

  const MemberContribution({
    required this.userId,
    required this.role,
    required this.assignedCount,
    required this.completedCount,
    required this.activeCount,
    required this.completedHours,
    required this.activeHours,
    required this.onTimeEligible,
    required this.onTimeCount,
    required this.contributionPercent,
  });

  /// 0.0–1.0, or null when there is nothing to measure.
  double? get onTimeRate => onTimeEligible == 0 ? null : onTimeCount / onTimeEligible;
}

/// Transparent contribution tracking (no AI/ML).
///
/// Rules (from the AI Studio prototype's `calculateMemberContributions`):
/// * Contribution = 50% share of completed task count + 50% share of
///   completed effort hours (unestimated tasks count as 3h).
/// * On-time = completed on or before the deadline's calendar day.
/// Adaptations:
/// * With no completed work every member gets 0% (the prototype split 100%
///   equally, which overstated contribution).
/// * Percentages use largest-remainder rounding so they always sum to 100.
/// * On-time rate is null (not 100%) when no eligible tasks exist.
/// * Only tasks assigned to current members count (unassigned / removed
///   members' tasks are excluded from the shares).
class ContributionEngine {
  ContributionEngine._();

  static List<MemberContribution> calculate(
    Workspace ws,
    Iterable<TeamTask> tasks, {
    String? projectId,
  }) {
    final memberIds = ws.memberIds.toSet();
    final relevant = [
      for (final t in tasks)
        if (t.workspaceId == ws.id &&
            (projectId == null || t.projectId == projectId) &&
            t.assigneeId != null &&
            memberIds.contains(t.assigneeId))
          t,
    ];

    final completed = relevant.where((t) => t.isCompleted).toList();
    final totalCount = completed.length;
    final totalHours = completed.fold<double>(0, (s, t) => s + effectiveHours(t));

    final rows = <_Row>[];
    for (final m in ws.members) {
      final mine = relevant.where((t) => t.assigneeId == m.userId).toList();
      final done = mine.where((t) => t.isCompleted).toList();
      final active = mine.where((t) => t.isActive).toList();
      final eligible = done.where((t) => t.dueAt != null && t.completedAt != null).toList();
      final onTime =
          eligible.where((t) => calendarDaysUntil(t.dueAt!, t.completedAt!) >= 0).length;
      final doneHours = done.fold<double>(0, (s, t) => s + effectiveHours(t));

      final share = totalCount == 0
          ? 0.0
          : 0.5 * (done.length / totalCount) + 0.5 * (doneHours / totalHours);

      rows.add(_Row(
        m.userId,
        m.role,
        mine.length,
        done.length,
        active.length,
        doneHours,
        active.fold<double>(0, (s, t) => s + effectiveHours(t)),
        eligible.length,
        onTime,
        share * 100,
      ));
    }

    final percents = totalCount == 0
        ? List<int>.filled(rows.length, 0)
        : _largestRemainder([for (final r in rows) r.rawPercent], [for (final r in rows) r.userId]);

    return [
      for (var i = 0; i < rows.length; i++)
        MemberContribution(
          userId: rows[i].userId,
          role: rows[i].role,
          assignedCount: rows[i].assigned,
          completedCount: rows[i].completed,
          activeCount: rows[i].active,
          completedHours: rows[i].completedHours,
          activeHours: rows[i].activeHours,
          onTimeEligible: rows[i].eligible,
          onTimeCount: rows[i].onTime,
          contributionPercent: percents[i],
        ),
    ];
  }

  /// Share of a project's (or any task set's) tasks that are completed,
  /// 0.0–1.0. Returns 0 for an empty set.
  static double progress(Iterable<TeamTask> tasks) {
    final list = tasks.toList();
    if (list.isEmpty) return 0;
    return list.where((t) => t.isCompleted).length / list.length;
  }

  /// Rounds [raw] (summing to ~100) to integers summing to exactly 100.
  /// Ties on the fractional part go to the smaller id (deterministic).
  static List<int> _largestRemainder(List<double> raw, List<String> ids) {
    final floors = [for (final r in raw) r.floor()];
    var remaining = 100 - floors.fold<int>(0, (s, f) => s + f);
    final order = List<int>.generate(raw.length, (i) => i)
      ..sort((a, b) {
        final fa = raw[a] - floors[a], fb = raw[b] - floors[b];
        final byFrac = fb.compareTo(fa);
        return byFrac != 0 ? byFrac : ids[a].compareTo(ids[b]);
      });
    for (final i in order) {
      if (remaining <= 0) break;
      floors[i]++;
      remaining--;
    }
    return floors;
  }
}

class _Row {
  final String userId;
  final SpRole role;
  final int assigned, completed, active, eligible, onTime;
  final double completedHours, activeHours, rawPercent;
  _Row(this.userId, this.role, this.assigned, this.completed, this.active, this.completedHours,
      this.activeHours, this.eligible, this.onTime, this.rawPercent);
}
