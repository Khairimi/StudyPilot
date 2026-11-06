import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/data/demo_workspace_repository.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/teams/teams_cubit.dart';
import 'package:study_app/studypilot/screens/teams/teams_tab.dart';
import 'package:study_app/studypilot/screens/teams/workspace_overview.dart';

final fixedNow = DateTime(2026, 11, 10, 9);

DemoWorkspaceRepository demoRepo() => DemoWorkspaceRepository(
    currentUserId: 'me', currentUserName: 'Khairi Rahimi', clock: () => fixedNow);

class _EmptyRepo implements WorkspaceRepository {
  @override
  bool get isDemo => true;
  @override
  Future<List<Workspace>> workspacesFor(String userId) async => [];
  @override
  Future<List<Project>> projectsFor(String workspaceId) async => [];
  @override
  Future<List<TeamTask>> tasksFor(String workspaceId) async => [];
}

/// Spy: fails the test if anything tries to change data.
class _ReadOnlySpy extends DemoWorkspaceRepository {
  int reads = 0;
  _ReadOnlySpy() : super(currentUserId: 'me', currentUserName: 'Khairi Rahimi', clock: () => fixedNow);
  @override
  Future<List<Workspace>> workspacesFor(String userId) {
    reads++;
    return super.workspacesFor(userId);
  }
}

Future<void> pumpTeams(WidgetTester tester, {WorkspaceRepository? repo, Size size = const Size(390, 2400)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: SpTheme.build(Brightness.light, useGoogleFonts: false),
    home: Scaffold(body: TeamsTab(repository: repo ?? demoRepo(), userId: 'me')),
  ));
  await tester.pumpAndSettle();
}

Future<void> openWorkspace(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pumpAndSettle();
}

void main() {
  group('TeamValidators', () {
    test('workspace name', () {
      expect(TeamValidators.workspaceName(''), isNotNull);
      expect(TeamValidators.workspaceName('  ab '), isNotNull);
      expect(TeamValidators.workspaceName('x' * 51), isNotNull);
      expect(TeamValidators.workspaceName(' Kopi Corner '), isNull);
    });
    test('invite code is 6 letters/digits, case-insensitive', () {
      expect(TeamValidators.inviteCode(''), isNotNull);
      expect(TeamValidators.inviteCode('ABC12'), isNotNull);
      expect(TeamValidators.inviteCode('AB-123'), isNotNull);
      expect(TeamValidators.inviteCode(' demo01 '), isNull);
      expect(TeamValidators.normaliseCode(' demo01 '), 'DEMO01');
    });
    test('email', () {
      expect(TeamValidators.email(''), isNotNull);
      expect(TeamValidators.email('not-an-email'), isNotNull);
      expect(TeamValidators.email('aina@example.com'), isNull);
    });
  });

  group('WorkspaceOverview & TeamsCubit', () {
    test('loads overviews with projects, tasks and roles', () async {
      final cubit = TeamsCubit(repository: demoRepo(), userId: 'me');
      await cubit.load();
      final s = cubit.state as TeamsReady;
      expect(s.isDemo, isTrue);
      expect(s.workspaces, hasLength(2));
      final cafe = s.byId('demo-ws-cafe')!;
      expect(cafe.roleOf('me'), SpRole.owner);
      expect(s.byId('demo-ws-csc661')!.roleOf('me'), SpRole.member);
      expect(cafe.projects, hasLength(2));
      expect(cafe.tasksOf('demo-p-launch'), isNotEmpty);
      expect(cafe.progressOf('demo-p-launch'), inInclusiveRange(0.0, 1.0));
      expect(cafe.sortedMembers.first.isOwner, isTrue);
      expect(cafe.activeTasksFor('demo-daniel'), 3);
      await cubit.close();
    });
  });

  group('Teams UI', () {
    testWidgets('lists workspaces with roles and demo label', (tester) async {
      await pumpTeams(tester);
      expect(find.text('Team Workspaces'), findsOneWidget);
      expect(find.textContaining('Demo data'), findsOneWidget);
      expect(find.text('Demo · Kopi Corner Team'), findsOneWidget);
      expect(find.text('Demo · CSC661 Project Group'), findsOneWidget);
      expect(find.widgetWithText(SpRoleBadge, 'Owner'), findsOneWidget);
      expect(find.widgetWithText(SpRoleBadge, 'Member'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty state offers create and join', (tester) async {
      await pumpTeams(tester, repo: _EmptyRepo());
      expect(find.text('No workspaces yet'), findsOneWidget);
      expect(find.text('Create'), findsOneWidget);
      expect(find.text('Join with code'), findsOneWidget);
    });

    testWidgets('owner sees projects, members and demo-labelled manage actions', (tester) async {
      await pumpTeams(tester);
      await openWorkspace(tester, 'Demo · Kopi Corner Team');

      expect(find.text('Demo workspace: changes here are not saved.'), findsOneWidget);
      expect(find.text('DEMO01'), findsOneWidget);
      expect(find.text('Menu Relaunch'), findsOneWidget);
      expect(find.text('Social Media Campaign'), findsOneWidget);
      expect(find.text('Khairi Rahimi (you)'), findsOneWidget);
      expect(find.text('New project (demo)'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);

      await tester.tap(find.byTooltip('Manage Daniel Lim'));
      await tester.pumpAndSettle();
      expect(find.text('Make owner (demo)'), findsOneWidget);
      await tester.tap(find.text('Make owner (demo)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Demo only: the role of Daniel Lim was not changed'), findsOneWidget);
    });

    testWidgets('member does not see owner-only actions', (tester) async {
      await pumpTeams(tester);
      await openWorkspace(tester, 'Demo · CSC661 Project Group');
      expect(find.text('Invite'), findsNothing);
      expect(find.text('New project (demo)'), findsNothing);
      expect(find.byTooltip('Manage Mei Ling'), findsNothing);
    });

    testWidgets('create form validates and says nothing was saved', (tester) async {
      final spy = _ReadOnlySpy();
      await pumpTeams(tester, repo: spy);
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(find.text('Demo mode: nothing you submit here will be saved.'), findsOneWidget);

      await tester.tap(find.text('Create workspace (demo)'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a workspace name'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Workspace name'), 'Night Market Crew');
      await tester.tap(find.text('Create workspace (demo)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('"Night Market Crew" was not created'), findsOneWidget);
      // The list is unchanged: still exactly the two demo workspaces.
      expect(find.text('Night Market Crew'), findsNothing);
      expect(spy.reads, 1);
    });

    testWidgets('join form: invalid code, already-member code', (tester) async {
      await pumpTeams(tester);
      await tester.tap(find.text('Join with code'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'AB-1');
      await tester.tap(find.text('Join workspace (demo)'));
      await tester.pumpAndSettle();
      expect(find.text('Codes are 6 letters or numbers'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'demo02');
      await tester.tap(find.text('Join workspace (demo)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('already a member of Demo · CSC661 Project Group'), findsOneWidget);
    });

    testWidgets('invite form validates email and sends nothing', (tester) async {
      await pumpTeams(tester);
      await openWorkspace(tester, 'Demo · Kopi Corner Team');
      await tester.tap(find.text('Invite'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send invite (demo)'));
      await tester.pumpAndSettle();
      expect(find.text('Enter an email address'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextFormField, 'Email address'), 'new@team.my');
      await tester.tap(find.text('Send invite (demo)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('no invitation was sent to new@team.my'), findsOneWidget);
    });
  });
}
