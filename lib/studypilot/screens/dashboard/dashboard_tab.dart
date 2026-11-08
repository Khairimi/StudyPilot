import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/core/sp_user.dart';
import 'package:study_app/studypilot/core/workspace_selection.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_cubit.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_sections.dart';
import 'package:study_app/studypilot/screens/workload/workload_insights_screen.dart';

/// StudyPilot Home dashboard (Phase 4). Uses the shell's shared repository
/// (demo data until Firestore integration); inputs are injectable for tests.
class DashboardTab extends StatelessWidget {
  final WorkspaceRepository? repository;
  final String? userId;
  final String? userName;
  final DateTime Function()? clock;

  /// Shared selection; defaults to the shell's (none when standalone).
  final WorkspaceSelectionCubit? selection;

  const DashboardTab({super.key, this.repository, this.userId, this.userName, this.clock, this.selection});

  @override
  Widget build(BuildContext context) {
    // Defaults come from the shell (SpUserScope + shared repository).
    final scopeUser = userId == null || userName == null ? SpUserScope.of(context) : null;
    final uid = userId ?? scopeUser!.uid;
    final name = userName ?? scopeUser!.displayName;
    final repo = repository ?? context.read<WorkspaceRepository>();

    return BlocProvider(
      create: (_) => DashboardCubit(
        repository: repo,
        userId: uid,
        clock: clock,
        selection: selection ?? context.read<WorkspaceSelectionCubit?>(),
      )..load(),
      child: _DashboardView(userName: name),
    );
  }
}

class _DashboardView extends StatelessWidget {
  final String userName;
  const _DashboardView({required this.userName});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) => switch (state) {
        DashboardLoading() => const Center(child: CircularProgressIndicator()),
        DashboardError(:final message) => SpEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Something went wrong',
          message: message,
          actionLabel: 'Try again',
          onAction: cubit.load,
        ),
        DashboardNoWorkspaces() => const SpEmptyState(
          icon: Icons.groups_outlined,
          title: 'No workspaces yet',
          message: 'Create or join a team workspace to see your dashboard.',
        ),
        DashboardReady() => _ReadyView(state: state, userName: userName, now: cubit.clock()),
      },
    );
  }
}

class _ReadyView extends StatelessWidget {
  final DashboardReady state;
  final String userName;
  final DateTime now;
  const _ReadyView({required this.state, required this.userName, required this.now});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    final theme = Theme.of(context);
    final s = state.summary;

    return RefreshIndicator(
      onRefresh: () => cubit.load(workspaceId: s.workspace.id),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          const gap = SizedBox(height: SpSpacing.xl);

          void openWorkload() => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WorkloadInsightsScreen(
                repository: cubit.repository,
                userId: cubit.userId,
                workspaceId: s.workspace.id,
                clock: cubit.clock,
                selection: cubit.selection,
              ),
            ),
          );

          final priority = PriorityTasksSection(summary: s, now: now);
          final workload = WorkloadHealthSection(summary: s, onViewDetails: openWorkload);

          return ListView(
            padding: const EdgeInsets.fromLTRB(SpSpacing.lg, SpSpacing.lg, SpSpacing.lg, SpSpacing.xxl),
            children: [
              Text('${greeting(now)}, ${firstName(userName)}', style: theme.textTheme.displaySmall),
              const SizedBox(height: SpSpacing.xs),
              Text('Here is how your team is doing today.', style: theme.textTheme.bodyMedium),
              const SizedBox(height: SpSpacing.lg),
              WorkspaceSelector(workspaces: state.workspaces, selected: s.workspace, onSelected: cubit.selectWorkspace),
              if (state.isDemo) ...[const SizedBox(height: SpSpacing.sm), const DemoDataBanner()],
              if (s.conflicts.isNotEmpty) ...[
                const SizedBox(height: SpSpacing.lg),
                WorkloadAlertCard(summary: s, onViewDetails: openWorkload),
              ],
              const SizedBox(height: SpSpacing.lg),
              KpiGrid(summary: s),
              gap,
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: priority),
                    const SizedBox(width: SpSpacing.xl),
                    Expanded(flex: 2, child: workload),
                  ],
                )
              else ...[
                priority,
                gap,
                workload,
              ],
              gap,
              RecentActivitySection(summary: s, now: now),
            ],
          );
        },
      ),
    );
  }
}
