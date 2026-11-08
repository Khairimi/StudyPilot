import 'package:flutter_test/flutter_test.dart';
import 'package:study_app/studypilot/models/models.dart';

import 'fixtures.dart';

void main() {
  test('Workspace round-trips and exposes membership helpers', () {
    final ws = workspace();
    final back = Workspace.fromMap(ws.toMap());
    expect(back.toMap(), ws.toMap());
    expect(back.memberIds, ['ana', 'ben', 'cai']);
    expect(back.isOwner('ana'), isTrue);
    expect(back.isOwner('ben'), isFalse);
    expect(back.isMember('zed'), isFalse);
    expect(ws.toMap()['memberIds'], ['ana', 'ben', 'cai']);
  });

  test('Project round-trips; copyWith can clear dueDate', () {
    final p = Project(
      id: 'p1',
      workspaceId: 'ws1',
      title: 'Launch',
      createdBy: 'ana',
      createdAt: DateTime(2026, 11, 1),
      dueDate: DateTime(2026, 12, 1),
    );
    expect(Project.fromMap(p.toMap()).toMap(), p.toMap());
    expect(p.copyWith(dueDate: null).dueDate, isNull);
    expect(p.copyWith(title: 'X').dueDate, p.dueDate);
  });

  test('TeamTask round-trips with subtasks and activity', () {
    final t = task('t1',
            assignee: 'ana',
            priority: SpPriority.high,
            status: SpTaskStatus.inProgress,
            due: inDays(2),
            hours: 4.5,
            subtasks: const [Subtask(id: 's1', title: 'Draft', completed: true)])
        .copyWith(activity: [
      TaskActivity(
        id: 'a1',
        userId: 'ana',
        type: TaskActivityType.statusChanged,
        detail: 'todo → inProgress',
        timestamp: DateTime(2026, 11, 9),
      ),
    ]);
    final back = TeamTask.fromMap(t.toMap());
    expect(back.toMap(), t.toMap());
    expect(back.openSubtaskCount, 0);
  });

  test('copyWith distinguishes "unchanged" from "set to null"', () {
    final t = task('t', assignee: 'ana', due: inDays(1));
    expect(t.copyWith(title: 'x').assigneeId, 'ana');
    expect(t.copyWith(assigneeId: null).assigneeId, isNull);
    expect(t.copyWith(dueAt: null).dueAt, isNull);
  });

  test('fromMap tolerates missing fields and unknown enum values', () {
    final t = TeamTask.fromMap({
      'id': 'x',
      'priority': 'critical', // unknown
      'status': 42, // wrong type
      'assigneeId': '',
      'estimatedHours': '2.5',
      'subtasks': [
        {'id': 's', 'title': 'ok'},
        'garbage',
      ],
      'dueAt': 'not a date',
    });
    expect(t.priority, SpPriority.medium);
    expect(t.status, SpTaskStatus.todo);
    expect(t.assigneeId, isNull);
    expect(t.estimatedHours, 2.5);
    expect(t.subtasks, hasLength(1));
    expect(t.dueAt, isNull);

    final ws = Workspace.fromMap({'id': 'w', 'type': 'enterprise', 'workloadThresholdHours': -1});
    expect(ws.type, WorkspaceType.other);
    expect(ws.workloadThresholdHours, Workspace.defaultWorkloadThresholdHours);
    expect(ws.members, isEmpty);
  });
}
