import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/core/sp_user.dart';
import 'package:study_app/studypilot/core/workspace_selection.dart';
import 'package:study_app/studypilot/data/demo_workspace_repository.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_cubit.dart';
import 'package:study_app/studypilot/screens/shell/studypilot_shell.dart';
import 'package:study_app/studypilot/screens/tasks/tasks_cubit.dart';
import 'package:study_app/studypilot/screens/workload/workload_cubit.dart';

final fixedNow = DateTime(2026, 11, 10, 9);
DateTime clock() => fixedNow;

const cafe = 'demo-ws-cafe';
const csc = 'demo-ws-csc661';
const cafeName = 'Demo · Kopi Corner Team';
const cscName = 'Demo · CSC661 Project Group';

DemoWorkspaceRepository demoRepo() =>
    DemoWorkspaceRepository(currentUserId: 'me', currentUserName: 'Khairi Rahimi', clock: clock);

Future<void> pumpShell(WidgetTester tester, {Size size = const Size(390, 900)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
      home: StudyPilotShell(
        userOverride: const SpUserInfo(uid: 'me', displayName: 'Khairi Rahimi'),
        // Real clock for both data and screens (the shell has no clock hook).
        repositoryOverride: DemoWorkspaceRepository(currentUserId: 'me', currentUserName: 'Khairi Rahimi'),
        profileTabOverride: const Text('Profile stub'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The workspace name shown by the selector of the visible tab.
Finder visibleSelectorText(String name) =>
    find.descendant(of: find.byTooltip('Switch workspace').hitTestable(), matching: find.text(name));

Future<void> switchWorkspace(WidgetTester tester, String name) async {
  await tester.tap(find.byTooltip('Switch workspace').hitTestable());
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  group('Shared workspace selection (cubits)', () {
    test('a selection made in Home is followed by Tasks and Workload', () async {
      final selection = WorkspaceSelectionCubit();
      final home = DashboardCubit(repository: demoRepo(), userId: 'me', clock: clock, selection: selection);
      final tasks = TasksCubit(repository: demoRepo(), userId: 'me', clock: clock, selection: selection);
      final workload = WorkloadCubit(repository: demoRepo(), userId: 'me', clock: clock, selection: selection);
      await Future.wait([home.load(), tasks.load(), workload.load()]);
      expect(selection.workspaceId, cafe);

      await home.selectWorkspace(csc);
      await pumpEventQueue();
      expect(selection.workspaceId, csc);
      expect((tasks.state as TasksReady).workspace.id, csc);
      expect((workload.state as WorkloadReady).workspace.id, csc);

      await workload.selectWorkspace(cafe);
      await pumpEventQueue();
      expect((home.state as DashboardReady).summary.workspace.id, cafe);
      expect((tasks.state as TasksReady).workspace.id, cafe);
      await Future.wait([home.close(), tasks.close(), workload.close(), selection.close()]);
    });

    test('a newly opened screen starts on the shared selection', () async {
      final selection = WorkspaceSelectionCubit(csc);
      final workload = WorkloadCubit(repository: demoRepo(), userId: 'me', clock: clock, selection: selection);
      await workload.load();
      expect((workload.state as WorkloadReady).workspace.id, csc);
      await workload.close();
    });

    test('a workspace the user is not a member of falls back and is corrected', () async {
      final selection = WorkspaceSelectionCubit('someone-elses-ws');
      final tasks = TasksCubit(repository: demoRepo(), userId: 'me', clock: clock, selection: selection);
      await tasks.load();
      expect((tasks.state as TasksReady).workspace.id, cafe);
      expect(selection.workspaceId, cafe);

      // Later requests for an inaccessible workspace are ignored.
      selection.select('someone-elses-ws');
      await pumpEventQueue();
      expect((tasks.state as TasksReady).workspace.id, cafe);
      await tasks.close();
    });

    test('focusProject switches workspace and filters Tasks by project', () async {
      final selection = WorkspaceSelectionCubit();
      final tasks = TasksCubit(repository: demoRepo(), userId: 'me', clock: clock, selection: selection);
      await tasks.load();
      selection.focusProject(csc, 'demo-p-report');
      await pumpEventQueue();
      final s = tasks.state as TasksReady;
      expect(s.workspace.id, csc);
      expect(s.filter.projectId, 'demo-p-report');

      // Switching workspace normally clears the project filter.
      await tasks.selectWorkspace(cafe);
      expect((tasks.state as TasksReady).filter.projectId, isNull);
      await tasks.close();
    });
  });

  group('Shell regressions', () {
    testWidgets('Home selection carries to Tasks and back', (tester) async {
      await pumpShell(tester);
      expect(visibleSelectorText(cafeName), findsOneWidget);
      await switchWorkspace(tester, cscName);
      expect(visibleSelectorText(cscName), findsOneWidget);

      await openTab(tester, 'Tasks');
      expect(visibleSelectorText(cscName), findsOneWidget);

      await switchWorkspace(tester, cafeName);
      await openTab(tester, 'Home');
      expect(visibleSelectorText(cafeName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Workload Insights opens on, and updates, the shared workspace', (tester) async {
      await pumpShell(tester);
      await tester.tap(find.text('View workload'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Workload Insights'), findsOneWidget);
      expect(visibleSelectorText(cafeName), findsOneWidget);

      await switchWorkspace(tester, cscName);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(visibleSelectorText(cscName), findsOneWidget); // Home followed
      await openTab(tester, 'Tasks');
      expect(visibleSelectorText(cscName), findsOneWidget);
    });

    testWidgets('project card opens Tasks filtered by that project', (tester) async {
      await pumpShell(tester, size: const Size(390, 1600));
      await openTab(tester, 'Teams');
      await tester.tap(find.text(cafeName).hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Social Media Campaign'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Tasks'), findsOneWidget);
      expect(find.text('Project: Social Media Campaign'), findsOneWidget);
      expect(find.text('4 of 11 tasks · ranked by Smart Priority'), findsOneWidget);

      await tester.tap(find.byTooltip('Show all projects'));
      await tester.pumpAndSettle();
      expect(find.text('11 of 11 tasks · ranked by Smart Priority'), findsOneWidget);
    });
  });
}
