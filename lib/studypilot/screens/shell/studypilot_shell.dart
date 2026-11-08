import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/core/sp_user.dart';
import 'package:study_app/studypilot/core/workspace_selection.dart';
import 'package:study_app/studypilot/data/demo_workspace_repository.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_tab.dart';
import 'package:study_app/studypilot/screens/tasks/tasks_tab.dart';
import 'package:study_app/studypilot/screens/teams/teams_tab.dart';
import 'package:study_app/studypilot/core/sp_shell_scope.dart';
import 'package:study_app/studypilot/screens/profile/sp_profile_tab.dart';
import 'package:study_app/studypilot/screens/shell/sp_placeholder_tab.dart';

/// One top-level StudyPilot destination (prototype BottomNav / Sidebar).
class _SpDestination {
  final String label;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  const _SpDestination(this.label, this.title, this.icon, this.selectedIcon);
}

const _destinations = [
  _SpDestination('Home', 'Dashboard', Icons.home_outlined, Icons.home_rounded),
  _SpDestination('Teams', 'Team Workspaces', Icons.apartment_outlined, Icons.apartment_rounded),
  _SpDestination('Tasks', 'Tasks', Icons.check_box_outlined, Icons.check_box_rounded),
  _SpDestination('Reports', 'Reports & Analytics', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
  _SpDestination('Profile', 'Profile', Icons.person_outline_rounded, Icons.person_rounded),
];

/// StudyPilot app shell: bottom NavigationBar on phones, NavigationRail on
/// wide screens (web/tablet). Tabs keep their state via IndexedStack.
class StudyPilotShell extends StatefulWidget {
  /// Test hooks (tests run without Firebase): the signed-in user, the data
  /// source, and the Profile tab (which reads Firebase directly).
  @visibleForTesting
  final SpUserInfo? userOverride;
  @visibleForTesting
  final WorkspaceRepository? repositoryOverride;
  @visibleForTesting
  final Widget? profileTabOverride;

  const StudyPilotShell({super.key, this.userOverride, this.repositoryOverride, this.profileTabOverride});

  /// Width at which the rail replaces the bottom bar (Material 3 "medium").
  static const double railBreakpoint = SpBreakpoints.navigationRail;

  @override
  State<StudyPilotShell> createState() => _StudyPilotShellState();
}

class _StudyPilotShellState extends State<StudyPilotShell> {
  int _index = 0;

  late final SpUserInfo _user = widget.userOverride ?? _userFromFirebase();

  /// One shared data source for all StudyPilot tabs. Demo data until the
  /// Firestore implementation is added.
  late final WorkspaceRepository _repository =
      widget.repositoryOverride ??
      DemoWorkspaceRepository(currentUserId: _user.uid, currentUserName: _user.displayName);

  /// The one shared selected workspace for Home, Tasks and Workload Insights.
  final WorkspaceSelectionCubit _selection = WorkspaceSelectionCubit();

  @override
  void dispose() {
    _selection.close();
    super.dispose();
  }

  static SpUserInfo _userFromFirebase() {
    final u = FirebaseAuth.instance.currentUser;
    final name = (u?.displayName?.trim().isNotEmpty ?? false)
        ? u!.displayName!.trim()
        : (u?.email?.split('@').first ?? 'You');
    return SpUserInfo(uid: u?.uid ?? '', displayName: name);
  }

  late final List<Widget> _tabs = [
    const DashboardTab(),
    const TeamsTab(),
    const TasksTab(),
    const SpPlaceholderTab(
      icon: Icons.insights_rounded,
      title: 'Reports coming soon',
      message: 'Workload conflicts, team analytics and PDF report export will appear here.',
    ),
    widget.profileTabOverride ?? const SpProfileTab(),
  ];

  void _select(int i) => setState(() => _index = i);

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Notifications')),
          body: const SpPlaceholderTab(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications coming soon',
            message: 'Task assignments, deadline reminders and workload alerts will appear here.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = _destinations[_index];

    return SpUserScope(
      user: _user,
      child: SpShellScope(
        selectTab: _select,
        child: RepositoryProvider<WorkspaceRepository>.value(
          value: _repository,
          child: BlocProvider<WorkspaceSelectionCubit>.value(value: _selection, child: _buildLayout(theme, current)),
        ),
      ),
    );
  }

  Widget _buildLayout(ThemeData theme, _SpDestination current) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= StudyPilotShell.railBreakpoint;

        final appBar = AppBar(
          titleSpacing: SpSpacing.lg,
          title: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(SpRadius.sm),
                ),
                child: Icon(Icons.rocket_launch_rounded, size: 18, color: theme.colorScheme.onPrimary),
              ),
              const SizedBox(width: SpSpacing.sm + 2),
              Flexible(child: Text(wide ? SpBrand.appName : current.title, overflow: TextOverflow.ellipsis)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_none_rounded),
              onPressed: _openNotifications,
            ),
            const SizedBox(width: SpSpacing.xs),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ),
        );

        final body = IndexedStack(index: _index, children: _tabs);

        if (wide) {
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: _select,
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: theme.colorScheme.surface,
                  indicatorColor: theme.colorScheme.primaryContainer,
                  destinations: [
                    for (final d in _destinations)
                      NavigationRailDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: Text(d.label),
                      ),
                  ],
                ),
                VerticalDivider(width: 1, color: theme.colorScheme.outlineVariant),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
            ),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              destinations: [
                for (final d in _destinations)
                  NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
              ],
            ),
          ),
        );
      },
    );
  }
}
