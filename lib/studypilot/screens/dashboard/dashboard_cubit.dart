import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_summary.dart';

sealed class DashboardState {
  const DashboardState();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardNoWorkspaces extends DashboardState {
  const DashboardNoWorkspaces();
}

class DashboardError extends DashboardState {
  final String message;
  const DashboardError(this.message);
}

class DashboardReady extends DashboardState {
  final List<Workspace> workspaces;
  final DashboardSummary summary;
  final bool isDemo;
  const DashboardReady({required this.workspaces, required this.summary, required this.isDemo});
}

class DashboardCubit extends Cubit<DashboardState> {
  final WorkspaceRepository repository;
  final String userId;
  final DateTime Function() clock;

  List<Workspace> _workspaces = const [];
  int _request = 0; // ignores results of superseded loads

  DashboardCubit({required this.repository, required this.userId, DateTime Function()? clock})
    : clock = clock ?? DateTime.now,
      super(const DashboardLoading());

  Future<void> load({String? workspaceId}) async {
    final req = ++_request;
    emit(const DashboardLoading());
    try {
      final workspaces = await repository.workspacesFor(userId);
      if (req != _request || isClosed) return;
      if (workspaces.isEmpty) {
        _workspaces = const [];
        emit(const DashboardNoWorkspaces());
        return;
      }
      _workspaces = workspaces;
      final selected = workspaces.firstWhere((w) => w.id == workspaceId, orElse: () => workspaces.first);
      await _show(selected, req);
    } catch (e) {
      if (req == _request && !isClosed) emit(DashboardError('Could not load your workspaces.'));
    }
  }

  Future<void> selectWorkspace(String workspaceId) async {
    final ws = _workspaces.where((w) => w.id == workspaceId).firstOrNull;
    if (ws == null) return;
    final req = ++_request;
    try {
      await _show(ws, req);
    } catch (e) {
      if (req == _request && !isClosed) emit(DashboardError('Could not load this workspace.'));
    }
  }

  Future<void> _show(Workspace ws, int req) async {
    final tasks = await repository.tasksFor(ws.id);
    if (req != _request || isClosed) return;
    emit(
      DashboardReady(
        workspaces: _workspaces,
        isDemo: repository.isDemo,
        summary: DashboardSummary.build(workspace: ws, tasks: tasks, currentUserId: userId, now: clock()),
      ),
    );
  }
}
