import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/models/models.dart';

/// In-memory DEMO data for building and presenting the UI before Firestore
/// integration. All names are fictional; workspace names start with
/// "Demo ·". Dates are relative to [clock] so the dashboard always shows
/// due-today / overdue items and a workload conflict.
class DemoWorkspaceRepository implements WorkspaceRepository {
  final String currentUserId;
  final String currentUserName;
  final DateTime Function() clock;

  DemoWorkspaceRepository({
    required this.currentUserId,
    required this.currentUserName,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  static const demoPrefix = 'Demo · ';
  static const _aina = 'demo-aina';
  static const _daniel = 'demo-daniel';
  static const _mei = 'demo-meiling';

  @override
  bool get isDemo => true;

  late final Map<String, ({Workspace ws, List<Project> projects, List<TeamTask> tasks})> _data =
      _build();

  @override
  Future<List<Workspace>> workspacesFor(String userId) async => [
        for (final d in _data.values)
          if (d.ws.isMember(userId)) d.ws,
      ];

  @override
  Future<List<Project>> projectsFor(String workspaceId) async =>
      _data[workspaceId]?.projects ?? const [];

  @override
  Future<List<TeamTask>> tasksFor(String workspaceId) async =>
      _data[workspaceId]?.tasks ?? const [];

  Map<String, ({Workspace ws, List<Project> projects, List<TeamTask> tasks})> _build() {
    final now = clock();
    DateTime day(int offset, [int hour = 17]) =>
        DateTime(now.year, now.month, now.day + offset, hour);
    DateTime ago(int hours) => now.subtract(Duration(hours: hours));

    WorkspaceMember member(String id, String name, SpRole role) =>
        WorkspaceMember(userId: id, displayName: name, role: role, joinedAt: day(-30));

    TaskActivity act(String id, String who, TaskActivityType type, int hoursAgo, [String detail = '']) =>
        TaskActivity(id: id, userId: who, type: type, timestamp: ago(hoursAgo), detail: detail);

    // ── Workspace 1: small business team (primary target) ──
    const ws1 = 'demo-ws-cafe';
    final cafe = Workspace(
      id: ws1,
      name: '${demoPrefix}Kopi Corner Team',
      type: WorkspaceType.smallBusiness,
      ownerId: currentUserId,
      inviteCode: 'DEMO01',
      createdAt: day(-30),
      members: [
        member(currentUserId, currentUserName, SpRole.owner),
        member(_aina, 'Aina Sofea', SpRole.member),
        member(_daniel, 'Daniel Lim', SpRole.member),
        member(_mei, 'Mei Ling', SpRole.member),
      ],
    );
    final cafeProjects = [
      Project(id: 'demo-p-launch', workspaceId: ws1, title: 'Menu Relaunch', createdBy: currentUserId, createdAt: day(-20), dueDate: day(10)),
      Project(id: 'demo-p-social', workspaceId: ws1, title: 'Social Media Campaign', createdBy: currentUserId, createdAt: day(-15), dueDate: day(21)),
    ];
    TeamTask t(String id, String title, String? who, {String project = 'demo-p-launch', SpPriority p = SpPriority.medium, SpTaskStatus s = SpTaskStatus.todo, DateTime? due, double h = 0, List<Subtask> sub = const [], DateTime? done, List<TaskActivity> log = const []}) =>
        TeamTask(id: id, workspaceId: ws1, projectId: project, title: title, assigneeId: who, createdBy: currentUserId, createdAt: day(-14), priority: p, status: s, dueAt: due, estimatedHours: h, subtasks: sub, completedAt: done, activity: log);

    final cafeTasks = [
      t('demo-t1', 'Finalise new menu pricing', currentUserId, p: SpPriority.urgent, s: SpTaskStatus.inProgress, due: day(0), h: 4,
          sub: const [Subtask(id: 's1', title: 'Supplier quotes', completed: true), Subtask(id: 's2', title: 'Margin check')],
          log: [act('a1', currentUserId, TaskActivityType.statusChanged, 3, 'To Do → In Progress')]),
      t('demo-t2', 'Approve packaging design', currentUserId, p: SpPriority.high, due: day(2), h: 2),
      t('demo-t3', 'Train staff on new recipes', _aina, p: SpPriority.medium, s: SpTaskStatus.inProgress, due: day(5), h: 6,
          log: [act('a2', _aina, TaskActivityType.statusChanged, 20, 'To Do → In Progress')]),
      t('demo-t4', 'Order seasonal ingredients', _daniel, p: SpPriority.high, due: day(-1), h: 3),
      t('demo-t5', 'Update POS menu items', _daniel, p: SpPriority.medium, due: day(1), h: 4),
      t('demo-t6', 'Book food photographer', _daniel, project: 'demo-p-social', p: SpPriority.low, due: day(2), h: 2,
          log: [act('a3', currentUserId, TaskActivityType.assigned, 6, 'Daniel Lim')]),
      t('demo-t7', 'Write Instagram captions', _mei, project: 'demo-p-social', p: SpPriority.medium, s: SpTaskStatus.inReview, due: day(4), h: 3,
          log: [act('a4', _mei, TaskActivityType.statusChanged, 2, 'In Progress → In Review')]),
      t('demo-t8', 'Plan launch-day promotion', null, project: 'demo-p-social', p: SpPriority.medium, due: day(9), h: 5),
      t('demo-t9', 'Survey regular customers', _aina, project: 'demo-p-social', s: SpTaskStatus.completed, due: day(-3), h: 4, done: day(-4, 15),
          log: [act('a5', _aina, TaskActivityType.completed, 30)]),
      t('demo-t10', 'Clean up recipe costing sheet', _mei, s: SpTaskStatus.completed, due: day(-2), h: 3, done: day(-2, 11),
          log: [act('a6', _mei, TaskActivityType.completed, 50)]),
      t('demo-t11', 'Draft new menu layout', currentUserId, s: SpTaskStatus.completed, due: day(-6), h: 5, done: day(-6, 16),
          log: [act('a7', currentUserId, TaskActivityType.completed, 100)]),
    ];

    // ── Workspace 2: university project group (pilot users) ──
    const ws2 = 'demo-ws-csc661';
    final uni = Workspace(
      id: ws2,
      name: '${demoPrefix}CSC661 Project Group',
      type: WorkspaceType.universityProject,
      ownerId: _aina,
      inviteCode: 'DEMO02',
      createdAt: day(-25),
      members: [
        member(_aina, 'Aina Sofea', SpRole.owner),
        member(currentUserId, currentUserName, SpRole.member),
        member(_mei, 'Mei Ling', SpRole.member),
      ],
    );
    final uniProjects = [
      Project(id: 'demo-p-report', workspaceId: ws2, title: 'Final Report', createdBy: _aina, createdAt: day(-25), dueDate: day(14)),
    ];
    TeamTask u(String id, String title, String? who, {SpPriority p = SpPriority.medium, SpTaskStatus s = SpTaskStatus.todo, DateTime? due, double h = 0, DateTime? done, List<TaskActivity> log = const []}) =>
        TeamTask(id: id, workspaceId: ws2, projectId: 'demo-p-report', title: title, assigneeId: who, createdBy: _aina, createdAt: day(-20), priority: p, status: s, dueAt: due, estimatedHours: h, completedAt: done, activity: log);
    final uniTasks = [
      u('demo-u1', 'Literature review chapter', currentUserId, p: SpPriority.high, s: SpTaskStatus.inProgress, due: day(3), h: 8,
          log: [act('b1', currentUserId, TaskActivityType.statusChanged, 5, 'To Do → In Progress')]),
      u('demo-u2', 'System architecture diagram', _mei, p: SpPriority.medium, due: day(6), h: 4),
      u('demo-u3', 'Prepare presentation slides', _aina, p: SpPriority.low, due: day(12), h: 3),
      u('demo-u4', 'Requirements analysis', _aina, s: SpTaskStatus.completed, due: day(-5), h: 6, done: day(-5, 10),
          log: [act('b2', _aina, TaskActivityType.completed, 120)]),
    ];

    return {
      ws1: (ws: cafe, projects: cafeProjects, tasks: cafeTasks),
      ws2: (ws: uni, projects: uniProjects, tasks: uniTasks),
    };
  }
}
