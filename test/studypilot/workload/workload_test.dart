import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/data/demo_workspace_repository.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/logic/workload_engine.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_tab.dart';
import 'package:study_app/studypilot/screens/workload/reassignment_preview.dart';
import 'package:study_app/studypilot/screens/workload/workload_cubit.dart';
import 'package:study_app/studypilot/screens/workload/workload_insights_screen.dart';

final fixedNow = DateTime(2026, 11, 10, 9);
DateTime clock() => fixedNow;

DemoWorkspaceRepository demoRepo() =>
    DemoWorkspaceRepository(currentUserId: 'me', currentUserName: 'Khairi Rahimi', clock: clock);

/// One workspace with explicit tasks (owner: 'me').
class FixedRepo implements WorkspaceRepository {
  final Workspace ws;
  final List<TeamTask> tasks;
  FixedRepo(this.ws, this.tasks);
  @override
  bool get isDemo => true;
  @override
  Future<List<Workspace>> workspacesFor(String userId) async => ws.isMember(userId) ? [ws] : [];
  @override
  Future<List<Project>> projectsFor(String id) async => const [];
  @override
  Future<List<TeamTask>> tasksFor(String id) async => tasks;
}

Workspace team() => Workspace(
      id: 'w',
      name: 'Ops Team',
      type: WorkspaceType.smallBusiness,
      ownerId: 'me',
      inviteCode: 'OPS123',
      createdAt: DateTime(2026, 10, 1),
      members: [
        for (final (id, name, role) in [
          ('me', 'Khairi Rahimi', SpRole.owner),
          ('ana', 'Ana Lee', SpRole.member),
          ('ben', 'Ben Tan', SpRole.member),
        ])
          WorkspaceMember(userId: id, displayName: name, role: role, joinedAt: DateTime(2026, 10, 1)),
      ],
    );

TeamTask job(String id, String who, double hours, {int dueIn = 10}) => TeamTask(
      id: id,
      workspaceId: 'w',
      projectId: 'p',
      title: 'Job $id',
      assigneeId: who,
      estimatedHours: hours,
      dueAt: DateTime(2026, 11, 10 + dueIn, 17),
      createdBy: 'me',
      createdAt: DateTime(2026, 11, 1),
    );

/// Ana is at 24h (≥1.5×15h → high); Ben has room for one 12h job.
FixedRepo overloadRepo() => FixedRepo(team(), [job('a1', 'ana', 12), job('a2', 'ana', 12), job('b1', 'ben', 2)]);

/// Ana is over capacity but nobody can take her 16h job without overload.
FixedRepo noRoomRepo() => FixedRepo(team(), [job('a1', 'ana', 16), job('b1', 'ben', 10), job('m1', 'me', 10)]);

Future<void> pumpInsights(WidgetTester tester,
    {WorkspaceRepository? repo, String userId = 'me', Size size = const Size(390, 3000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
    home: WorkloadInsightsScreen(repository: repo ?? demoRepo(), userId: userId, clock: clock),
  ));
  await tester.pumpAndSettle();
}

Future<ReassignmentPreview> previewFor(WorkspaceRepository repo, String userId) async {
  final ws = (await repo.workspacesFor(userId)).first;
  final tasks = await repo.tasksFor(ws.id);
  final loads = WorkloadEngine.memberWorkloads(ws, tasks, fixedNow);
  final c = WorkloadEngine.detectConflicts(ws, tasks, fixedNow).first;
  return ReassignmentPreview.of(c, loads, tasks)!;
}

void main() {
  group('ReassignmentPreview (capacity limits)', () {
    test('demo congestion: moving the suggested task clears it and keeps target healthy', () async {
      final p = await previewFor(demoRepo(), 'me');
      expect(p.task.id, 'demo-t6');
      expect(p.from.userId, 'demo-daniel');
      expect(p.to.userId, 'demo-meiling');
      expect((p.from.activeHours, p.fromHoursAfter), (9, 7));
      expect((p.to.activeHours, p.toHoursAfter), (3, 5));
      expect(p.fromDueSoonAfter, 2);
      expect(p.targetStaysHealthy, isTrue);
      expect(p.resolvesConflict, isTrue);
    });

    test('high overload: suggested target stays under capacity', () async {
      final p = await previewFor(overloadRepo(), 'me');
      expect(p.conflict.severity, SpSeverity.high);
      // Least-loaded teammate is the owner (0h), not Ben (2h).
      expect(p.to.userId, 'me');
      expect((p.fromHoursAfter, p.toHoursAfter), (12, 12));
      expect(p.targetStaysHealthy, isTrue);
      expect(p.resolvesConflict, isTrue);
    });

    test('reaching capacity exactly is not healthy; no suggestion when nobody has room', () {
      MemberWorkload load(String id, double h) => MemberWorkload(
          userId: id, activeTasks: const [], activeHours: h, dueSoonTasks: const [], thresholdHours: 15);
      final task = job('x', 'ana', 3);
      final c = WorkloadConflict(
        id: 'c', workspaceId: 'w', memberId: 'ana', type: ConflictType.capacityOverload,
        severity: SpSeverity.medium, taskIds: const ['x'], assignedHours: 18, thresholdHours: 15,
        dueSoonCount: 0, reasons: const [], suggestedTaskId: 'x', suggestedAssigneeId: 'ben',
      );
      final p = ReassignmentPreview(conflict: c, task: task, from: load('ana', 18), to: load('ben', 12));
      expect(p.toHoursAfter, 15);
      expect(p.targetStaysHealthy, isFalse);
      // 18h → 15h is still AT capacity, so the overload is not cleared.
      expect(p.fromHoursAfter, 15);
      expect(p.resolvesConflict, isFalse);
    });

    test('nobody with room → conflict has no suggestion', () async {
      final repo = noRoomRepo();
      final ws = (await repo.workspacesFor('me')).first;
      final c = WorkloadEngine.detectConflicts(ws, await repo.tasksFor('w'), fixedNow).single;
      expect(c.hasSuggestion, isFalse);
      expect(ReassignmentPreview.of(c, const [], const []), isNull);
    });
  });

  group('WorkloadCubit', () {
    test('owner flag follows the workspace role', () async {
      final cubit = WorkloadCubit(repository: demoRepo(), userId: 'me', clock: clock);
      await cubit.load();
      var s = cubit.state as WorkloadReady;
      expect(s.isOwner, isTrue);
      expect(s.conflicts, hasLength(1));
      await cubit.selectWorkspace('demo-ws-csc661');
      s = cubit.state as WorkloadReady;
      expect(s.isOwner, isFalse);
      expect(s.conflicts, isEmpty);
      await cubit.close();
    });
  });

  group('Workload Insights UI', () {
    testWidgets('owner reviews and approves: demo only, data unchanged', (tester) async {
      final repo = demoRepo();
      await pumpInsights(tester, repo: repo);
      expect(find.text('Daniel Lim'), findsWidgets); // conflict card + capacity row
      expect(find.text('Deadline congestion'), findsOneWidget);
      expect(find.textContaining('3 active tasks due within 2 days'), findsOneWidget);
      expect(find.textContaining('Suggestion: move "Book food photographer" (2h) to Mei Ling (3h → 5h of 15h)'),
          findsOneWidget);

      await tester.tap(find.text('Review reassignment'));
      await tester.pumpAndSettle();
      expect(find.textContaining('StudyPilot never reassigns tasks automatically'), findsOneWidget);
      expect(find.text('From: Daniel Lim'), findsOneWidget);
      expect(find.text('9h → 7h'), findsOneWidget);
      expect(find.text('Mei Ling stays under capacity'), findsOneWidget);

      await tester.tap(find.text('Approve (demo)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"Book food photographer" was not reassigned. No task data changed.'),
          findsOneWidget);
      // Nothing changed: conflict still shown, task still assigned to Daniel.
      expect(find.text('Review reassignment'), findsOneWidget);
      final t6 = (await repo.tasksFor('demo-ws-cafe')).firstWhere((t) => t.id == 'demo-t6');
      expect(t6.assigneeId, 'demo-daniel');
    });

    testWidgets('owner rejects: demo only', (tester) async {
      await pumpInsights(tester);
      await tester.tap(find.text('Review reassignment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reject (demo)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('dismissed for this preview only. Nothing was saved.'), findsOneWidget);
      expect(find.text('Review reassignment'), findsOneWidget);
    });

    testWidgets('members see alerts but cannot review or approve', (tester) async {
      await pumpInsights(tester, userId: 'demo-aina'); // member of the cafe workspace
      expect(find.text('Daniel Lim'), findsWidgets); // conflict card + capacity row
      expect(find.textContaining('Suggestion: move'), findsOneWidget);
      expect(find.text('Review reassignment'), findsNothing);
      expect(find.text('Only the workspace owner can approve reassignments.'), findsOneWidget);
      expect(find.text('Only workspace owners can review reassignments'), findsOneWidget);
      expect(find.text('Aina Sofea (you)'), findsOneWidget);
    });

    testWidgets('high overload and capacity tags', (tester) async {
      await pumpInsights(tester, repo: overloadRepo());
      expect(find.text('Capacity overload'), findsOneWidget);
      expect(find.text('High risk'), findsOneWidget);
      expect(find.text('Over capacity'), findsWidgets);
      expect(find.text('24h / 15h'), findsOneWidget);
      expect(find.text('Healthy'), findsWidgets);
    });

    testWidgets('no safe target: explained, no review button even for owner', (tester) async {
      await pumpInsights(tester, repo: noRoomRepo());
      expect(find.textContaining('No teammate has spare capacity'), findsOneWidget);
      expect(find.text('Review reassignment'), findsNothing);
      expect(find.textContaining('Suggestion: move'), findsNothing);
    });

    for (final width in [320.0, 390.0]) {
      testWidgets('no overflow at ${width.toInt()}px (screen and review sheet)', (tester) async {
        await pumpInsights(tester, size: Size(width, 3000));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Review reassignment'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Home workload alert opens Workload Insights', (tester) async {
      tester.view.physicalSize = const Size(390, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
        home: Scaffold(
          body: DashboardTab(repository: demoRepo(), userId: 'me', userName: 'Khairi', clock: clock),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View workload'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Workload Insights'), findsOneWidget);
      expect(find.text('Review reassignment'), findsOneWidget);
    });
  });
}
