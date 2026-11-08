import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/data/demo_workspace_repository.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_cubit.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_sections.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_summary.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_tab.dart';

final fixedNow = DateTime(2026, 11, 10, 9);
DateTime clock() => fixedNow;

DemoWorkspaceRepository demoRepo() =>
    DemoWorkspaceRepository(currentUserId: 'me', currentUserName: 'Khairi Rahimi', clock: clock);

class _EmptyRepo implements WorkspaceRepository {
  @override
  bool get isDemo => false;
  @override
  Future<List<Workspace>> workspacesFor(String userId) async => [];
  @override
  Future<List<Project>> projectsFor(String workspaceId) async => [];
  @override
  Future<List<TeamTask>> tasksFor(String workspaceId) async => [];
}

class _FailingRepo extends _EmptyRepo {
  @override
  Future<List<Workspace>> workspacesFor(String userId) async => throw Exception('offline');
}

/// Delays the first workspace's tasks so a later selection finishes first.
class _SlowFirstRepo implements WorkspaceRepository {
  final DemoWorkspaceRepository inner = demoRepo();
  final Completer<void> gate = Completer<void>();
  @override
  bool get isDemo => true;
  @override
  Future<List<Workspace>> workspacesFor(String userId) => inner.workspacesFor(userId);
  @override
  Future<List<Project>> projectsFor(String workspaceId) => inner.projectsFor(workspaceId);
  @override
  Future<List<TeamTask>> tasksFor(String workspaceId) async {
    if (workspaceId == 'demo-ws-cafe') await gate.future;
    return inner.tasksFor(workspaceId);
  }
}

Future<DashboardSummary> cafeSummary() async {
  final repo = demoRepo();
  final ws = (await repo.workspacesFor('me')).first;
  return DashboardSummary.build(
    workspace: ws,
    tasks: await repo.tasksFor(ws.id),
    currentUserId: 'me',
    now: fixedNow,
  );
}

void main() {
  group('DashboardSummary (demo data, fixed clock)', () {
    test('KPIs', () async {
      final s = await cafeSummary();
      expect(s.workspace.name, startsWith(DemoWorkspaceRepository.demoPrefix));
      expect(s.myActiveCount, 2);
      expect(s.dueTodayCount, 1);
      expect(s.overdueCount, 1);
      expect(s.completedCount, 3);
      expect(s.totalCount, 11);
    });

    test('Smart Priority list is top 5 active tasks, highest first', () async {
      final s = await cafeSummary();
      expect(s.priorityTasks, hasLength(DashboardSummary.priorityLimit));
      expect(s.priorityTasks.first.task.id, 'demo-t1'); // urgent, due today, open subtask
      expect(s.priorityTasks.every((r) => r.task.isActive), isTrue);
      final scores = s.priorityTasks.map((r) => r.priority.score).toList();
      expect(scores, [...scores]..sort((a, b) => b.compareTo(a)));
    });

    test('workload: congestion for Daniel with an advisory suggestion', () async {
      final s = await cafeSummary();
      expect(s.workloads.map((w) => w.userId).first, 'me');
      final c = s.conflicts.single;
      expect(s.memberName(c.memberId), 'Daniel Lim');
      expect(c.type, ConflictType.deadlineCongestion);
      expect(c.suggestedTaskId, 'demo-t6');
      expect(s.memberName(c.suggestedAssigneeId), 'Mei Ling');
    });

    test('recent activity is newest first and limited', () async {
      final s = await cafeSummary();
      expect(s.recentActivity, hasLength(DashboardSummary.activityLimit));
      expect(s.recentActivity.first.activity.id, 'a4');
      final times = s.recentActivity.map((a) => a.activity.timestamp).toList();
      for (var i = 1; i < times.length; i++) {
        expect(times[i].isAfter(times[i - 1]), isFalse);
      }
    });

    test('demo data only lists workspaces the user belongs to', () async {
      expect(await demoRepo().workspacesFor('someone-else'), isEmpty);
      expect((await demoRepo().workspacesFor('me')).length, 2);
    });
  });

  group('format helpers', () {
    test('due labels and relative time', () {
      expect(dueLabel(null, fixedNow), 'No deadline');
      expect(dueLabel(DateTime(2026, 11, 9), fixedNow), 'Overdue 1 day');
      expect(dueLabel(DateTime(2026, 11, 7), fixedNow), 'Overdue 3 days');
      expect(dueLabel(DateTime(2026, 11, 10, 23), fixedNow), 'Due today');
      expect(dueLabel(DateTime(2026, 11, 11), fixedNow), 'Due tomorrow');
      expect(dueLabel(DateTime(2026, 11, 14), fixedNow), 'Due in 4 days');
      expect(timeAgo(fixedNow, fixedNow), 'just now');
      expect(timeAgo(fixedNow.subtract(const Duration(minutes: 5)), fixedNow), '5m ago');
      expect(timeAgo(fixedNow.subtract(const Duration(hours: 3)), fixedNow), '3h ago');
      expect(timeAgo(fixedNow.subtract(const Duration(days: 2)), fixedNow), '2d ago');
      expect(firstName('  Khairi Rahimi '), 'Khairi');
      expect(firstName(''), 'there');
      expect(greeting(fixedNow), 'Good morning');
    });
  });

  group('DashboardCubit', () {
    test('loads first workspace, then switches', () async {
      final cubit = DashboardCubit(repository: demoRepo(), userId: 'me', clock: clock);
      await cubit.load();
      final ready = cubit.state as DashboardReady;
      expect(ready.summary.workspace.id, 'demo-ws-cafe');
      expect(ready.workspaces, hasLength(2));
      expect(ready.isDemo, isTrue);

      await cubit.selectWorkspace('demo-ws-csc661');
      expect((cubit.state as DashboardReady).summary.workspace.id, 'demo-ws-csc661');
      expect((cubit.state as DashboardReady).summary.myActiveCount, 1);

      await cubit.selectWorkspace('unknown'); // ignored
      expect((cubit.state as DashboardReady).summary.workspace.id, 'demo-ws-csc661');
      await cubit.close();
    });

    test('no workspaces and repository errors', () async {
      final empty = DashboardCubit(repository: _EmptyRepo(), userId: 'me', clock: clock);
      await empty.load();
      expect(empty.state, isA<DashboardNoWorkspaces>());

      final failing = DashboardCubit(repository: _FailingRepo(), userId: 'me', clock: clock);
      await failing.load();
      expect(failing.state, isA<DashboardError>());
      await empty.close();
      await failing.close();
    });

    test('a slower, superseded load cannot overwrite a newer selection', () async {
      final repo = _SlowFirstRepo();
      final cubit = DashboardCubit(repository: repo, userId: 'me', clock: clock);
      final firstLoad = cubit.load(); // waits on the cafe workspace
      await Future<void>.delayed(Duration.zero);
      await cubit.selectWorkspace('demo-ws-csc661');
      repo.gate.complete();
      await firstLoad;
      expect((cubit.state as DashboardReady).summary.workspace.id, 'demo-ws-csc661');
      await cubit.close();
    });
  });

  group('DashboardTab widget', () {
    Future<void> pump(WidgetTester tester, {Size size = const Size(390, 3200), Brightness b = Brightness.light, WorkspaceRepository? repo}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: SpTheme.build(b, useGoogleFonts: false),
        home: Scaffold(
          body: DashboardTab(
            repository: repo ?? demoRepo(),
            userId: 'me',
            userName: 'Khairi Rahimi',
            clock: clock,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('phone: shows all dashboard sections with demo label', (tester) async {
      await pump(tester);
      expect(find.text('Good morning, Khairi'), findsOneWidget);
      expect(find.textContaining('Demo data'), findsOneWidget);
      expect(find.text('Workload imbalance: Daniel Lim'), findsOneWidget);
      for (final label in ['Assigned to you', 'Due today', 'Overdue', 'Completed']) {
        expect(find.widgetWithText(KpiTile, label), findsOneWidget);
      }
      expect(find.text('Smart Priority Tasks'), findsOneWidget);
      expect(find.text('Finalise new menu pricing'), findsOneWidget);
      expect(find.text('Team Workload Health'), findsOneWidget);
      expect(find.text('Deadline crunch'), findsOneWidget);
      expect(find.text('Recent Team Activity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('workspace selector switches workspace', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Switch workspace'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Demo · CSC661 Project Group').last);
      await tester.pumpAndSettle();
      expect(find.text('Demo · CSC661 Project Group'), findsOneWidget);
      expect(find.text('Literature review chapter'), findsWidgets);
      expect(find.textContaining('Workload imbalance'), findsNothing);
    });

    testWidgets('wide and dark layouts render without errors', (tester) async {
      await pump(tester, size: const Size(1280, 2000));
      expect(find.text('Team Workload Health'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await pump(tester, size: const Size(390, 3200), b: Brightness.dark);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty state when the user has no workspaces', (tester) async {
      await pump(tester, repo: _EmptyRepo());
      expect(find.text('No workspaces yet'), findsOneWidget);
      expect(find.textContaining('Demo data'), findsNothing);
    });
  });
}
