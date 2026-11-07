import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/core/sp_shell_scope.dart';
import 'package:study_app/studypilot/logic/workload_engine.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_summary.dart';

void _comingSoon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text('$what arrives in a later phase.')));
}

/// Workspace picker shown at the top of the dashboard.
class WorkspaceSelector extends StatelessWidget {
  final List<Workspace> workspaces;
  final Workspace selected;
  final ValueChanged<String> onSelected;

  const WorkspaceSelector({
    super.key,
    required this.workspaces,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StudyPilotCard(
      padding: EdgeInsets.zero,
      child: PopupMenuButton<String>(
        tooltip: 'Switch workspace',
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final w in workspaces)
            CheckedPopupMenuItem(value: w.id, checked: w.id == selected.id, child: Text(w.name)),
        ],
        child: Padding(
          padding: const EdgeInsets.all(SpSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(SpRadius.md),
                ),
                child: Icon(
                  selected.type == WorkspaceType.universityProject
                      ? Icons.school_outlined
                      : Icons.storefront_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: SpSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selected.name,
                        style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      '${workspaceTypeLabel(selected.type)} · ${selected.members.length} members',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SpAvatarStack(
                members: [
                  for (final m in selected.members) (name: m.displayName, id: m.userId, photoUrl: null),
                ],
                maxVisible: 3,
                size: 26,
              ),
              const SizedBox(width: SpSpacing.xs),
              const Icon(Icons.unfold_more_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class DemoDataBanner extends StatelessWidget {
  const DemoDataBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final tone = SpTone.info(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SpSpacing.md, vertical: SpSpacing.sm),
      decoration: BoxDecoration(color: tone.background, borderRadius: SpRadius.control),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: tone.foreground),
          const SizedBox(width: SpSpacing.sm),
          Expanded(
            child: Text(
              'Demo data: sample workspaces for preview. Your real team data will appear after Firebase integration.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}

/// Highlights the most severe workload conflict (prototype "Workload
/// Imbalance Alert").
class WorkloadAlertCard extends StatelessWidget {
  final DashboardSummary summary;

  /// Opens Workload Insights (null = not available in this context).
  final VoidCallback? onViewDetails;
  const WorkloadAlertCard({super.key, required this.summary, this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = summary.conflicts.first;
    final tone = c.severity.tone(context);
    final taskTitle = c.suggestedTaskId == null ? null : _titleOf(c.suggestedTaskId!);
    final more = summary.conflicts.length - 1;

    return StudyPilotCard(
      color: tone.background,
      accentColor: tone.foreground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title wraps (max 2 lines) beside a top-aligned severity badge, so
          // long member names never squeeze or push the badge.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(Icons.warning_amber_rounded, size: 20, color: tone.foreground),
              ),
              const SizedBox(width: SpSpacing.sm),
              Expanded(
                child: Text(
                  'Workload imbalance: ${summary.memberName(c.memberId)}',
                  style: theme.textTheme.titleMedium?.copyWith(color: tone.foreground),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: SpSpacing.sm),
              SpSeverityBadge(severity: c.severity),
            ],
          ),
          const SizedBox(height: SpSpacing.sm),
          Text(c.reasons.first, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface)),
          if (c.hasSuggestion && taskTitle != null) ...[
            const SizedBox(height: SpSpacing.xs),
            Text(
              'Suggestion: move "$taskTitle" to ${summary.memberName(c.suggestedAssigneeId)} '
              '(owner approval required).',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: SpSpacing.sm),
          Row(
            children: [
              if (more > 0)
                Text('+$more more conflict${more == 1 ? '' : 's'}', style: theme.textTheme.labelMedium),
              const Spacer(),
              TextButton(
                onPressed: onViewDetails ?? () => _comingSoon(context, 'Workload review'),
                child: const Text('View workload'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _titleOf(String taskId) {
    for (final r in summary.priorityTasks) {
      if (r.task.id == taskId) return r.task.title;
    }
    for (final w in summary.workloads) {
      for (final t in w.activeTasks) {
        if (t.id == taskId) return t.title;
      }
    }
    return null;
  }
}

class KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final SpTone tone;

  const KpiTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StudyPilotCard(
      padding: const EdgeInsets.all(SpSpacing.md),
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(SpRadius.sm)),
              child: Icon(icon, size: 18, color: tone.foreground),
            ),
            const SizedBox(height: SpSpacing.sm),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(label, style: theme.textTheme.labelMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (caption != null)
              Text(caption!, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

class KpiGrid extends StatelessWidget {
  final DashboardSummary summary;
  const KpiGrid({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final tiles = [
      KpiTile(
        icon: Icons.assignment_ind_outlined,
        label: 'Assigned to you',
        value: '${s.myActiveCount}',
        caption: 'Active tasks',
        tone: SpTone.brand(context),
      ),
      KpiTile(
        icon: Icons.today_outlined,
        label: 'Due today',
        value: '${s.dueTodayCount}',
        caption: 'Team tasks',
        tone: s.dueTodayCount > 0 ? SpTone.warning(context) : SpTone.neutral(context),
      ),
      KpiTile(
        icon: Icons.event_busy_outlined,
        label: 'Overdue',
        value: '${s.overdueCount}',
        caption: 'Team tasks',
        tone: s.overdueCount > 0 ? SpTone.danger(context) : SpTone.neutral(context),
      ),
      KpiTile(
        icon: Icons.task_alt_rounded,
        label: 'Completed',
        value: '${s.completedCount}',
        caption: 'of ${s.totalCount} tasks',
        tone: SpTone.success(context),
      ),
    ];

    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 640 ? 4 : 2;
      const gap = SpSpacing.md;
      final width = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [for (final t in tiles) SizedBox(width: width, child: t)],
      );
    });
  }
}

class PriorityTasksSection extends StatelessWidget {
  final DashboardSummary summary;
  final DateTime now;
  const PriorityTasksSection({super.key, required this.summary, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SpSectionHeading(
          title: 'Smart Priority Tasks',
          subtitle: 'Ranked by deadline, priority, effort and checklist',
          icon: Icons.auto_awesome_outlined,
          actionLabel: 'All tasks',
          onAction: () {
            final shell = SpShellScope.maybeOf(context);
            if (shell != null) {
              shell.selectTab(SpTabs.tasks);
            } else {
              _comingSoon(context, 'Task management');
            }
          },
        ),
        if (summary.priorityTasks.isEmpty)
          const StudyPilotCard(child: Text('No active tasks. Nice work!'))
        else
          for (final r in summary.priorityTasks) ...[
            StudyPilotCard(
              padding: const EdgeInsets.all(SpSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SpScoreBadge(score: r.priority.score),
                  const SizedBox(width: SpSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.task.title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: SpSpacing.xs),
                        Wrap(
                          spacing: SpSpacing.xs + 2,
                          runSpacing: SpSpacing.xs,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SpPriorityBadge(priority: r.task.priority),
                            SpStatusBadge(status: r.task.status, showIcon: false),
                            Text(dueLabel(r.task.dueAt, now), style: theme.textTheme.bodySmall),
                          ],
                        ),
                        const SizedBox(height: SpSpacing.xs),
                        Text(
                          r.priority.reasons.take(2).join(' · '),
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: SpSpacing.sm),
                  Tooltip(
                    message: summary.memberName(r.task.assigneeId),
                    child: SpMemberAvatar(
                      name: summary.memberName(r.task.assigneeId),
                      colorSeed: r.task.assigneeId,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpSpacing.sm),
          ],
      ],
    );
  }
}

class WorkloadHealthSection extends StatelessWidget {
  final DashboardSummary summary;
  final VoidCallback? onViewDetails;
  const WorkloadHealthSection({super.key, required this.summary, this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SpSectionHeading(
          title: 'Team Workload Health',
          subtitle: 'Active hours vs ${hoursText(summary.workspace.workloadThresholdHours)} capacity',
          icon: Icons.monitor_heart_outlined,
          actionLabel: onViewDetails == null ? null : 'Details',
          onAction: onViewDetails,
        ),
        StudyPilotCard(
          child: Column(
            children: [
              for (final (i, w) in summary.workloads.indexed) ...[
                if (i > 0) const SizedBox(height: SpSpacing.lg),
                _MemberLoadRow(name: summary.memberName(w.userId), workload: w, theme: theme),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberLoadRow extends StatelessWidget {
  final String name;
  final MemberWorkload workload;
  final ThemeData theme;
  const _MemberLoadRow({required this.name, required this.workload, required this.theme});

  @override
  Widget build(BuildContext context) {
    final w = workload;
    return Row(
      children: [
        SpMemberAvatar(name: name, colorSeed: w.userId, size: 32),
        const SizedBox(width: SpSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(name, style: theme.textTheme.labelLarge, overflow: TextOverflow.ellipsis)),
                  if (w.isCongested)
                    SpBadge(label: 'Deadline crunch', tone: SpTone.danger(context))
                  else if (w.isOverCapacity)
                    SpBadge(label: 'Over capacity', tone: SpTone.warning(context)),
                ],
              ),
              const SizedBox(height: SpSpacing.xs + 2),
              SpProgressBar(
                value: w.loadRatio,
                color: spCapacityColor(w.loadRatio),
                label: '${w.activeTasks.length} active task${w.activeTasks.length == 1 ? '' : 's'}',
                valueText: '${hoursText(w.activeHours)} / ${hoursText(w.thresholdHours)}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class RecentActivitySection extends StatelessWidget {
  final DashboardSummary summary;
  final DateTime now;
  const RecentActivitySection({super.key, required this.summary, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SpSectionHeading(title: 'Recent Team Activity', icon: Icons.history_rounded),
        StudyPilotCard(
          padding: const EdgeInsets.symmetric(vertical: SpSpacing.xs),
          child: summary.recentActivity.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(SpSpacing.lg),
                  child: Text('No activity yet.'),
                )
              : Column(
                  children: [
                    for (final item in summary.recentActivity)
                      ListTile(
                        dense: true,
                        leading: SpMemberAvatar(
                          name: summary.memberName(item.activity.userId),
                          colorSeed: item.activity.userId,
                          size: 30,
                        ),
                        title: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                              text: summary.memberName(item.activity.userId),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: ' ${activityVerb(item.activity.type)} '),
                            TextSpan(
                              text: item.task.title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ]),
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          [
                            if (item.activity.detail.isNotEmpty) item.activity.detail,
                            timeAgo(item.activity.timestamp, now),
                          ].join(' · '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
