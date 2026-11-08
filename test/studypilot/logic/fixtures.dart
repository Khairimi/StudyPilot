import 'package:study_app/studypilot/models/models.dart';

/// Fixed clock for deterministic tests: Tue 10 Nov 2026, 09:00 local.
final now = DateTime(2026, 11, 10, 9);

DateTime inDays(int days, {int hour = 17}) =>
    DateTime(now.year, now.month, now.day + days, hour);

TeamTask task(
  String id, {
  String workspaceId = 'ws1',
  String projectId = 'p1',
  String? assignee,
  SpPriority priority = SpPriority.medium,
  SpTaskStatus status = SpTaskStatus.todo,
  DateTime? due,
  double hours = 0,
  List<Subtask> subtasks = const [],
  DateTime? completedAt,
  DateTime? createdAt,
}) =>
    TeamTask(
      id: id,
      workspaceId: workspaceId,
      projectId: projectId,
      title: 'Task $id',
      createdBy: 'owner',
      createdAt: createdAt ?? DateTime(2026, 11, 1),
      assigneeId: assignee,
      priority: priority,
      status: status,
      dueAt: due,
      estimatedHours: hours,
      subtasks: subtasks,
      completedAt: completedAt,
    );

Workspace workspace({List<String> members = const ['ana', 'ben', 'cai'], double threshold = 15}) =>
    Workspace(
      id: 'ws1',
      name: 'Pilot Team',
      type: WorkspaceType.smallBusiness,
      ownerId: members.first,
      inviteCode: 'PILOT1',
      createdAt: DateTime(2026, 10, 1),
      workloadThresholdHours: threshold,
      members: [
        for (final m in members)
          WorkspaceMember(
            userId: m,
            displayName: m.toUpperCase(),
            role: m == members.first ? SpRole.owner : SpRole.member,
            joinedAt: DateTime(2026, 10, 1),
          ),
      ],
    );
