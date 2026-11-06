import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/core/design_system.dart';

Widget _host(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: SpTheme.build(brightness, useGoogleFonts: false),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('SpTheme', () {
    test('light theme uses StudyPilot brand and neutrals', () {
      final t = SpTheme.build(Brightness.light, useGoogleFonts: false);
      expect(t.colorScheme.primary, SpColors.indigo600);
      expect(t.scaffoldBackgroundColor, SpColors.slate50);
      expect(t.brightness, Brightness.light);
    });

    test('dark theme uses dark-mode brand and night background', () {
      final t = SpTheme.build(Brightness.dark, useGoogleFonts: false);
      expect(t.colorScheme.primary, SpColors.indigo400);
      expect(t.scaffoldBackgroundColor, SpColors.night);
      expect(t.brightness, Brightness.dark);
    });

    test('keeps legacy component themes used by StudyFlow screens', () {
      final t = SpTheme.build(Brightness.light, useGoogleFonts: false);
      expect(t.bottomNavigationBarTheme.type, BottomNavigationBarType.fixed);
      expect(t.textTheme.displayMedium?.fontSize, 28);
      expect(t.textTheme.bodyMedium?.fontSize, 14);
    });
  });

  group('SpColors.memberColor', () {
    test('is stable for the same id and within the palette', () {
      final a = SpColors.memberColor('user-123');
      expect(SpColors.memberColor('user-123'), a);
      expect(SpColors.memberPalette, contains(a));
      expect(SpColors.memberColor(''), SpColors.memberPalette.first);
    });
  });

  group('SpMemberAvatar.initialsOf', () {
    test('handles one, many and empty names', () {
      expect(SpMemberAvatar.initialsOf('Khairi Rahimi'), 'KR');
      expect(SpMemberAvatar.initialsOf('  aisyah  binti  ali '), 'AA');
      expect(SpMemberAvatar.initialsOf('Zul'), 'Z');
      expect(SpMemberAvatar.initialsOf('   '), '?');
    });
  });

  group('widgets render in light and dark', () {
    for (final b in Brightness.values) {
      testWidgets('all components ($b)', (tester) async {
        var tapped = false;
        await tester.pumpWidget(_host(
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StudyPilotCard(
                  accentColor: SpColors.amber500,
                  onTap: () => tapped = true,
                  child: const Text('Card body'),
                ),
                const SpStatusBadge(status: SpTaskStatus.inProgress),
                const SpPriorityBadge(priority: SpPriority.urgent, score: 92),
                const SpSeverityBadge(severity: SpSeverity.high),
                const SpRoleBadge(role: SpRole.owner),
                const SpMemberAvatar(name: 'Khairi Rahimi'),
                const SpAvatarStack(members: [
                  (name: 'A B', id: '1', photoUrl: null),
                  (name: 'C D', id: '2', photoUrl: null),
                  (name: 'E F', id: '3', photoUrl: null),
                ], maxVisible: 2),
                const SpSectionHeading(title: 'Team Workload Health', subtitle: 'This week'),
                const SpProgressBar(value: 0.65, label: 'Project progress'),
                const SizedBox(
                  height: 320,
                  child: SpEmptyState(
                    icon: Icons.groups_rounded,
                    title: 'No workspaces yet',
                    message: 'Create or join a team to get started.',
                  ),
                ),
              ],
            ),
          ),
          brightness: b,
        ));

        expect(find.text('Card body'), findsOneWidget);
        expect(find.text('In Progress'), findsOneWidget);
        expect(find.text('Urgent · 92'), findsOneWidget);
        expect(find.text('High risk'), findsOneWidget);
        expect(find.text('Owner'), findsOneWidget);
        expect(find.text('KR'), findsOneWidget);
        expect(find.text('+1'), findsOneWidget);
        expect(find.text('65%'), findsOneWidget);
        expect(find.text('No workspaces yet'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Card body'));
        expect(tapped, isTrue);
      });
    }

    testWidgets('progress bar clamps out-of-range values', (tester) async {
      await tester.pumpWidget(_host(const SizedBox(
        width: 200,
        child: SpProgressBar(value: 1.7, label: 'Over capacity'),
      )));
      expect(find.text('100%'), findsOneWidget);
    });
  });

  test('capacity colour thresholds', () {
    expect(spCapacityColor(0.5), SpColors.emerald600);
    expect(spCapacityColor(0.8), SpColors.amber500);
    expect(spCapacityColor(1.2), SpColors.rose600);
  });
}
