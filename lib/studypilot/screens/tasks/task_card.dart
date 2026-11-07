import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/logic/priority_engine.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';

/// Task summary card used by the List and Board views.
class TaskCard extends StatelessWidget {
  final TeamTask task;
  final DateTime now;
  final String assigneeName;
  final String? projectName;
  final VoidCallback onTap;

  /// Board columns use a tighter layout (status is implied by the column).
  final bool compact;

  const TaskCard({
    super.key,
    required this.task,
    required this.now,
    required this.assigneeName,
    required this.onTap,
    this.projectName,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = PriorityEngine.score(task, now);
    final overdue = task.isActive && task.dueAt != null && dueLabel(task.dueAt, now).startsWith('Overdue');
    final open = task.subtasks.where((s) => !s.completed).length;

    return StudyPilotCard(
      onTap: onTap,
      padding: const EdgeInsets.all(SpSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpScoreBadge(score: result.score, size: compact ? 38 : 44),
          const SizedBox(width: SpSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (projectName != null && !compact)
                  Text(projectName!, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: SpSpacing.xs),
                Wrap(
                  spacing: SpSpacing.xs + 2,
                  runSpacing: SpSpacing.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SpPriorityBadge(priority: task.priority),
                    if (!compact) SpStatusBadge(status: task.status, showIcon: false),
                    Text(
                      dueLabel(task.dueAt, now),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: overdue ? theme.colorScheme.error : null,
                        fontWeight: overdue ? FontWeight.w700 : null,
                      ),
                    ),
                    if (task.subtasks.isNotEmpty)
                      Text('${task.subtasks.length - open}/${task.subtasks.length} subtasks',
                          style: theme.textTheme.bodySmall),
                  ],
                ),
                if (!compact && task.isActive) ...[
                  const SizedBox(height: SpSpacing.xs),
                  Text(
                    result.reasons.take(2).join(' · '),
                    style: theme.textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: SpSpacing.sm),
          Tooltip(
            message: assigneeName,
            child: SpMemberAvatar(name: assigneeName, colorSeed: task.assigneeId, size: compact ? 26 : 30),
          ),
        ],
      ),
    );
  }
}
