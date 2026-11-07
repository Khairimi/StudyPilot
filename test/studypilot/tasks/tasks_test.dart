import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/data/demo_workspace_repository.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/tasks/task_filter.dart';
import 'package:study_app/studypilot/screens/tasks/tasks_cubit.dart';
import 'package:study_app/studypilot/screens/tasks/tasks_tab.dart';

final fixedNow = DateTime(2026, 11, 10, 9);
DateTime clock() => fixedNow;

DemoWorkspaceRepository demoRepo() =>
    DemoWorkspaceRepository(currentUserId: 'me', currentUserName: 'Khairi Rahimi', clock: clock);

TeamTask t(String id,
        {String title = 'Task',
        String description = '',
        List<String> tags = const [],
        String? assignee,
        SpPriority p = SpPriority.medium,
        SpTaskStatus s = SpTaskStatus.todo,
        String project = 'p1'}) =>
    TeamTask(
      id: id,
      workspaceId: 'w',
      projectId: project,
      title: title,
      description: description,
      tags: tags,
      assigneeId: assignee,
      priority: p,
      status: s,
      createdBy: 'me',
      createdAt: DateTime(2026, 11, 1),
    );

Future<void> pumpTasks(WidgetTester tester, {Size size = const Size(390, 2400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
    home: Scaffold(body: TasksTab(repository: demoRepo(), userId: 'me', clock: clock)),
  ));
  await tester.pumpAndSettle();
}

Future<void> openTask(WidgetTester tester, String title) async {
  await tester.tap(find.text(title).first);
  await tester.pumpAndSettle();
}

void main() {
  group('TaskFilter', () {
    final tasks = [
      t('a', title: 'Fix login bug', assignee: 'me', p: SpPriority.urgent),
      t('b', title: 'Write docs', description: 'API reference', assignee: 'ana'),
      t('c', title: 'Plan launch', tags: ['Marketing'], s: SpTaskStatus.completed, project: 'p2'),
    ];
    List<String> ids(TaskFilter f) => f.apply(tasks, 'me', fixedNow).map((x) => x.id).toList();

    test('search covers title, description and tags, case-insensitive', () {
      expect(ids(const TaskFilter(query: 'LOGIN')), ['a']);
      expect(ids(const TaskFilter(query: 'api')), ['b']);
      expect(ids(const TaskFilter(query: 'market')), ['c']);
      expect(ids(const TaskFilter(query: '  ')), hasLength(3));
    });

    test('scope, priority, status and project filters combine', () {
      expect(ids(const TaskFilter(scope: TaskScope.mine)), ['a']);
      expect(ids(const TaskFilter(scope: TaskScope.unassigned)), ['c']);
      expect(ids(const TaskFilter(priorities: {SpPriority.urgent})), ['a']);
      expect(ids(const TaskFilter(statuses: {SpTaskStatus.completed})), ['c']);
      expect(ids(const TaskFilter(projectId: 'p2')), ['c']);
      expect(ids(const TaskFilter(scope: TaskScope.mine, statuses: {SpTaskStatus.completed})), isEmpty);
    });

    test('ranked by Smart Priority with completed last; active filter count', () {
      expect(ids(const TaskFilter()), ['a', 'b', 'c']);
      const f = TaskFilter(scope: TaskScope.mine, priorities: {SpPriority.high}, projectId: 'p1');
      expect(f.activeCount, 3);
      expect(f.copyWith(projectId: null).projectId, isNull);
      expect(const TaskFilter(query: 'x').isDefault, isFalse);
    });

    test('groupByStatus keeps workflow order and ranking', () {
      final g = groupByStatus(const TaskFilter().apply(tasks, 'me', fixedNow));
      expect(g.keys, SpTaskStatus.values);
      expect(g[SpTaskStatus.todo]!.map((x) => x.id), ['a', 'b']);
      expect(g[SpTaskStatus.completed]!.map((x) => x.id), ['c']);
      expect(g[SpTaskStatus.inReview], isEmpty);
    });
  });

  group('TaskValidators', () {
    test('title and hours', () {
      expect(TaskValidators.title(''), isNotNull);
      expect(TaskValidators.title('ab'), isNotNull);
      expect(TaskValidators.title('x' * 121), isNotNull);
      expect(TaskValidators.title('Draft menu'), isNull);
      expect(TaskValidators.hours(''), isNull);
      expect(TaskValidators.hours('abc'), isNotNull);
      expect(TaskValidators.hours('-1'), isNotNull);
      expect(TaskValidators.hours('201'), isNotNull);
      expect(TaskValidators.hours('2.5'), isNull);
      expect(TaskValidators.parseHours('2.5'), 2.5);
      expect(TaskValidators.parseHours(''), 0);
    });

    test('due date: new tasks cannot be in the past; edits may stay overdue', () {
      final yesterday = DateTime(2026, 11, 9);
      expect(TaskValidators.dueDate(yesterday, fixedNow, isNew: true), isNotNull);
      expect(TaskValidators.dueDate(yesterday, fixedNow, isNew: false), isNull);
      expect(TaskValidators.dueDate(DateTime(2026, 11, 10, 8), fixedNow, isNew: true), isNull);
      expect(TaskValidators.dueDate(null, fixedNow, isNew: true), isNull);
      expect(TaskValidators.project(null), isNotNull);
    });
  });

  group('TasksCubit', () {
    test('filters, view mode and workspace switch', () async {
      final cubit = TasksCubit(repository: demoRepo(), userId: 'me', clock: clock);
      await cubit.load();
      var s = cubit.state as TasksReady;
      expect(s.allTasks, hasLength(11));
      expect(s.visible.first.id, 'demo-t1');

      cubit.setQuery('pos');
      expect((cubit.state as TasksReady).visible.map((x) => x.id), ['demo-t5']);
      cubit.setFilter(const TaskFilter(scope: TaskScope.mine, projectId: 'demo-p-launch'));
      expect((cubit.state as TasksReady).visible.map((x) => x.id).toSet(),
          {'demo-t1', 'demo-t2', 'demo-t11'});

      cubit.setMode(TaskViewMode.board);
      expect((cubit.state as TasksReady).mode, TaskViewMode.board);

      await cubit.selectWorkspace('demo-ws-csc661');
      s = cubit.state as TasksReady;
      expect(s.workspace.id, 'demo-ws-csc661');
      expect(s.filter.projectId, isNull); // project filter is per workspace
      expect(s.mode, TaskViewMode.board);
      await cubit.close();
    });
  });

  group('Tasks UI', () {
    testWidgets('list is ranked by Smart Priority and searchable', (tester) async {
      await pumpTasks(tester);
      expect(find.textContaining('Demo data'), findsOneWidget);
      expect(find.text('11 of 11 tasks · ranked by Smart Priority'), findsOneWidget);
      final first = tester.getTopLeft(find.text('Finalise new menu pricing'));
      final later = tester.getTopLeft(find.text('Plan launch-day promotion'));
      expect(first.dy, lessThan(later.dy));

      await tester.enterText(find.byType(TextField), 'POS');
      await tester.pumpAndSettle();
      expect(find.text('1 of 11 tasks · ranked by Smart Priority'), findsOneWidget);
      expect(find.text('Update POS menu items'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matching tasks'), findsOneWidget);
    });

    testWidgets('filter sheet applies and clears filters', (tester) async {
      await pumpTasks(tester);
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assigned to me'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text('3 of 11 tasks · ranked by Smart Priority'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pumpAndSettle();
      expect(find.text('11 of 11 tasks · ranked by Smart Priority'), findsOneWidget);
    });

    testWidgets('board view shows status columns', (tester) async {
      await pumpTasks(tester, size: const Size(1600, 1400));
      await tester.tap(find.byTooltip('Board view'));
      await tester.pumpAndSettle();
      for (final label in ['To Do', 'In Progress', 'In Review', 'Completed']) {
        expect(find.widgetWithText(SpStatusBadge, label), findsOneWidget);
      }
      expect(find.byTooltip('List view'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail explains the score, lists subtasks and activity', (tester) async {
      await pumpTasks(tester);
      await openTask(tester, 'Finalise new menu pricing');
      expect(find.text('Smart Priority'), findsOneWidget);
      expect(find.text('Due today'), findsWidgets);
      expect(find.text('Marked urgent'), findsOneWidget);
      expect(find.text('+40'), findsOneWidget);
      expect(find.text('+35'), findsOneWidget);
      expect(find.text('Supplier quotes'), findsOneWidget);
      expect(find.textContaining('moved this task'), findsOneWidget);

      // Subtask toggle is a demo: state does not change and the user is told.
      final box = find.widgetWithText(CheckboxListTile, 'Margin check');
      expect(tester.widget<CheckboxListTile>(box).value, isFalse);
      await tester.tap(box);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(box).value, isFalse);
      expect(find.textContaining('Demo only: subtask "Margin check" was not updated'), findsOneWidget);
    });

    testWidgets('status and assign actions are demo-only', (tester) async {
      await pumpTasks(tester);
      await openTask(tester, 'Finalise new menu pricing');
      await tester.tap(find.text('Status'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Completed'));
      await tester.pumpAndSettle();
      expect(find.textContaining('status was not changed to Completed'), findsOneWidget);
      expect(find.widgetWithText(SpStatusBadge, 'In Progress'), findsOneWidget);

      await tester.tap(find.text('Assign'));
      await tester.pumpAndSettle();
      expect(find.text('Current load vs 15h capacity'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Mei Ling'));
      await tester.pumpAndSettle();
      expect(find.textContaining('was not reassigned to Mei Ling'), findsOneWidget);
    });

    testWidgets('create form validates, previews priority, saves nothing', (tester) async {
      await pumpTasks(tester);
      await tester.tap(find.text('New task'));
      await tester.pumpAndSettle();
      expect(find.text('Demo mode: nothing you submit here will be saved.'), findsOneWidget);

      await tester.tap(find.text('Create task (demo)'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a task title'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Prepare tasting event');
      await tester.enterText(find.widgetWithText(TextFormField, 'Est. hours'), 'abc');
      await tester.tap(find.text('Create task (demo)'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a number of hours'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Est. hours'), '8');
      await tester.tap(find.text('Urgent').last);
      await tester.pumpAndSettle();
      // Live preview combines all rule reasons for the draft.
      expect(find.text('No deadline set · Marked urgent · Heavy effort (~8h)'), findsOneWidget);

      await tester.tap(find.text('Create task (demo)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"Prepare tasting event" was not created'), findsOneWidget);
      expect(find.text('Prepare tasting event'), findsNothing);
      expect(find.text('11 of 11 tasks · ranked by Smart Priority'), findsOneWidget);
    });

    testWidgets('edit form is prefilled and saves nothing', (tester) async {
      await pumpTasks(tester);
      await openTask(tester, 'Train staff on new recipes');
      await tester.tap(find.byTooltip('Edit task'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Train staff on new recipes'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '6'), findsOneWidget);
      await tester.tap(find.text('Save changes (demo)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('changes to "Train staff on new recipes" were not saved'), findsOneWidget);
    });

    testWidgets('no overflow at 320px: list, board, detail, form', (tester) async {
      await pumpTasks(tester, size: const Size(320, 2400));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Board view'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('List view'));
      await tester.pumpAndSettle();
      await openTask(tester, 'Finalise new menu pricing');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Edit task'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
