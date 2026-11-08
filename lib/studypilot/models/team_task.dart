import 'package:study_app/studypilot/core/domain_enums.dart';
import 'package:study_app/studypilot/models/model_utils.dart';

/// Checklist item inside a task.
class Subtask {
  final String id;
  final String title;
  final bool completed;

  const Subtask({required this.id, required this.title, this.completed = false});

  Subtask copyWith({String? title, bool? completed}) =>
      Subtask(id: id, title: title ?? this.title, completed: completed ?? this.completed);

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'completed': completed};

  factory Subtask.fromMap(Map<String, dynamic> m) => Subtask(
        id: m['id'] as String? ?? '',
        title: m['title'] as String? ?? '',
        completed: m['completed'] == true,
      );
}

enum TaskActivityType { created, edited, assigned, reassigned, statusChanged, completed }

/// Audit entry used for contribution tracking and the activity feed.
class TaskActivity {
  final String id;
  final String userId;
  final TaskActivityType type;

  /// Optional detail, e.g. "todo → inProgress" or the new assignee id.
  final String detail;
  final DateTime timestamp;

  const TaskActivity({
    required this.id,
    required this.userId,
    required this.type,
    required this.timestamp,
    this.detail = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'type': type.name,
        'detail': detail,
        'timestamp': timestamp.toIso8601String(),
      };

  factory TaskActivity.fromMap(Map<String, dynamic> m) => TaskActivity(
        id: m['id'] as String? ?? '',
        userId: m['userId'] as String? ?? '',
        type: enumByName(TaskActivityType.values, m['type'], TaskActivityType.edited),
        detail: m['detail'] as String? ?? '',
        timestamp: parseDate(m['timestamp']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// A task in a workspace project. The Smart Priority score is NOT stored:
/// it depends on the current date and is computed by the priority engine.
class TeamTask {
  final String id;
  final String workspaceId;
  final String projectId;
  final String title;
  final String description;

  /// Null when the task is unassigned.
  final String? assigneeId;
  final String createdBy;
  final SpPriority priority;
  final SpTaskStatus status;

  /// Deadline (date and optional time). Null = no deadline.
  final DateTime? dueAt;

  /// Effort estimate in hours. Values <= 0 mean "not estimated".
  final double estimatedHours;
  final List<Subtask> subtasks;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<TaskActivity> activity;

  const TeamTask({
    required this.id,
    required this.workspaceId,
    required this.projectId,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    this.description = '',
    this.assigneeId,
    this.priority = SpPriority.medium,
    this.status = SpTaskStatus.todo,
    this.dueAt,
    this.estimatedHours = 0,
    this.subtasks = const [],
    this.tags = const [],
    this.completedAt,
    this.activity = const [],
  });

  bool get isCompleted => status == SpTaskStatus.completed;
  bool get isActive => !isCompleted;
  int get openSubtaskCount => subtasks.where((s) => !s.completed).length;

  TeamTask copyWith({
    String? projectId,
    String? title,
    String? description,
    Object? assigneeId = unset,
    SpPriority? priority,
    SpTaskStatus? status,
    Object? dueAt = unset,
    double? estimatedHours,
    List<Subtask>? subtasks,
    List<String>? tags,
    Object? completedAt = unset,
    List<TaskActivity>? activity,
  }) =>
      TeamTask(
        id: id,
        workspaceId: workspaceId,
        projectId: projectId ?? this.projectId,
        title: title ?? this.title,
        description: description ?? this.description,
        assigneeId: identical(assigneeId, unset) ? this.assigneeId : assigneeId as String?,
        createdBy: createdBy,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        dueAt: identical(dueAt, unset) ? this.dueAt : dueAt as DateTime?,
        estimatedHours: estimatedHours ?? this.estimatedHours,
        subtasks: subtasks ?? this.subtasks,
        tags: tags ?? this.tags,
        createdAt: createdAt,
        completedAt: identical(completedAt, unset) ? this.completedAt : completedAt as DateTime?,
        activity: activity ?? this.activity,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'workspaceId': workspaceId,
        'projectId': projectId,
        'title': title,
        'description': description,
        'assigneeId': assigneeId,
        'createdBy': createdBy,
        'priority': priority.name,
        'status': status.name,
        'dueAt': isoOrNull(dueAt),
        'estimatedHours': estimatedHours,
        'subtasks': [for (final s in subtasks) s.toMap()],
        'tags': tags,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': isoOrNull(completedAt),
        'activity': [for (final a in activity) a.toMap()],
      };

  factory TeamTask.fromMap(Map<String, dynamic> m) => TeamTask(
        id: m['id'] as String? ?? '',
        workspaceId: m['workspaceId'] as String? ?? '',
        projectId: m['projectId'] as String? ?? '',
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        assigneeId: switch (m['assigneeId']) {
          final String id when id.isNotEmpty => id,
          _ => null,
        },
        createdBy: m['createdBy'] as String? ?? '',
        priority: enumByName(SpPriority.values, m['priority'], SpPriority.medium),
        status: enumByName(SpTaskStatus.values, m['status'], SpTaskStatus.todo),
        dueAt: parseDate(m['dueAt']),
        estimatedHours: parseDouble(m['estimatedHours']),
        subtasks: [for (final s in parseMapList(m['subtasks'])) Subtask.fromMap(s)],
        tags: parseStringList(m['tags']),
        createdAt: parseDate(m['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        completedAt: parseDate(m['completedAt']),
        activity: [for (final a in parseMapList(m['activity'])) TaskActivity.fromMap(a)],
      );
}
