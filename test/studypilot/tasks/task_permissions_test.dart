import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/data/demo_workspace_repository.dart';
import 'package:study_app/studypilot/logic/task_permissions.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/tasks/task_forms.dart';
import 'package:study_app/studypilot/screens/tasks/tasks_tab.dart';

final fixedNow = DateTime(2026, 11, 10, 9);
DateTime clock() => fixedNow;

Workspace ws(String id, {required String owner, required List<String> members}) => Workspace(
      id: id,
      name: 'WS $id',
      type: WorkspaceType.smallBusiness,
      ownerId: owner,
      inviteCode: 'CODE$id',
      createdAt: DateTime(2026, 10, 1),
      members: [
        for (final m in [owner, ...members])
          WorkspaceMember(
            userId: m,
            displayName: m,
            role: m == owner ? SpRole.owner : SpRole.member,
            joinedAt: DateTime(2026, 10, 1),
          ),
      ],
    );

TeamTask task(String id, {String workspaceId = 'a', String? assignee}) => TeamTask(
      id: id,
      workspaceId: workspaceId,
      projectId: 'p',
      title: 'Task $id',
      assigneeId: assignee,
      createdBy: 'owner',
      createdAt: DateTime(2026, 11, 1),
    );

/// The signed-in user is 'me' unless [userId] says otherwise.
Future<void> pumpTasks(WidgetTester tester, {required String userId}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = DemoWorkspaceRepository(currentUserId: 'me', currentUserName: 'Khairi Rahimi', clock: clock);
  await tester.pumpWidget(MaterialApp(
    theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
    home: Scaffold(body: TasksTab(repository: repo, userId: userId, clock: clock)),
  ));
  await tester.pumpAndSettle();
}

Future<void> openTask(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();
}

void main() {
  group('TaskPermissions', () {
    final a = ws('a', owner: 'owner', members: ['mem', 'other']);

    test('owner has full task control', () {
      final p = TaskPermissions(a, 'owner');
      final t = task('1', assignee: 'mem');
      expect(p.canCreate, isTrue);
      expect(p.canChooseAssignee, isTrue);
      expect(p.canAssign(t), isTrue);
      expect(p.canEditDetails(t), isTrue);
      expect(p.canUpdateProgress(t), isTrue);
      expect(p.canUpdateProgress(task('2')), isTrue); // unassigned
    });

    test('member: create, and update status/subtasks of own tasks only', () {
      final p = TaskPermissions(a, 'mem');
      final mine = task('1', assignee: 'mem');
      final theirs = task('2', assignee: 'other');
      final unassigned = task('3');
      expect(p.canCreate, isTrue);
      expect(p.canUpdateProgress(mine), isTrue);
      expect(p.canUpdateProgress(theirs), isFalse);
      expect(p.canUpdateProgress(unassigned), isFalse);
    });

    test('member cannot edit details, choose an assignee or (re)assign', () {
      final p = TaskPermissions(a, 'mem');
      expect(p.canChooseAssignee, isFalse);
      for (final t in [task('1', assignee: 'mem'), task('2', assignee: 'other'), task('3')]) {
        expect(p.canAssign(t), isFalse);
        expect(p.canEditDetails(t), isFalse);
      }
    });

    test('roles are workspace-specific', () {
      final b = ws('b', owner: 'mem', members: ['owner']);
      final inB = task('1', workspaceId: 'b', assignee: 'owner');
      expect(TaskPermissions(b, 'mem').canAssign(inB), isTrue);
      expect(TaskPermissions(b, 'owner').canAssign(inB), isFalse);
      // Owner of A gets nothing on a task from workspace B through A.
      expect(TaskPermissions(a, 'owner').canAssign(inB), isFalse);
      expect(TaskPermissions(a, 'owner').canUpdateProgress(inB), isFalse);
    });

    test('non-members get no permissions', () {
      final p = TaskPermissions(a, 'stranger');
      final t = task('1', assignee: 'stranger');
      expect(p.canCreate, isFalse);
      expect(p.canUpdateProgress(t), isFalse);
      expect(p.canAssign(t), isFalse);
    });
  });

  group('Task permission UI (member of the demo cafe workspace)', () {
    // demo-aina is a member (not owner) of the cafe workspace.
    testWidgets("other member's task is view-only", (tester) async {
      await pumpTasks(tester, userId: 'demo-aina');
      await openTask(tester, 'Finalise new menu pricing'); // assigned to the owner
      expect(find.byTooltip('Edit task'), findsNothing);
      expect(find.text('Status'), findsNothing);
      expect(find.text('Assign'), findsNothing);
      expect(find.textContaining('View only'), findsOneWidget);
      final box = find.widgetWithText(CheckboxListTile, 'Margin check');
      expect(tester.widget<CheckboxListTile>(box).onChanged, isNull);
    });

    testWidgets('own task: status allowed, edit and assign hidden', (tester) async {
      await pumpTasks(tester, userId: 'demo-aina');
      await openTask(tester, 'Train staff on new recipes'); // assigned to Aina
      expect(find.byTooltip('Edit task'), findsNothing);
      expect(find.text('Assign'), findsNothing);
      expect(find.textContaining('Only the workspace owner can edit details or reassign it'), findsOneWidget);
      await tester.tap(find.text('Status'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Completed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('status was not changed to Completed'), findsOneWidget);
    });

    testWidgets('member creates a task assigned to themselves only', (tester) async {
      await pumpTasks(tester, userId: 'demo-aina');
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String?>), findsNothing);
      expect(find.text('Aina Sofea (you)'), findsOneWidget);
      expect(find.text('Only the workspace owner can assign tasks to others.'), findsOneWidget);
    });

    testWidgets('owner still sees edit, status, assign and the assignee picker', (tester) async {
      await pumpTasks(tester, userId: 'me');
      await openTask(tester, 'Train staff on new recipes'); // another member's task
      expect(find.byTooltip('Edit task'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Assign'), findsOneWidget);
      expect(find.textContaining('View only'), findsNothing);
      await tester.tap(find.byTooltip('Edit task'));
      await tester.pumpAndSettle();
      expect(find.byType(DropdownButtonFormField<String?>), findsOneWidget);
    });

    testWidgets('sheet entry points refuse members directly', (tester) async {
      final w = ws('a', owner: 'owner', members: ['mem', 'other']);
      final theirs = task('1', assignee: 'other');
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
        home: Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
      ));

      showAssignSheet(ctx, task: theirs, workspace: w, allTasks: [theirs], currentUserId: 'mem', now: fixedNow);
      await tester.pumpAndSettle();
      expect(find.text('Assign task'), findsNothing);
      expect(find.text(kOwnerOnlyAssignMessage), findsOneWidget);

      showStatusSheet(ctx, task: theirs, workspace: w, currentUserId: 'mem');
      await tester.pumpAndSettle();
      expect(find.text('Change status'), findsNothing);
      expect(find.text(kNoProgressMessage), findsOneWidget);

      showTaskFormSheet(ctx, workspace: w, projects: const [], currentUserId: 'mem', now: fixedNow, existing: theirs);
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsNothing);
      expect(find.text(kOwnerOnlyEditMessage), findsOneWidget);
    });
  });
}
