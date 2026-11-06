import 'package:study_app/studypilot/core/domain_enums.dart';
import 'package:study_app/studypilot/logic/priority_engine.dart';
import 'package:study_app/studypilot/logic/task_math.dart';
import 'package:study_app/studypilot/models/team_task.dart';
import 'package:study_app/studypilot/models/workload_conflict.dart';
import 'package:study_app/studypilot/models/workspace.dart';

/// Active workload of one workspace member.
class MemberWorkload {
  final String userId;
  final List<TeamTask> activeTasks;
  final double activeHours;

  /// Active tasks due within the congestion window (incl. overdue).
  final List<TeamTask> dueSoonTasks;
  final double thresholdHours;

  const MemberWorkload({
    required this.userId,
    required this.activeTasks,
    required this.activeHours,
    required this.dueSoonTasks,
    required this.thresholdHours,
  });

  /// activeHours / threshold (1.0 = at capacity).
  double get loadRatio => thresholdHours > 0 ? activeHours / thresholdHours : 0;
  bool get isOverCapacity => activeHours >= thresholdHours;
  bool get isCongested => dueSoonTasks.length >= WorkloadEngine.congestionTaskCount;
}

/// Deterministic workload conflict detection (no AI/ML).
///
/// Rules (from the AI Studio prototype's `detectWorkloadConflicts`, adapted):
/// * Only active tasks in the workspace, assigned to current members, count.
/// * Deadline congestion: ≥3 active tasks due within 2 calendar days → high.
///   (Adaptation: overdue tasks also count; the prototype ignored them.)
/// * Capacity overload: active hours ≥ threshold (default 15h) → medium,
///   ≥1.5× threshold → high. (Adaptation: the high tier is new.)
/// * One conflict per member; congestion takes precedence and an overload
///   is then listed as an extra reason.
/// * Suggestion (advisory, owner approval required): move the member's
///   lowest-Smart-Priority conflicting task to the least-loaded other member
///   who stays under the threshold and is not congested. (Adaptation: the
///   prototype could suggest a target that would itself become overloaded.)
class WorkloadEngine {
  WorkloadEngine._();

  static const int congestionTaskCount = 3;
  static const int congestionWindowDays = 2;
  static const double highOverloadFactor = 1.5;

  static double thresholdFor(Workspace ws, double? override) {
    final t = override ?? ws.workloadThresholdHours;
    return t > 0 ? t : Workspace.defaultWorkloadThresholdHours;
  }

  /// Workload for every member, in member order.
  static List<MemberWorkload> memberWorkloads(
    Workspace ws,
    Iterable<TeamTask> tasks,
    DateTime now, {
    double? thresholdHours,
  }) {
    final threshold = thresholdFor(ws, thresholdHours);
    final byMember = <String, List<TeamTask>>{for (final id in ws.memberIds) id: []};
    for (final t in tasks) {
      final a = t.assigneeId;
      if (t.workspaceId != ws.id || !t.isActive || a == null) continue;
      byMember[a]?.add(t); // ignores non-members (e.g. removed members)
    }

    return [
      for (final m in ws.members)
        () {
          final active = [...byMember[m.userId]!]..sort((a, b) => a.id.compareTo(b.id));
          return MemberWorkload(
            userId: m.userId,
            activeTasks: active,
            activeHours: active.fold(0.0, (s, t) => s + effectiveHours(t)),
            dueSoonTasks: [
              for (final t in active)
                if (t.dueAt != null && calendarDaysUntil(t.dueAt!, now) <= congestionWindowDays) t,
            ],
            thresholdHours: threshold,
          );
        }(),
    ];
  }

  static List<WorkloadConflict> detectConflicts(
    Workspace ws,
    Iterable<TeamTask> tasks,
    DateTime now, {
    double? thresholdHours,
  }) {
    final loads = memberWorkloads(ws, tasks, now, thresholdHours: thresholdHours);
    final conflicts = <WorkloadConflict>[];

    for (final w in loads) {
      final congested = w.isCongested;
      final overloaded = w.isOverCapacity;
      if (!congested && !overloaded) continue;

      final type = congested ? ConflictType.deadlineCongestion : ConflictType.capacityOverload;
      final severity = congested || w.activeHours >= w.thresholdHours * highOverloadFactor
          ? SpSeverity.high
          : SpSeverity.medium;
      final conflictTasks = congested ? w.dueSoonTasks : w.activeTasks;

      final reasons = <String>[
        if (congested)
          '${w.dueSoonTasks.length} active tasks due within $congestionWindowDays days '
              '(limit: ${congestionTaskCount - 1})',
        if (overloaded)
          '${_fmt(w.activeHours)}h assigned across ${w.activeTasks.length} active tasks '
              '(threshold: ${_fmt(w.thresholdHours)}h)',
      ];

      final suggestion = _suggest(w, conflictTasks, loads, now);
      if (suggestion != null) {
        reasons.add('Suggestion requires owner approval before reassigning');
      } else {
        reasons.add('No teammate has spare capacity; consider extending deadlines');
      }

      conflicts.add(WorkloadConflict(
        id: '${type.name}-${w.userId}',
        workspaceId: ws.id,
        memberId: w.userId,
        type: type,
        severity: severity,
        taskIds: [for (final t in conflictTasks) t.id],
        assignedHours: w.activeHours,
        thresholdHours: w.thresholdHours,
        dueSoonCount: w.dueSoonTasks.length,
        reasons: reasons,
        suggestedTaskId: suggestion?.taskId,
        suggestedAssigneeId: suggestion?.assigneeId,
      ));
    }

    conflicts.sort((a, b) {
      final bySeverity = a.severity.index.compareTo(b.severity.index); // high first
      if (bySeverity != 0) return bySeverity;
      final byHours = b.assignedHours.compareTo(a.assignedHours);
      if (byHours != 0) return byHours;
      return a.memberId.compareTo(b.memberId);
    });
    return conflicts;
  }

  static ({String taskId, String assigneeId})? _suggest(
    MemberWorkload source,
    List<TeamTask> conflictTasks,
    List<MemberWorkload> all,
    DateTime now,
  ) {
    // Least critical task first: lowest score, then latest deadline, then id.
    final candidatesTasks = [...conflictTasks]..sort((a, b) {
        final byScore = PriorityEngine.score(a, now).score
            .compareTo(PriorityEngine.score(b, now).score);
        if (byScore != 0) return byScore;
        final ad = a.dueAt, bd = b.dueAt;
        if (ad != bd) {
          if (ad == null) return -1;
          if (bd == null) return 1;
          final byDue = bd.compareTo(ad);
          if (byDue != 0) return byDue;
        }
        return a.id.compareTo(b.id);
      });

    // Least-loaded other members first (tie: userId).
    final targets = [
      for (final w in all)
        if (w.userId != source.userId && !w.isCongested) w,
    ]..sort((a, b) {
        final byHours = a.activeHours.compareTo(b.activeHours);
        return byHours != 0 ? byHours : a.userId.compareTo(b.userId);
      });

    for (final task in candidatesTasks) {
      for (final target in targets) {
        if (target.activeHours + effectiveHours(task) < target.thresholdHours) {
          return (taskId: task.id, assigneeId: target.userId);
        }
      }
    }
    return null;
  }

  static String _fmt(double h) =>
      h == h.roundToDouble() ? h.toInt().toString() : h.toStringAsFixed(1);
}
