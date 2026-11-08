import 'package:study_app/studypilot/models/team_task.dart';
import 'package:study_app/studypilot/models/workspace.dart';

/// Task permissions for one user in one workspace (proposal: Owner/Member).
///
/// * Owner: full task control (create, edit, status, subtasks, assign).
/// * Member: create tasks (assigned to themselves) and update the status and
///   subtasks of tasks assigned to them. Members cannot edit task details,
///   touch other members' tasks, or assign/reassign tasks, so workload
///   reassignment always goes through the owner.
///
/// Roles come from [workspace]'s member list for [userId] (the signed-in
/// user's id), so the same person can be an owner in one workspace and a
/// member in another. Non-members get no permissions.
class TaskPermissions {
  final Workspace workspace;
  final String userId;

  const TaskPermissions(this.workspace, this.userId);

  bool get isOwner => workspace.isOwner(userId);
  bool get isMember => workspace.isMember(userId);

  bool _inWorkspace(TeamTask t) => t.workspaceId == workspace.id;

  bool get canCreate => isMember;

  /// Only owners choose who a new or existing task is assigned to.
  bool get canChooseAssignee => isOwner;

  bool canAssign(TeamTask t) => isOwner && _inWorkspace(t);

  bool canEditDetails(TeamTask t) => isOwner && _inWorkspace(t);

  /// Status changes and subtask toggles.
  bool canUpdateProgress(TeamTask t) => _inWorkspace(t) && (isOwner || (isMember && t.assigneeId == userId));
}
