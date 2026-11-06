import 'package:study_app/studypilot/models/team_task.dart';

/// Shared, deterministic helpers for the StudyPilot rule engines.

/// Hours assumed for tasks without an estimate (prototype default).
const double kDefaultTaskHours = 3;

/// Effort used by all engines: the estimate, or [kDefaultTaskHours] when
/// the task has no positive estimate.
double effectiveHours(TeamTask t) =>
    t.estimatedHours > 0 ? t.estimatedHours : kDefaultTaskHours;

/// Whole calendar days from [now] to [due] (negative = overdue). Compares
/// calendar dates only, via UTC, so daylight-saving changes and the time of
/// day never shift the result.
int calendarDaysUntil(DateTime due, DateTime now) {
  final d = DateTime.utc(due.year, due.month, due.day);
  final n = DateTime.utc(now.year, now.month, now.day);
  return d.difference(n).inDays;
}
