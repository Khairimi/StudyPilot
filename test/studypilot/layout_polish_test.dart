import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/data/demo_workspace_repository.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_tab.dart';
import 'package:study_app/studypilot/screens/teams/teams_tab.dart';

final fixedNow = DateTime(2026, 11, 10, 9);

/// Demo data with very long workspace and member names.
class _LongNamesRepo implements WorkspaceRepository {
  final _inner = DemoWorkspaceRepository(
      currentUserId: 'me', currentUserName: 'Khairi Rahimi', clock: () => fixedNow);

  @override
  bool get isDemo => true;

  @override
  Future<List<Workspace>> workspacesFor(String userId) async => [
        for (final w in await _inner.workspacesFor(userId))
          w.copyWith(
            name: '${w.name} — Regional Operations and Customer Experience Working Group',
            members: [
              for (final m in w.members)
                m.copyWith(displayName: '${m.displayName} binti Abdullah Rahman Hakimi'),
            ],
          ),
      ];

  @override
  Future<List<Project>> projectsFor(String id) => _inner.projectsFor(id);
  @override
  Future<List<TeamTask>> tasksFor(String id) => _inner.tasksFor(id);
}

Future<void> _pump(WidgetTester tester, Widget body, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
    home: Scaffold(body: body),
  ));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [390.0, 320.0]) {
    testWidgets('long names do not overflow on Home at ${width.toInt()}px', (tester) async {
      await _pump(
        tester,
        DashboardTab(repository: _LongNamesRepo(), userId: 'me', userName: 'Khairi', clock: () => fixedNow),
        Size(width, 3200),
      );
      expect(find.textContaining('Workload imbalance: Daniel Lim binti'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long names do not overflow on Teams list and detail at ${width.toInt()}px',
        (tester) async {
      await _pump(tester, TeamsTab(repository: _LongNamesRepo(), userId: 'me'), Size(width, 2400));
      expect(tester.takeException(), isNull);

      await tester.tap(find.textContaining('Kopi Corner Team'));
      await tester.pumpAndSettle();
      expect(find.text('Menu Relaunch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('"Team Workspaces" heading only in the body on wide layouts', (tester) async {
    await _pump(tester, TeamsTab(repository: _LongNamesRepo(), userId: 'me'), const Size(390, 2400));
    expect(find.text('Team Workspaces'), findsNothing); // shell app bar shows it on phones

    await _pump(tester, TeamsTab(repository: _LongNamesRepo(), userId: 'me'), const Size(1280, 1600));
    expect(find.text('Team Workspaces'), findsOneWidget);
  });
}
