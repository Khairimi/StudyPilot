import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/screens/shell/studypilot_shell.dart';

Future<void> _pumpShell(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
    home: const StudyPilotShell(
      homeTabOverride: Text('Home stub'),
      profileTabOverride: Text('Profile stub'),
    ),
  ));
}

void main() {
  testWidgets('phone: bottom NavigationBar with 5 tabs and switching', (tester) async {
    await _pumpShell(tester, const Size(390, 844));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    for (final label in ['Home', 'Teams', 'Tasks', 'Reports', 'Profile']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.text('Home stub'), findsOneWidget);

    await tester.tap(find.text('Tasks'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Tasks'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Profile stub'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide: NavigationRail replaces bottom bar', (tester) async {
    await _pumpShell(tester, const Size(1280, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.text('Reports coming soon'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('notifications bell opens placeholder', (tester) async {
    await _pumpShell(tester, const Size(390, 844));
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Notifications coming soon'), findsOneWidget);
  });
}
