import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/core/sp_user.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_sections.dart' show DemoDataBanner;
import 'package:study_app/studypilot/screens/teams/team_forms.dart';
import 'package:study_app/studypilot/screens/teams/teams_cubit.dart';
import 'package:study_app/studypilot/screens/teams/workspace_detail_screen.dart';
import 'package:study_app/studypilot/screens/teams/workspace_overview.dart';

/// Teams tab: the user's workspaces, plus create / join entry points.
class TeamsTab extends StatelessWidget {
  final WorkspaceRepository? repository;
  final String? userId;

  const TeamsTab({super.key, this.repository, this.userId});

  @override
  Widget build(BuildContext context) {
    final uid = userId ?? SpUserScope.of(context).uid;
    final repo = repository ?? context.read<WorkspaceRepository>();
    return BlocProvider(
      create: (_) => TeamsCubit(repository: repo, userId: uid)..load(),
      child: _TeamsView(userId: uid),
    );
  }
}

class _TeamsView extends StatelessWidget {
  final String userId;
  const _TeamsView({required this.userId});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<TeamsCubit>();
    return BlocBuilder<TeamsCubit, TeamsState>(
      builder: (context, state) => switch (state) {
        TeamsLoading() => const Center(child: CircularProgressIndicator()),
        TeamsError(:final message) => SpEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Something went wrong',
          message: message,
          actionLabel: 'Try again',
          onAction: cubit.load,
        ),
        TeamsReady() => RefreshIndicator(
          onRefresh: cubit.load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(SpSpacing.lg, SpSpacing.lg, SpSpacing.lg, SpSpacing.xxl),
            children: [
              // On phones the shell's app bar already reads "Team Workspaces";
              // only wide layouts (app bar shows the brand) need this heading.
              if (MediaQuery.sizeOf(context).width >= SpBreakpoints.navigationRail) ...[
                Text('Team Workspaces', style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: SpSpacing.xs),
              ],
              Text('Your teams, their projects and members.', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: SpSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showCreateWorkspaceSheet(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Create'),
                    ),
                  ),
                  const SizedBox(width: SpSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showJoinWorkspaceSheet(context, mine: state.workspaces),
                      icon: const Icon(Icons.vpn_key_outlined, size: 18),
                      label: const Text('Join with code'),
                    ),
                  ),
                ],
              ),
              if (state.isDemo) ...[const SizedBox(height: SpSpacing.md), const DemoDataBanner()],
              const SizedBox(height: SpSpacing.lg),
              if (state.workspaces.isEmpty)
                const SizedBox(
                  height: 320,
                  child: SpEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No workspaces yet',
                    message: 'Create a workspace for your team or join one with an invite code.',
                  ),
                )
              else
                for (final w in state.workspaces) ...[
                  _WorkspaceCard(
                    overview: w,
                    userId: userId,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => WorkspaceDetailScreen(overview: w, userId: userId, isDemo: state.isDemo),
                      ),
                    ),
                  ),
                  const SizedBox(height: SpSpacing.md),
                ],
            ],
          ),
        ),
      },
    );
  }
}

class _WorkspaceCard extends StatelessWidget {
  final WorkspaceOverview overview;
  final String userId;
  final VoidCallback onTap;
  const _WorkspaceCard({required this.overview, required this.userId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ws = overview.workspace;
    final role = overview.roleOf(userId);
    return StudyPilotCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(SpRadius.md),
                ),
                child: Icon(
                  ws.type == WorkspaceType.universityProject ? Icons.school_outlined : Icons.storefront_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: SpSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ws.name, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(
                      workspaceTypeLabel(ws.type),
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (role != null) SpRoleBadge(role: role),
            ],
          ),
          const SizedBox(height: SpSpacing.md),
          Row(
            children: [
              SpAvatarStack(
                members: [for (final m in ws.members) (name: m.displayName, id: m.userId, photoUrl: null)],
                maxVisible: 4,
                size: 26,
              ),
              const SizedBox(width: SpSpacing.sm),
              Expanded(
                child: Text(
                  '${ws.members.length} members · ${overview.projects.length} projects · '
                  '${overview.activeTaskCount} active tasks',
                  style: theme.textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ],
      ),
    );
  }
}
