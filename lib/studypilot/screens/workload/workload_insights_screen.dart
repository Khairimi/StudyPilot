import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/logic/workload_engine.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_sections.dart'
    show DemoDataBanner, KpiTile, WorkspaceSelector;
import 'package:study_app/studypilot/screens/workload/reassignment_preview.dart';
import 'package:study_app/studypilot/screens/workload/reassignment_review_sheet.dart';
import 'package:study_app/studypilot/screens/workload/workload_cubit.dart';

/// Workload Insights: member capacity, deadline congestion / overload
/// conflicts with explanations, and owner-only reassignment review.
/// Pushed as its own route, so the repository and user are passed in.
class WorkloadInsightsScreen extends StatelessWidget {
  final WorkspaceRepository repository;
  final String userId;
  final String? workspaceId;
  final DateTime Function()? clock;

  const WorkloadInsightsScreen({
    super.key,
    required this.repository,
    required this.userId,
    this.workspaceId,
    this.clock,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WorkloadCubit(repository: repository, userId: userId, clock: clock)
        ..load(workspaceId: workspaceId),
      child: Scaffold(
        appBar: AppBar(title: const Text('Workload Insights')),
        body: BlocBuilder<WorkloadCubit, WorkloadState>(
          builder: (context, state) => switch (state) {
            WorkloadLoading() => const Center(child: CircularProgressIndicator()),
            WorkloadError(:final message) => SpEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Something went wrong',
                message: message,
                actionLabel: 'Try again',
                onAction: () => context.read<WorkloadCubit>().load(workspaceId: workspaceId),
              ),
            WorkloadNoWorkspaces() => const SpEmptyState(
                icon: Icons.groups_outlined,
                title: 'No workspaces yet',
                message: 'Join a team workspace to see workload insights.',
              ),
            WorkloadReady() => _ReadyView(state: state, userId: userId),
          },
        ),
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  final WorkloadReady state;
  final String userId;
  const _ReadyView({required this.state, required this.userId});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<WorkloadCubit>();
    final now = cubit.clock();
    final s = state;
    final high = s.conflicts.where((c) => c.severity == SpSeverity.high).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(SpSpacing.lg, SpSpacing.md, SpSpacing.lg, SpSpacing.xxl),
      children: [
        WorkspaceSelector(workspaces: s.workspaces, selected: s.workspace, onSelected: cubit.selectWorkspace),
        if (s.isDemo) ...[
          const SizedBox(height: SpSpacing.sm),
          const DemoDataBanner(),
        ],
        const SizedBox(height: SpSpacing.lg),
        LayoutBuilder(builder: (context, c) {
          const gap = SpSpacing.md;
          final columns = c.maxWidth >= 640 ? 3 : 2;
          final w = (c.maxWidth - gap * (columns - 1)) / columns;
          final tiles = [
            KpiTile(
              icon: Icons.warning_amber_rounded,
              label: 'Conflicts',
              value: '${s.conflicts.length}',
              caption: '$high high severity',
              tone: s.conflicts.isEmpty ? SpTone.success(context) : SpTone.danger(context),
            ),
            KpiTile(
              icon: Icons.battery_alert_outlined,
              label: 'Over capacity',
              value: '${s.membersOverCapacity}',
              caption: 'of ${s.workloads.length} members',
              tone: s.membersOverCapacity == 0 ? SpTone.neutral(context) : SpTone.warning(context),
            ),
            KpiTile(
              icon: Icons.schedule_rounded,
              label: 'Team load',
              value: hoursText(s.teamHours),
              caption: 'of ${hoursText(s.teamCapacity)} capacity',
              tone: SpTone.brand(context),
            ),
          ];
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (final t in tiles) SizedBox(width: w, child: t)],
          );
        }),
        const SizedBox(height: SpSpacing.xl),
        SpSectionHeading(
          title: 'Conflicts',
          subtitle: s.isOwner
              ? 'Review suggested reassignments before anything changes'
              : 'Only workspace owners can review reassignments',
          icon: Icons.report_gmailerrorred_rounded,
        ),
        if (s.conflicts.isEmpty)
          StudyPilotCard(
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: SpTone.success(context).foreground),
                const SizedBox(width: SpSpacing.sm),
                const Expanded(child: Text('No workload conflicts. The team is balanced.')),
              ],
            ),
          )
        else
          for (final c in s.conflicts) ...[
            _ConflictCard(conflict: c, state: s, userId: userId, now: now),
            const SizedBox(height: SpSpacing.md),
          ],
        const SizedBox(height: SpSpacing.lg),
        SpSectionHeading(
          title: 'Member capacity',
          subtitle: 'Active hours vs ${hoursText(s.workspace.workloadThresholdHours)} each',
          icon: Icons.monitor_heart_outlined,
        ),
        StudyPilotCard(
          child: Column(
            children: [
              for (final (i, w) in s.workloads.indexed) ...[
                if (i > 0) const SizedBox(height: SpSpacing.lg),
                _CapacityRow(workload: w, name: s.memberName(w.userId), isMe: w.userId == userId),
              ],
            ],
          ),
        ),
        const SizedBox(height: SpSpacing.xl),
        const _HowItWorks(),
      ],
    );
  }
}

class _ConflictCard extends StatelessWidget {
  final WorkloadConflict conflict;
  final WorkloadReady state;
  final String userId;
  final DateTime now;
  const _ConflictCard({required this.conflict, required this.state, required this.userId, required this.now});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = conflict;
    final tone = c.severity.tone(context);
    final name = state.memberName(c.memberId);
    final preview = ReassignmentPreview.of(c, state.workloads, state.tasks);
    final typeLabel = c.type == ConflictType.deadlineCongestion ? 'Deadline congestion' : 'Capacity overload';

    return StudyPilotCard(
      accentColor: tone.foreground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SpMemberAvatar(name: name, colorSeed: c.memberId, size: 32),
              const SizedBox(width: SpSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.memberId == userId ? '$name (you)' : name,
                        style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(typeLabel, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: SpSpacing.sm),
              SpSeverityBadge(severity: c.severity),
            ],
          ),
          const SizedBox(height: SpSpacing.md),
          for (final r in c.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: SpSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(r, style: theme.textTheme.bodyMedium)),
                ],
              ),
            ),
          const SizedBox(height: SpSpacing.sm),
          Text('Tasks involved', style: theme.textTheme.labelLarge),
          const SizedBox(height: SpSpacing.xs),
          for (final id in c.taskIds)
            if (state.taskById(id) case final t?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: SpSpacing.xxs),
                child: Row(
                  children: [
                    Expanded(child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: SpSpacing.sm),
                    Text(dueLabel(t.dueAt, now), style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
          if (preview != null) ...[
            const SizedBox(height: SpSpacing.md),
            Container(
              padding: const EdgeInsets.all(SpSpacing.md),
              decoration: BoxDecoration(color: SpTone.brand(context).background, borderRadius: SpRadius.control),
              child: Text(
                'Suggestion: move "${preview.task.title}" (${hoursText(preview.taskHours)}) to '
                '${state.memberName(preview.to.userId)} '
                '(${hoursText(preview.to.activeHours)} → ${hoursText(preview.toHoursAfter)} of '
                '${hoursText(preview.threshold)}).',
                style: theme.textTheme.bodyMedium?.copyWith(color: SpTone.brand(context).foreground),
              ),
            ),
          ],
          const SizedBox(height: SpSpacing.md),
          if (preview != null && state.isOwner)
            FilledButton.icon(
              onPressed: () => showReassignmentReview(
                context,
                preview: preview,
                memberName: state.memberName,
                now: now,
              ),
              icon: const Icon(Icons.rule_rounded, size: 18),
              label: const Text('Review reassignment'),
            )
          else if (preview != null)
            Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: SpSpacing.xs),
                Expanded(
                  child: Text('Only the workspace owner can approve reassignments.',
                      style: theme.textTheme.bodySmall),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CapacityRow extends StatelessWidget {
  final MemberWorkload workload;
  final String name;
  final bool isMe;
  const _CapacityRow({required this.workload, required this.name, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final w = workload;
    final ratio = w.loadRatio;
    final (String label, SpTone tone) = w.isCongested
        ? ('Deadline crunch', SpTone.danger(context))
        : w.isOverCapacity
            ? ('Over capacity', SpTone.warning(context))
            : ratio >= 0.7
                ? ('Near capacity', SpTone.info(context))
                : ('Healthy', SpTone.success(context));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SpMemberAvatar(name: name, colorSeed: w.userId, size: 32),
        const SizedBox(width: SpSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(isMe ? '$name (you)' : name,
                        style: theme.textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: SpSpacing.sm),
                  SpBadge(label: label, tone: tone),
                ],
              ),
              const SizedBox(height: SpSpacing.xs + 2),
              SpProgressBar(
                value: ratio,
                color: spCapacityColor(ratio),
                label: '${w.activeTasks.length} active · ${w.dueSoonTasks.length} due within '
                    '${WorkloadEngine.congestionWindowDays} days',
                valueText: '${hoursText(w.activeHours)} / ${hoursText(w.thresholdHours)}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const rules = [
      'Deadline congestion: ${WorkloadEngine.congestionTaskCount} or more active tasks due within '
          '${WorkloadEngine.congestionWindowDays} days (including overdue) is high severity.',
      'Capacity overload: active hours at or above the workspace capacity is medium severity; '
          '1.5× capacity is high.',
      'Suggestions move the least urgent task to the least loaded teammate who stays under capacity.',
      'Nothing is reassigned automatically. Only owners can approve a reassignment.',
    ];
    return StudyPilotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('How detection works', style: theme.textTheme.titleMedium),
          const SizedBox(height: SpSpacing.sm),
          for (final r in rules)
            Padding(
              padding: const EdgeInsets.only(bottom: SpSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  '),
                  Expanded(child: Text(r, style: theme.textTheme.bodySmall)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
