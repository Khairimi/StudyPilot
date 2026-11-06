import 'package:study_app/studypilot/core/domain_enums.dart';
import 'package:study_app/studypilot/logic/task_math.dart';
import 'package:study_app/studypilot/models/team_task.dart';

/// One explainable contribution to a Smart Priority score.
class PriorityFactor {
  final String label;
  final int points;
  const PriorityFactor(this.label, this.points);

  @override
  String toString() => '$label (+$points)';
}

class PriorityResult {
  /// 0–100. Completed tasks score 0; active tasks score at least 5.
  final int score;
  final List<PriorityFactor> factors;
  const PriorityResult(this.score, this.factors);

  List<String> get reasons => [for (final f in factors) f.label];
}

/// Smart Priority: a transparent, rule-based 0–100 score (no AI/ML).
///
/// Rules (from the AI Studio prototype's `calculateSmartPriority`):
/// * Deadline: overdue +45, today +40, tomorrow +35, ≤3 days +25,
///   ≤7 days +15, later +5, no deadline +0.
/// * Stated priority: urgent +35, high +25, medium +15, low +5.
/// * Effort: ≥8h +12, ≥5h +8 (unestimated tasks count as 3h).
/// * Open subtasks (to-do / in-progress only): +3 each, max +10.
/// * Active tasks are clamped to 5–100; completed tasks are 0.
class PriorityEngine {
  PriorityEngine._();

  static const int minActiveScore = 5;
  static const int maxScore = 100;

  static PriorityResult score(TeamTask task, DateTime now) {
    if (task.isCompleted) {
      return const PriorityResult(0, [PriorityFactor('Task is completed', 0)]);
    }

    final factors = <PriorityFactor>[];

    // 1. Deadline urgency
    final due = task.dueAt;
    if (due == null) {
      factors.add(const PriorityFactor('No deadline set', 0));
    } else {
      final days = calendarDaysUntil(due, now);
      if (days < 0) {
        final n = -days;
        factors.add(PriorityFactor('Overdue by $n day${n == 1 ? '' : 's'}', 45));
      } else if (days == 0) {
        factors.add(const PriorityFactor('Due today', 40));
      } else if (days == 1) {
        factors.add(const PriorityFactor('Due tomorrow', 35));
      } else if (days <= 3) {
        factors.add(PriorityFactor('Due in $days days', 25));
      } else if (days <= 7) {
        factors.add(PriorityFactor('Due this week ($days days)', 15));
      } else {
        factors.add(const PriorityFactor('Due in more than a week', 5));
      }
    }

    // 2. Stated priority
    factors.add(switch (task.priority) {
      SpPriority.urgent => const PriorityFactor('Marked urgent', 35),
      SpPriority.high => const PriorityFactor('High priority', 25),
      SpPriority.medium => const PriorityFactor('Medium priority', 15),
      SpPriority.low => const PriorityFactor('Low priority', 5),
    });

    // 3. Effort
    final hours = effectiveHours(task);
    if (hours >= 8) {
      factors.add(PriorityFactor('Heavy effort (~${_fmt(hours)}h)', 12));
    } else if (hours >= 5) {
      factors.add(PriorityFactor('Moderate effort (~${_fmt(hours)}h)', 8));
    }

    // 4. Open checklist items
    final open = task.openSubtaskCount;
    if (open > 0 &&
        (task.status == SpTaskStatus.todo || task.status == SpTaskStatus.inProgress)) {
      final pts = (open * 3).clamp(0, 10);
      factors.add(PriorityFactor('$open open subtask${open == 1 ? '' : 's'}', pts));
    }

    final raw = factors.fold<int>(0, (s, f) => s + f.points);
    return PriorityResult(raw.clamp(minActiveScore, maxScore), factors);
  }

  /// Highest priority first. Deterministic tie-breaks: earlier deadline
  /// (no deadline last), then older task, then id.
  static List<TeamTask> rank(Iterable<TeamTask> tasks, DateTime now) {
    final scored = [for (final t in tasks) (task: t, score: score(t, now).score)];
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      final ad = a.task.dueAt, bd = b.task.dueAt;
      if (ad != bd) {
        if (ad == null) return 1;
        if (bd == null) return -1;
        final byDue = ad.compareTo(bd);
        if (byDue != 0) return byDue;
      }
      final byCreated = a.task.createdAt.compareTo(b.task.createdAt);
      if (byCreated != 0) return byCreated;
      return a.task.id.compareTo(b.task.id);
    });
    return [for (final s in scored) s.task];
  }

  static String _fmt(double h) =>
      h == h.roundToDouble() ? h.toInt().toString() : h.toStringAsFixed(1);
}
