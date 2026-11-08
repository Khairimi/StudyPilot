import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/logic/priority_engine.dart';
import 'package:study_app/studypilot/logic/task_math.dart';
import 'package:study_app/studypilot/logic/task_permissions.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';
import 'package:study_app/studypilot/screens/tasks/task_forms.dart';

/// Read-only task details with an explained Smart Priority score. Status,
/// assignment, edits and checklist toggles are demo previews (not saved).
class TaskDetailScreen extends StatelessWidget {
  final TeamTask task;
  final Workspace workspace;
  final List<Project> projects;
  final List<TeamTask> allTasks;
  final String currentUserId;
  final DateTime now;
  final bool isDemo;

  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.workspace,
    required this.projects,
    required this.allTasks,
    required this.currentUserId,
    required this.now,
    required this.isDemo,
  });

  String _name(String? id) =>
      id == null ? 'Unassigned' : workspace.memberById(id)?.displayName ?? 'Former member';

  String get _projectName {
    for (final p in projects) {
      if (p.id == task.projectId) return p.title;
    }
    return 'No project';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = PriorityEngine.score(task, now);
    final activity = [...task.activity]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final done = task.subtasks.where((s) => s.completed).length;
    final perms = TaskPermissions(workspace, currentUserId);
    final canEdit = perms.canEditDetails(task);
    final canProgress = perms.canUpdateProgress(task);
    final canAssign = perms.canAssign(task);
    final permissionNote = canEdit
        ? null
        : canProgress
            ? 'You can update the status and subtasks of your task. Only the workspace owner can edit details or reassign it.'
            : 'View only: only the assignee or the workspace owner can update this task.';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Task details'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'Edit task',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => showTaskFormSheet(
                context,
                workspace: workspace,
                projects: projects,
                currentUserId: currentUserId,
                now: now,
                existing: task,
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SpSpacing.lg, SpSpacing.md, SpSpacing.lg, SpSpacing.xxl),
        children: [
          if (isDemo) ...[
            const SpDemoModeBanner(message: 'Demo task: changes here are not saved.'),
            const SizedBox(height: SpSpacing.md),
          ],
          Text(task.title, style: theme.textTheme.headlineMedium),
          const SizedBox(height: SpSpacing.xs),
          Text(_projectName, style: theme.textTheme.bodyMedium),
          const SizedBox(height: SpSpacing.sm),
          Wrap(
            spacing: SpSpacing.sm,
            runSpacing: SpSpacing.xs,
            children: [
              SpPriorityBadge(priority: task.priority),
              SpStatusBadge(status: task.status),
            ],
          ),
          if (canProgress || canAssign) ...[
            const SizedBox(height: SpSpacing.md),
            Row(
              children: [
                if (canProgress)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          showStatusSheet(context, task: task, workspace: workspace, currentUserId: currentUserId),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Status'),
                    ),
                  ),
                if (canProgress && canAssign) const SizedBox(width: SpSpacing.sm),
                if (canAssign)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showAssignSheet(context,
                          task: task,
                          workspace: workspace,
                          allTasks: allTasks,
                          currentUserId: currentUserId,
                          now: now),
                      icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                      label: const Text('Assign'),
                    ),
                  ),
              ],
            ),
          ],
          if (permissionNote != null) ...[
            const SizedBox(height: SpSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: SpSpacing.sm),
                Expanded(child: Text(permissionNote, style: theme.textTheme.bodySmall)),
              ],
            ),
          ],
          const SizedBox(height: SpSpacing.lg),
          StudyPilotCard(
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.person_outline_rounded,
                  label: 'Assignee',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SpMemberAvatar(name: _name(task.assigneeId), colorSeed: task.assigneeId, size: 24),
                      const SizedBox(width: SpSpacing.sm),
                      Flexible(child: Text(_name(task.assigneeId), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
                _InfoRow(icon: Icons.event_outlined, label: 'Due', value: dueLabel(task.dueAt, now)),
                _InfoRow(
                  icon: Icons.timer_outlined,
                  label: 'Estimate',
                  value: task.estimatedHours > 0
                      ? hoursText(task.estimatedHours)
                      : 'Not estimated (counted as ${hoursText(kDefaultTaskHours)})',
                ),
              ],
            ),
          ),
          const SizedBox(height: SpSpacing.xl),
          const SpSectionHeading(
            title: 'Smart Priority',
            subtitle: 'Rule-based score from deadline, priority, effort and checklist',
            icon: Icons.auto_awesome_outlined,
          ),
          StudyPilotCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SpScoreBadge(score: result.score, size: 52),
                    const SizedBox(width: SpSpacing.md),
                    Expanded(
                      child: Text(
                        task.isCompleted ? 'Completed tasks are not prioritised.' : 'Score out of 100',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpSpacing.md),
                for (final f in result.factors)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: SpSpacing.xxs + 1),
                    child: Row(
                      children: [
                        Expanded(child: Text(f.label, style: theme.textTheme.bodyMedium)),
                        Text('+${f.points}',
                            style: theme.textTheme.labelLarge
                                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                      ],
                    ),
                  ),
                if (!task.isCompleted &&
                    result.factors.fold<int>(0, (s, f) => s + f.points) != result.score)
                  Text('Total kept within ${PriorityEngine.minActiveScore}–${PriorityEngine.maxScore}.',
                      style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          if (task.description.isNotEmpty) ...[
            const SizedBox(height: SpSpacing.xl),
            const SpSectionHeading(title: 'Description', icon: Icons.notes_rounded),
            StudyPilotCard(child: Text(task.description, style: theme.textTheme.bodyMedium)),
          ],
          const SizedBox(height: SpSpacing.xl),
          SpSectionHeading(
            title: 'Subtasks',
            subtitle: task.subtasks.isEmpty ? null : '$done of ${task.subtasks.length} done',
            icon: Icons.checklist_rounded,
          ),
          StudyPilotCard(
            padding: const EdgeInsets.symmetric(vertical: SpSpacing.xs),
            child: task.subtasks.isEmpty
                ? const Padding(padding: EdgeInsets.all(SpSpacing.lg), child: Text('No subtasks.'))
                : Column(
                    children: [
                      for (final s in task.subtasks)
                        CheckboxListTile(
                          value: s.completed,
                          title: Text(s.title),
                          controlAffinity: ListTileControlAffinity.leading,
                          // Demo: the checkbox does not change; the user is told why.
                          // Disabled for users who may not update this task.
                          onChanged: canProgress
                              ? (_) => showDemoNotice(context, 'subtask "${s.title}" was not updated.')
                              : null,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: SpSpacing.xl),
          const SpSectionHeading(title: 'Activity', icon: Icons.history_rounded),
          StudyPilotCard(
            padding: const EdgeInsets.symmetric(vertical: SpSpacing.xs),
            child: activity.isEmpty
                ? const Padding(padding: EdgeInsets.all(SpSpacing.lg), child: Text('No activity yet.'))
                : Column(
                    children: [
                      for (final a in activity)
                        ListTile(
                          dense: true,
                          leading: SpMemberAvatar(name: _name(a.userId), colorSeed: a.userId, size: 28),
                          title: Text('${_name(a.userId)} ${activityVerb(a.type)} this task'),
                          subtitle: Text([
                            if (a.detail.isNotEmpty) a.detail,
                            timeAgo(a.timestamp, now),
                          ].join(' · ')),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  const _InfoRow({required this.icon, required this.label, this.value, this.trailing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpSpacing.xs + 2),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: SpSpacing.sm),
          Text(label, style: theme.textTheme.bodyMedium),
          const SizedBox(width: SpSpacing.md),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: trailing ??
                  Text(value ?? '',
                      style: theme.textTheme.labelLarge, textAlign: TextAlign.end, overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
      ),
    );
  }
}
