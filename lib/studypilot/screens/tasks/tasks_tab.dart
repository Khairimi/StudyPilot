import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/core/sp_user.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/logic/task_permissions.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_sections.dart' show DemoDataBanner, WorkspaceSelector;
import 'package:study_app/studypilot/screens/tasks/task_card.dart';
import 'package:study_app/studypilot/screens/tasks/task_detail_screen.dart';
import 'package:study_app/studypilot/screens/tasks/task_filter.dart';
import 'package:study_app/studypilot/screens/tasks/task_forms.dart';
import 'package:study_app/studypilot/screens/tasks/tasks_cubit.dart';

/// Tasks tab: List (ranked by Smart Priority) and Board (by status) views
/// with search and filters. Uses the shell's shared repository by default.
class TasksTab extends StatelessWidget {
  final WorkspaceRepository? repository;
  final String? userId;
  final DateTime Function()? clock;

  const TasksTab({super.key, this.repository, this.userId, this.clock});

  @override
  Widget build(BuildContext context) {
    final uid = userId ?? SpUserScope.of(context).uid;
    final repo = repository ?? context.read<WorkspaceRepository>();
    return BlocProvider(
      create: (_) => TasksCubit(repository: repo, userId: uid, clock: clock)..load(),
      child: _TasksView(userId: uid),
    );
  }
}

class _TasksView extends StatelessWidget {
  final String userId;
  const _TasksView({required this.userId});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TasksCubit>();
    return BlocBuilder<TasksCubit, TasksState>(
      builder: (context, state) => switch (state) {
        TasksLoading() => const Center(child: CircularProgressIndicator()),
        TasksError(:final message) => SpEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Something went wrong',
          message: message,
          actionLabel: 'Try again',
          onAction: cubit.load,
        ),
        TasksNoWorkspaces() => const SpEmptyState(
          icon: Icons.task_alt_rounded,
          title: 'No workspaces yet',
          message: 'Join or create a team workspace in Teams to manage tasks.',
        ),
        TasksReady() => _ReadyView(state: state, userId: userId),
      },
    );
  }
}

class _ReadyView extends StatelessWidget {
  final TasksReady state;
  final String userId;
  const _ReadyView({required this.state, required this.userId});

  void _openTask(BuildContext context, TeamTask task, DateTime now) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          workspace: state.workspace,
          projects: state.projects,
          allTasks: state.allTasks,
          currentUserId: userId,
          now: now,
          isDemo: state.isDemo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TasksCubit>();
    final now = cubit.clock();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: !TaskPermissions(state.workspace, userId).canCreate
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showTaskFormSheet(
                context,
                workspace: state.workspace,
                projects: state.projects,
                currentUserId: userId,
                now: now,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New task'),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(SpSpacing.lg, SpSpacing.md, SpSpacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSelector(
                  workspaces: state.workspaces,
                  selected: state.workspace,
                  onSelected: cubit.selectWorkspace,
                ),
                if (state.isDemo) ...[const SizedBox(height: SpSpacing.sm), const DemoDataBanner()],
                const SizedBox(height: SpSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: cubit.setQuery,
                        decoration: const InputDecoration(
                          hintText: 'Search tasks',
                          prefixIcon: Icon(Icons.search_rounded),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: SpSpacing.sm),
                    IconButton.outlined(
                      tooltip: 'Filters',
                      onPressed: () => _showFilterSheet(context, state),
                      icon: Badge(
                        isLabelVisible: state.filter.activeCount > 0,
                        label: Text('${state.filter.activeCount}'),
                        child: const Icon(Icons.tune_rounded),
                      ),
                    ),
                    const SizedBox(width: SpSpacing.xs),
                    IconButton.outlined(
                      tooltip: state.mode == TaskViewMode.list ? 'Board view' : 'List view',
                      onPressed: () =>
                          cubit.setMode(state.mode == TaskViewMode.list ? TaskViewMode.board : TaskViewMode.list),
                      icon: Icon(
                        state.mode == TaskViewMode.list ? Icons.view_kanban_outlined : Icons.view_list_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${state.visible.length} of ${state.allTasks.length} tasks · '
                        '${state.mode == TaskViewMode.list ? 'ranked by Smart Priority' : 'by status'}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (state.filter.activeCount > 0)
                      TextButton(onPressed: cubit.clearFilters, child: const Text('Clear filters')),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: state.visible.isEmpty
                ? const SpEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No matching tasks',
                    message: 'Try a different search or clear the filters.',
                  )
                : state.mode == TaskViewMode.list
                ? _ListView(state: state, now: now, onOpen: (t) => _openTask(context, t, now))
                : _BoardView(state: state, now: now, onOpen: (t) => _openTask(context, t, now)),
          ),
        ],
      ),
    );
  }
}

class _ListView extends StatelessWidget {
  final TasksReady state;
  final DateTime now;
  final ValueChanged<TeamTask> onOpen;
  const _ListView({required this.state, required this.now, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(SpSpacing.lg, SpSpacing.sm, SpSpacing.lg, 96),
      itemCount: state.visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: SpSpacing.sm),
      itemBuilder: (context, i) {
        final t = state.visible[i];
        return TaskCard(
          task: t,
          now: now,
          assigneeName: state.memberName(t.assigneeId),
          projectName: state.projectName(t.projectId),
          onTap: () => onOpen(t),
        );
      },
    );
  }
}

class _BoardView extends StatelessWidget {
  final TasksReady state;
  final DateTime now;
  final ValueChanged<TeamTask> onOpen;
  const _BoardView({required this.state, required this.now, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final columns = groupByStatus(state.visible);
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final columnWidth = (c.maxWidth * 0.82).clamp(240.0, 320.0);
        return ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(SpSpacing.lg, SpSpacing.sm, SpSpacing.lg, SpSpacing.lg),
          children: [
            for (final entry in columns.entries)
              Container(
                width: columnWidth,
                margin: const EdgeInsets.only(right: SpSpacing.md),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: SpRadius.card),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(SpSpacing.md),
                      child: Row(
                        children: [
                          SpStatusBadge(status: entry.key),
                          const Spacer(),
                          Text('${entry.value.length}', style: theme.textTheme.labelLarge),
                        ],
                      ),
                    ),
                    Expanded(
                      child: entry.value.isEmpty
                          ? Center(child: Text('No tasks', style: theme.textTheme.bodySmall))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(SpSpacing.sm, 0, SpSpacing.sm, 96),
                              itemCount: entry.value.length,
                              separatorBuilder: (_, _) => const SizedBox(height: SpSpacing.sm),
                              itemBuilder: (context, i) {
                                final t = entry.value[i];
                                return TaskCard(
                                  task: t,
                                  now: now,
                                  assigneeName: state.memberName(t.assigneeId),
                                  compact: true,
                                  onTap: () => onOpen(t),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Real (view-only) filtering; nothing here changes data.
Future<void> _showFilterSheet(BuildContext context, TasksReady state) {
  final cubit = context.read<TasksCubit>();
  var draft = state.filter;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final theme = Theme.of(ctx);
        Widget label(String s) => Padding(
          padding: const EdgeInsets.only(top: SpSpacing.lg, bottom: SpSpacing.xs),
          child: Text(s, style: theme.textTheme.labelLarge),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(SpSpacing.xl, 0, SpSpacing.xl, SpSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Filter tasks', style: theme.textTheme.titleLarge),
              label('Show'),
              Wrap(
                spacing: SpSpacing.sm,
                children: [
                  for (final (scope, text) in [
                    (TaskScope.all, 'All tasks'),
                    (TaskScope.mine, 'Assigned to me'),
                    (TaskScope.unassigned, 'Unassigned'),
                  ])
                    ChoiceChip(
                      label: Text(text),
                      selected: draft.scope == scope,
                      onSelected: (_) => setSheet(() => draft = draft.copyWith(scope: scope)),
                    ),
                ],
              ),
              label('Project'),
              Wrap(
                spacing: SpSpacing.sm,
                runSpacing: SpSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('Any'),
                    selected: draft.projectId == null,
                    onSelected: (_) => setSheet(() => draft = draft.copyWith(projectId: null)),
                  ),
                  for (final p in state.projects)
                    ChoiceChip(
                      label: Text(p.title),
                      selected: draft.projectId == p.id,
                      onSelected: (_) => setSheet(() => draft = draft.copyWith(projectId: p.id)),
                    ),
                ],
              ),
              label('Priority'),
              Wrap(
                spacing: SpSpacing.sm,
                runSpacing: SpSpacing.xs,
                children: [
                  for (final p in SpPriority.values)
                    FilterChip(
                      label: Text(p.label),
                      selected: draft.priorities.contains(p),
                      onSelected: (on) => setSheet(
                        () => draft = draft.copyWith(
                          priorities: on ? {...draft.priorities, p} : ({...draft.priorities}..remove(p)),
                        ),
                      ),
                    ),
                ],
              ),
              label('Status'),
              Wrap(
                spacing: SpSpacing.sm,
                runSpacing: SpSpacing.xs,
                children: [
                  for (final s in SpTaskStatus.values)
                    FilterChip(
                      label: Text(s.label),
                      selected: draft.statuses.contains(s),
                      onSelected: (on) => setSheet(
                        () => draft = draft.copyWith(
                          statuses: on ? {...draft.statuses, s} : ({...draft.statuses}..remove(s)),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: SpSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setSheet(() => draft = TaskFilter(query: draft.query)),
                      child: const Text('Reset'),
                    ),
                  ),
                  const SizedBox(width: SpSpacing.md),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        cubit.setFilter(draft);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ),
  );
}
