import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/data/demo_workspace_repository.dart';
import 'package:study_app/studypilot/screens/tasks/task_card.dart';
import 'package:study_app/studypilot/screens/tasks/tasks_tab.dart';

final fixedNow = DateTime(2026, 11, 10, 9);
DateTime clock() => fixedNow;

DemoWorkspaceRepository demoRepo() =>
    DemoWorkspaceRepository(currentUserId: 'me', currentUserName: 'Khairi Rahimi', clock: clock);

void main() {
  group('Mobile Tasks layout', () {
    Future<void> pumpTasks(WidgetTester tester, double width, {double height = 700}) async {
      tester.view.physicalSize = Size(width, height);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
          home: Scaffold(
            body: TasksTab(repository: demoRepo(), userId: 'me', clock: clock),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    for (final width in [320.0, 390.0]) {
      testWidgets('${width.toInt()}px: New task button never covers the last task', (tester) async {
        await pumpTasks(tester, width);
        final list = find.byType(Scrollable).last;
        final position = tester.state<ScrollableState>(list).position;
        position.jumpTo(position.maxScrollExtent); // programmatic: FAB stays visible
        await tester.pumpAndSettle();
        final fab = tester.getRect(find.byType(FloatingActionButton));
        final last = tester.getRect(find.byType(TaskCard).last);
        expect(last.bottom, lessThanOrEqualTo(fab.top));
        expect(tester.takeException(), isNull);
      });

      testWidgets('${width.toInt()}px: button hides while scrolling down, returns on scroll up', (tester) async {
        await pumpTasks(tester, width);
        expect(find.text('New task'), findsOneWidget);
        await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
        await tester.pumpAndSettle();
        expect(find.text('New task'), findsNothing);
        await tester.drag(find.byType(Scrollable).last, const Offset(0, 200));
        await tester.pumpAndSettle();
        expect(find.text('New task'), findsOneWidget);
      });

      testWidgets('${width.toInt()}px: board shows status tabs that scroll to columns', (tester) async {
        await pumpTasks(tester, width);
        await tester.tap(find.byTooltip('Board view'));
        await tester.pumpAndSettle();
        expect(find.byType(TabBar), findsOneWidget);
        expect(find.text('To Do (5)'), findsOneWidget);

        final board = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.right).last;
        expect(tester.state<ScrollableState>(board).position.pixels, 0);
        await tester.ensureVisible(find.textContaining('Completed ('));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Completed ('));
        await tester.pumpAndSettle();
        expect(tester.state<ScrollableState>(board).position.pixels, greaterThan(0));
        expect(find.widgetWithText(SpStatusBadge, 'Completed').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('wide board has no tabs (all columns visible)', (tester) async {
      await pumpTasks(tester, 1600, height: 1000);
      await tester.tap(find.byTooltip('Board view'));
      await tester.pumpAndSettle();
      expect(find.byType(TabBar), findsNothing);
    });
  });
}
