import 'package:study_app/studypilot/core/domain_enums.dart';

enum ConflictType {
  /// Several active tasks due within the congestion window (48h).
  deadlineCongestion,

  /// Assigned active hours at or above the workspace threshold.
  capacityOverload,
}

/// A detected workload problem for one member. Produced by the workload
/// engine (derived data, recomputed from tasks — not a source of truth).
/// Suggestions are advisory only: reassignment needs owner approval.
class WorkloadConflict {
  final String id;
  final String workspaceId;
  final String memberId;
  final ConflictType type;
  final SpSeverity severity;

  /// Tasks causing the conflict, in deterministic order.
  final List<String> taskIds;

  /// Active hours assigned to the member (all active tasks).
  final double assignedHours;
  final double thresholdHours;

  /// Number of active tasks due inside the congestion window.
  final int dueSoonCount;

  /// Optional advisory reassignment: move [suggestedTaskId] to
  /// [suggestedAssigneeId]. Both null when no safe target exists.
  final String? suggestedTaskId;
  final String? suggestedAssigneeId;

  /// Human-readable, rule-based explanation (transparency).
  final List<String> reasons;

  const WorkloadConflict({
    required this.id,
    required this.workspaceId,
    required this.memberId,
    required this.type,
    required this.severity,
    required this.taskIds,
    required this.assignedHours,
    required this.thresholdHours,
    required this.dueSoonCount,
    required this.reasons,
    this.suggestedTaskId,
    this.suggestedAssigneeId,
  });

  bool get hasSuggestion => suggestedTaskId != null && suggestedAssigneeId != null;
}
