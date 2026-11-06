/// Shared StudyPilot domain vocabulary (pure Dart, no Flutter imports).
/// UI labels/colours for these live in theme/sp_semantics.dart.
library;

enum SpPriority { urgent, high, medium, low }

enum SpTaskStatus { todo, inProgress, inReview, completed }

enum SpSeverity { high, medium, low }

enum SpRole { owner, member }

/// Parses an enum by [Enum.name], falling back to [fallback] for unknown or
/// missing values (e.g. data written by a newer app version).
T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  if (name is! String) return fallback;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}
