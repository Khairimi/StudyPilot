import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';
import 'package:study_app/studypilot/screens/teams/team_forms.dart';
import 'package:study_app/studypilot/screens/teams/workspace_overview.dart';

/// Workspace details: about + invite code, projects, members and roles.
/// Owner-only actions are shown to owners and run in demo mode.
class WorkspaceDetailScreen extends StatelessWidget {
  final WorkspaceOverview overview;
  final String userId;
  final bool isDemo;

  /// Opens the Tasks tab filtered by a project. When null, project cards
  /// are not interactive.
  final ValueChanged<String>? onOpenProject;

  const WorkspaceDetailScreen({
    super.key,
    required this.overview,
    required this.userId,
    required this.isDemo,
    this.onOpenProject,
  });

  @override
  Widget build(BuildContext context) {
    final ws = overview.workspace;
    final isOwner = overview.isOwner(userId);
    return Scaffold(
      appBar: AppBar(title: Text(ws.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(SpSpacing.lg, SpSpacing.md, SpSpacing.lg, SpSpacing.xxl),
        children: [
          if (isDemo) ...[
            const SpDemoModeBanner(message: 'Demo workspace: changes here are not saved.'),
            const SizedBox(height: SpSpacing.md),
          ],
          _AboutCard(overview: overview, userId: userId),
          const SizedBox(height: SpSpacing.xl),
          SpSectionHeading(
            title: 'Projects',
            subtitle: '${overview.projects.length} shared project${overview.projects.length == 1 ? '' : 's'}',
            icon: Icons.folder_outlined,
            actionLabel: isOwner ? 'New project (demo)' : null,
            onAction: isOwner
                ? () => showDemoNotice(context, 'project creation will be enabled with Firebase integration.')
                : null,
          ),
          if (overview.projects.isEmpty)
            const StudyPilotCard(child: Text('No projects yet.'))
          else
            for (final p in overview.projects) ...[
              _ProjectCard(project: p, overview: overview, onOpen: onOpenProject),
              const SizedBox(height: SpSpacing.sm),
            ],
          const SizedBox(height: SpSpacing.xl),
          SpSectionHeading(
            title: 'Members',
            subtitle: '${ws.members.length} people',
            icon: Icons.people_outline_rounded,
            actionLabel: isOwner ? 'Invite' : null,
            onAction: isOwner ? () => showInviteMemberSheet(context, workspace: ws) : null,
          ),
          StudyPilotCard(
            padding: const EdgeInsets.symmetric(vertical: SpSpacing.xs),
            child: Column(
              children: [
                for (final m in overview.sortedMembers)
                  _MemberTile(member: m, overview: overview, userId: userId, canManage: isOwner),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  final WorkspaceOverview overview;
  final String userId;
  const _AboutCard({required this.overview, required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ws = overview.workspace;
    final role = overview.roleOf(userId);
    return StudyPilotCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(workspaceTypeLabel(ws.type), style: theme.textTheme.labelLarge)),
              if (role != null) SpRoleBadge(role: role),
            ],
          ),
          if (ws.description.isNotEmpty) ...[
            const SizedBox(height: SpSpacing.sm),
            Text(ws.description, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: SpSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite code', style: theme.textTheme.bodySmall),
                    Text(
                      ws.inviteCode,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Copy invite code',
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: ws.inviteCode));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(const SnackBar(content: Text('Invite code copied')));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final WorkspaceOverview overview;
  final ValueChanged<String>? onOpen;
  const _ProjectCard({required this.project, required this.overview, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = overview.tasksOf(project.id);
    final done = tasks.where((t) => t.isCompleted).length;
    final status = switch (project.status) {
      ProjectStatus.active => (label: 'Active', tone: SpTone.brand(context)),
      ProjectStatus.onHold => (label: 'On hold', tone: SpTone.warning(context)),
      ProjectStatus.completed => (label: 'Completed', tone: SpTone.success(context)),
    };
    final open = onOpen;
    return StudyPilotCard(
      onTap: open == null
          ? null
          : () {
              Navigator.of(context).pop();
              open(project.id);
            },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(project.title, style: theme.textTheme.titleMedium)),
              SpBadge(label: status.label, tone: status.tone),
            ],
          ),
          if (project.dueDate != null) ...[
            const SizedBox(height: SpSpacing.xs),
            Text(_projectDue(project.dueDate!), style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: SpSpacing.md),
          SpProgressBar(value: overview.progressOf(project.id), label: '$done of ${tasks.length} tasks done'),
          if (open != null) ...[
            const SizedBox(height: SpSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('View tasks', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                Icon(Icons.chevron_right_rounded, size: 18, color: theme.colorScheme.primary),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _projectDue(DateTime d) =>
      'Due ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _MemberTile extends StatelessWidget {
  final WorkspaceMember member;
  final WorkspaceOverview overview;
  final String userId;
  final bool canManage;
  const _MemberTile({required this.member, required this.overview, required this.userId, required this.canManage});

  @override
  Widget build(BuildContext context) {
    final isMe = member.userId == userId;
    final active = overview.activeTasksFor(member.userId);
    return ListTile(
      leading: SpMemberAvatar(name: member.displayName, colorSeed: member.userId, size: 36),
      title: Text(isMe ? '${member.displayName} (you)' : member.displayName),
      subtitle: Text('$active active task${active == 1 ? '' : 's'}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SpRoleBadge(role: member.role),
          if (canManage && !isMe)
            PopupMenuButton<String>(
              tooltip: 'Manage ${member.displayName}',
              onSelected: (action) => showDemoNotice(
                context,
                action == 'role'
                    ? 'the role of ${member.displayName} was not changed.'
                    : '${member.displayName} was not removed.',
              ),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'role', child: Text(member.isOwner ? 'Make member (demo)' : 'Make owner (demo)')),
                const PopupMenuItem(value: 'remove', child: Text('Remove from workspace (demo)')),
              ],
            ),
        ],
      ),
    );
  }
}
