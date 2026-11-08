import 'package:study_app/studypilot/logic/contribution_engine.dart';
import 'package:study_app/studypilot/models/models.dart';

/// A workspace with its projects and tasks, plus derived figures for the
/// Teams screens. Pure and immutable.
class WorkspaceOverview {
  final Workspace workspace;
  final List<Project> projects;
  final List<TeamTask> tasks;

  const WorkspaceOverview({required this.workspace, required this.projects, required this.tasks});

  SpRole? roleOf(String userId) => workspace.memberById(userId)?.role;
  bool isOwner(String userId) => workspace.isOwner(userId);

  int get activeTaskCount => tasks.where((t) => t.isActive).length;

  List<TeamTask> tasksOf(String projectId) => [
        for (final t in tasks)
          if (t.projectId == projectId) t,
      ];

  /// Completed share of the project's tasks (0.0–1.0).
  double progressOf(String projectId) => ContributionEngine.progress(tasksOf(projectId));

  int activeTasksFor(String userId) =>
      tasks.where((t) => t.isActive && t.assigneeId == userId).length;

  /// Owners first, then by name (stable for display).
  List<WorkspaceMember> get sortedMembers => [...workspace.members]..sort((a, b) {
      if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
      return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    });
}

/// Form validation for create / join / invite (pure, testable).
class TeamValidators {
  TeamValidators._();

  static final _code = RegExp(r'^[A-Z0-9]{6}$');
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? workspaceName(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter a workspace name';
    if (s.length < 3) return 'Use at least 3 characters';
    if (s.length > 50) return 'Use at most 50 characters';
    return null;
  }

  /// Codes are 6 letters/digits; input is normalised to upper case.
  static String normaliseCode(String v) => v.trim().toUpperCase();

  static String? inviteCode(String? v) {
    final s = normaliseCode(v ?? '');
    if (s.isEmpty) return 'Enter the 6-character invite code';
    if (!_code.hasMatch(s)) return 'Codes are 6 letters or numbers';
    return null;
  }

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Enter an email address';
    if (!_email.hasMatch(s)) return 'Enter a valid email address';
    return null;
  }
}
