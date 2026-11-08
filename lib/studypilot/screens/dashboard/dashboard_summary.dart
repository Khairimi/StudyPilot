import 'package:study_app/studypilot/logic/priority_engine.dart';
import 'package:study_app/studypilot/logic/task_math.dart';
import 'package:study_app/studypilot/logic/workload_engine.dart';
import 'package:study_app/studypilot/models/models.dart';

class RankedTask {
  final TeamTask task;
  final PriorityResult priority;
  const RankedTask(this.task, this.priority);
}

class ActivityItem {
  final TaskActivity activity;
  final TeamTask task;
  const ActivityItem(this.activity, this.task);
}

/// Everything the Home dashboard shows for one workspace, derived with the
/// Phase 3 engines. Pure and deterministic for a given [now].
class DashboardSummary {
  static const int priorityLimit = 5;
  static const int activityLimit = 6;

  final Workspace workspace;
  final int myActiveCount;
  final int dueTodayCount;
  final int overdueCount;
  final int completedCount;
  final int totalCount;
  final List<RankedTask> priorityTasks;
  final List<MemberWorkload> workloads;
  final List<WorkloadConflict> conflicts;
  final List<ActivityItem> recentActivity;

  const DashboardSummary({
    required this.workspace,
    required this.myActiveCount,
    required this.dueTodayCount,
    required this.overdueCount,
    required this.completedCount,
    required this.totalCount,
    required this.priorityTasks,
    required this.workloads,
    required this.conflicts,
    required this.recentActivity,
  });

  String memberName(String? userId) {
    if (userId == null) return 'Unassigned';
    return workspace.memberById(userId)?.displayName ?? 'Former member';
  }

  factory DashboardSummary.build({
    required Workspace workspace,
    required List<TeamTask> tasks,
    required String currentUserId,
    required DateTime now,
  }) {
    final mine = tasks.where((t) => t.workspaceId == workspace.id).toList();
    final active = mine.where((t) => t.isActive).toList();

    int dueIn(bool Function(int days) test) => active
        .where((t) => t.dueAt != null && test(calendarDaysUntil(t.dueAt!, now)))
        .length;

    final ranked = PriorityEngine.rank(active, now)
        .take(priorityLimit)
        .map((t) => RankedTask(t, PriorityEngine.score(t, now)))
        .toList();

    final activity = [
      for (final t in mine)
        for (final a in t.activity) ActivityItem(a, t),
    ]..sort((a, b) {
        final byTime = b.activity.timestamp.compareTo(a.activity.timestamp);
        return byTime != 0 ? byTime : a.activity.id.compareTo(b.activity.id);
      });

    return DashboardSummary(
      workspace: workspace,
      myActiveCount: active.where((t) => t.assigneeId == currentUserId).length,
      dueTodayCount: dueIn((d) => d == 0),
      overdueCount: dueIn((d) => d < 0),
      completedCount: mine.length - active.length,
      totalCount: mine.length,
      priorityTasks: ranked,
      workloads: WorkloadEngine.memberWorkloads(workspace, mine, now),
      conflicts: WorkloadEngine.detectConflicts(workspace, mine, now),
      recentActivity: activity.take(activityLimit).toList(),
    );
  }
}
