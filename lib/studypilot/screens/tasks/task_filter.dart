import 'package:study_app/studypilot/logic/priority_engine.dart';
import 'package:study_app/studypilot/logic/task_math.dart';
import 'package:study_app/studypilot/models/models.dart';

enum TaskScope { all, mine, unassigned }

/// Search + filter settings for the Tasks tab (immutable, pure).
class TaskFilter {
  final String query;
  final TaskScope scope;
  final Set<SpPriority> priorities; // empty = any
  final Set<SpTaskStatus> statuses; // empty = any
  final String? projectId; // null = any

  const TaskFilter({
    this.query = '',
    this.scope = TaskScope.all,
    this.priorities = const {},
    this.statuses = const {},
    this.projectId,
  });

  /// Number of active (non-default) filters, excluding the search text.
  int get activeCount =>
      (scope == TaskScope.all ? 0 : 1) +
      (priorities.isEmpty ? 0 : 1) +
      (statuses.isEmpty ? 0 : 1) +
      (projectId == null ? 0 : 1);

  bool get isDefault => query.trim().isEmpty && activeCount == 0;

  TaskFilter copyWith({
    String? query,
    TaskScope? scope,
    Set<SpPriority>? priorities,
    Set<SpTaskStatus>? statuses,
    Object? projectId = _unset,
  }) =>
      TaskFilter(
        query: query ?? this.query,
        scope: scope ?? this.scope,
        priorities: priorities ?? this.priorities,
        statuses: statuses ?? this.statuses,
        projectId: identical(projectId, _unset) ? this.projectId : projectId as String?,
      );

  bool matches(TeamTask t, String currentUserId) {
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty &&
        !t.title.toLowerCase().contains(q) &&
        !t.description.toLowerCase().contains(q) &&
        !t.tags.any((tag) => tag.toLowerCase().contains(q))) {
      return false;
    }
    switch (scope) {
      case TaskScope.mine:
        if (t.assigneeId != currentUserId) return false;
      case TaskScope.unassigned:
        if (t.assigneeId != null) return false;
      case TaskScope.all:
        break;
    }
    if (priorities.isNotEmpty && !priorities.contains(t.priority)) return false;
    if (statuses.isNotEmpty && !statuses.contains(t.status)) return false;
    if (projectId != null && t.projectId != projectId) return false;
    return true;
  }

  /// Matching tasks ranked by Smart Priority (completed tasks sink to the end).
  List<TeamTask> apply(Iterable<TeamTask> tasks, String currentUserId, DateTime now) =>
      PriorityEngine.rank(tasks.where((t) => matches(t, currentUserId)), now);
}

const Object _unset = Object();

/// Board columns in workflow order, each ranked by Smart Priority.
Map<SpTaskStatus, List<TeamTask>> groupByStatus(List<TeamTask> ranked) => {
      for (final s in SpTaskStatus.values) s: [for (final t in ranked) if (t.status == s) t],
    };

/// Validation for the create/edit task form (pure, testable).
class TaskValidators {
  TaskValidators._();

  static const double maxHours = 200;

  static String? title(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter a task title';
    if (s.length < 3) return 'Use at least 3 characters';
    if (s.length > 120) return 'Use at most 120 characters';
    return null;
  }

  /// Optional; when given must be a number from 0 to [maxHours].
  static String? hours(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return null;
    final h = double.tryParse(s);
    if (h == null) return 'Enter a number of hours';
    if (h < 0) return 'Hours cannot be negative';
    if (h > maxHours) return 'Use at most ${maxHours.toInt()} hours';
    return null;
  }

  static double parseHours(String? v) => double.tryParse(v?.trim() ?? '') ?? 0;

  /// New tasks cannot be due in the past; existing (edited) tasks may keep
  /// an overdue date.
  static String? dueDate(DateTime? due, DateTime now, {required bool isNew}) {
    if (due == null || !isNew) return null;
    return calendarDaysUntil(due, now) < 0 ? 'Due date cannot be in the past' : null;
  }

  static String? project(String? id) => (id == null || id.isEmpty) ? 'Choose a project' : null;
}
