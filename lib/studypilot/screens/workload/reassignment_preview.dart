import 'package:study_app/studypilot/logic/task_math.dart';
import 'package:study_app/studypilot/logic/workload_engine.dart';
import 'package:study_app/studypilot/models/models.dart';

/// Before/after view of a suggested reassignment (pure, read-only). Used by
/// the owner review sheet; it never changes any task.
class ReassignmentPreview {
  final WorkloadConflict conflict;
  final TeamTask task;
  final MemberWorkload from;
  final MemberWorkload to;

  const ReassignmentPreview({
    required this.conflict,
    required this.task,
    required this.from,
    required this.to,
  });

  double get taskHours => effectiveHours(task);
  double get threshold => from.thresholdHours;

  double get fromHoursAfter => from.activeHours - taskHours;
  double get toHoursAfter => to.activeHours + taskHours;

  bool get _taskIsDueSoon => from.dueSoonTasks.any((t) => t.id == task.id);
  int get fromDueSoonAfter => from.dueSoonTasks.length - (_taskIsDueSoon ? 1 : 0);
  int get toDueSoonAfter => to.dueSoonTasks.length + (_taskIsDueSoon ? 1 : 0);

  /// The receiving member stays below capacity and is not congested.
  bool get targetStaysHealthy =>
      toHoursAfter < threshold && toDueSoonAfter < WorkloadEngine.congestionTaskCount;

  /// Whether the move would clear this conflict for the source member.
  bool get resolvesConflict => switch (conflict.type) {
        ConflictType.deadlineCongestion =>
          fromDueSoonAfter < WorkloadEngine.congestionTaskCount && fromHoursAfter < threshold,
        ConflictType.capacityOverload => fromHoursAfter < threshold,
      };

  /// Builds the preview for a conflict's suggestion, or null if the
  /// conflict has no suggestion or the data no longer matches.
  static ReassignmentPreview? of(
    WorkloadConflict conflict,
    List<MemberWorkload> workloads,
    List<TeamTask> tasks,
  ) {
    if (!conflict.hasSuggestion) return null;
    MemberWorkload? find(String id) => workloads.where((w) => w.userId == id).firstOrNull;
    final from = find(conflict.memberId);
    final to = find(conflict.suggestedAssigneeId!);
    final task = tasks.where((t) => t.id == conflict.suggestedTaskId).firstOrNull;
    if (from == null || to == null || task == null) return null;
    return ReassignmentPreview(conflict: conflict, task: task, from: from, to: to);
  }
}
