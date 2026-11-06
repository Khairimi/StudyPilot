import 'package:study_app/studypilot/logic/task_math.dart';
import 'package:study_app/studypilot/models/models.dart';

/// Short text helpers for the dashboard (pure, testable).

String dueLabel(DateTime? due, DateTime now) {
  if (due == null) return 'No deadline';
  final d = calendarDaysUntil(due, now);
  if (d < 0) return 'Overdue ${-d} day${d == -1 ? '' : 's'}';
  if (d == 0) return 'Due today';
  if (d == 1) return 'Due tomorrow';
  return 'Due in $d days';
}

String timeAgo(DateTime t, DateTime now) {
  final diff = now.difference(t);
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}

String hoursText(double h) =>
    h == h.roundToDouble() ? '${h.toInt()}h' : '${h.toStringAsFixed(1)}h';

String activityVerb(TaskActivityType type) => switch (type) {
      TaskActivityType.created => 'created',
      TaskActivityType.edited => 'updated',
      TaskActivityType.assigned => 'assigned',
      TaskActivityType.reassigned => 'reassigned',
      TaskActivityType.statusChanged => 'moved',
      TaskActivityType.completed => 'completed',
    };

String greeting(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

String firstName(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return parts.isEmpty || parts.first.isEmpty ? 'there' : parts.first;
}

String workspaceTypeLabel(WorkspaceType t) => switch (t) {
      WorkspaceType.smallBusiness => 'Small business team',
      WorkspaceType.universityProject => 'University project group',
      WorkspaceType.other => 'Team',
    };
