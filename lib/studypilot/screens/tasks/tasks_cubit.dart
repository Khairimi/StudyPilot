import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/tasks/task_filter.dart';

enum TaskViewMode { list, board }

sealed class TasksState {
  const TasksState();
}

class TasksLoading extends TasksState {
  const TasksLoading();
}

class TasksNoWorkspaces extends TasksState {
  const TasksNoWorkspaces();
}

class TasksError extends TasksState {
  final String message;
  const TasksError(this.message);
}

class TasksReady extends TasksState {
  final List<Workspace> workspaces;
  final Workspace workspace;
  final List<Project> projects;

  /// Every task in the workspace (unfiltered).
  final List<TeamTask> allTasks;

  /// Filtered and ranked by Smart Priority.
  final List<TeamTask> visible;
  final TaskFilter filter;
  final TaskViewMode mode;
  final bool isDemo;

  const TasksReady({
    required this.workspaces,
    required this.workspace,
    required this.projects,
    required this.allTasks,
    required this.visible,
    required this.filter,
    required this.mode,
    required this.isDemo,
  });

  String projectName(String id) {
    for (final p in projects) {
      if (p.id == id) return p.title;
    }
    return 'No project';
  }

  String memberName(String? userId) => userId == null
      ? 'Unassigned'
      : workspace.memberById(userId)?.displayName ?? 'Former member';
}

/// Tasks tab state: workspace, filters and view mode. Read-only: edits are
/// demo previews handled by the UI and never written to the repository.
class TasksCubit extends Cubit<TasksState> {
  final WorkspaceRepository repository;
  final String userId;
  final DateTime Function() clock;

  List<Workspace> _workspaces = const [];
  TaskFilter _filter = const TaskFilter();
  TaskViewMode _mode = TaskViewMode.list;
  int _request = 0;

  TasksCubit({required this.repository, required this.userId, DateTime Function()? clock})
      : clock = clock ?? DateTime.now,
        super(const TasksLoading());

  Future<void> load({String? workspaceId}) async {
    final req = ++_request;
    emit(const TasksLoading());
    try {
      final workspaces = await repository.workspacesFor(userId);
      if (req != _request || isClosed) return;
      _workspaces = workspaces;
      if (workspaces.isEmpty) {
        emit(const TasksNoWorkspaces());
        return;
      }
      final ws = workspaces.firstWhere((w) => w.id == workspaceId, orElse: () => workspaces.first);
      await _show(ws, req);
    } catch (_) {
      if (req == _request && !isClosed) emit(const TasksError('Could not load tasks.'));
    }
  }

  Future<void> selectWorkspace(String workspaceId) async {
    final ws = _workspaces.where((w) => w.id == workspaceId).firstOrNull;
    if (ws == null) return;
    final req = ++_request;
    // Project filter belongs to the old workspace.
    _filter = _filter.copyWith(projectId: null);
    try {
      await _show(ws, req);
    } catch (_) {
      if (req == _request && !isClosed) emit(const TasksError('Could not load this workspace.'));
    }
  }

  void setFilter(TaskFilter filter) {
    _filter = filter;
    _reapply();
  }

  void setQuery(String query) => setFilter(_filter.copyWith(query: query));

  void clearFilters() => setFilter(TaskFilter(query: _filter.query));

  void setMode(TaskViewMode mode) {
    _mode = mode;
    _reapply();
  }

  void _reapply() {
    final s = state;
    if (s is! TasksReady) return;
    emit(_ready(s.workspace, s.projects, s.allTasks));
  }

  Future<void> _show(Workspace ws, int req) async {
    final (projects, tasks) = await (repository.projectsFor(ws.id), repository.tasksFor(ws.id)).wait;
    if (req != _request || isClosed) return;
    emit(_ready(ws, projects, tasks));
  }

  TasksReady _ready(Workspace ws, List<Project> projects, List<TeamTask> tasks) => TasksReady(
        workspaces: _workspaces,
        workspace: ws,
        projects: projects,
        allTasks: tasks,
        visible: _filter.apply(tasks, userId, clock()),
        filter: _filter,
        mode: _mode,
        isDemo: repository.isDemo,
      );
}
