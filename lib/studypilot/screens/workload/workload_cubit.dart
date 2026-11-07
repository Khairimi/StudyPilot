import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/logic/workload_engine.dart';
import 'package:study_app/studypilot/models/models.dart';

sealed class WorkloadState {
  const WorkloadState();
}

class WorkloadLoading extends WorkloadState {
  const WorkloadLoading();
}

class WorkloadNoWorkspaces extends WorkloadState {
  const WorkloadNoWorkspaces();
}

class WorkloadError extends WorkloadState {
  final String message;
  const WorkloadError(this.message);
}

class WorkloadReady extends WorkloadState {
  final List<Workspace> workspaces;
  final Workspace workspace;
  final List<TeamTask> tasks;
  final List<MemberWorkload> workloads;
  final List<WorkloadConflict> conflicts;
  final bool isOwner;
  final bool isDemo;

  const WorkloadReady({
    required this.workspaces,
    required this.workspace,
    required this.tasks,
    required this.workloads,
    required this.conflicts,
    required this.isOwner,
    required this.isDemo,
  });

  String memberName(String? id) =>
      id == null ? 'Unassigned' : workspace.memberById(id)?.displayName ?? 'Former member';

  TeamTask? taskById(String id) => tasks.where((t) => t.id == id).firstOrNull;

  double get teamHours => workloads.fold(0.0, (s, w) => s + w.activeHours);
  double get teamCapacity => workloads.fold(0.0, (s, w) => s + w.thresholdHours);
  int get membersOverCapacity => workloads.where((w) => w.isOverCapacity).length;
}

/// Read-only workload analysis for one workspace (Phase 3 engine). It never
/// reassigns or edits tasks.
class WorkloadCubit extends Cubit<WorkloadState> {
  final WorkspaceRepository repository;
  final String userId;
  final DateTime Function() clock;

  List<Workspace> _workspaces = const [];
  int _request = 0;

  WorkloadCubit({required this.repository, required this.userId, DateTime Function()? clock})
      : clock = clock ?? DateTime.now,
        super(const WorkloadLoading());

  Future<void> load({String? workspaceId}) async {
    final req = ++_request;
    emit(const WorkloadLoading());
    try {
      final workspaces = await repository.workspacesFor(userId);
      if (req != _request || isClosed) return;
      _workspaces = workspaces;
      if (workspaces.isEmpty) {
        emit(const WorkloadNoWorkspaces());
        return;
      }
      final ws = workspaces.firstWhere((w) => w.id == workspaceId, orElse: () => workspaces.first);
      await _show(ws, req);
    } catch (_) {
      if (req == _request && !isClosed) emit(const WorkloadError('Could not load workload data.'));
    }
  }

  Future<void> selectWorkspace(String workspaceId) async {
    final ws = _workspaces.where((w) => w.id == workspaceId).firstOrNull;
    if (ws == null) return;
    final req = ++_request;
    try {
      await _show(ws, req);
    } catch (_) {
      if (req == _request && !isClosed) emit(const WorkloadError('Could not load this workspace.'));
    }
  }

  Future<void> _show(Workspace ws, int req) async {
    final tasks = await repository.tasksFor(ws.id);
    if (req != _request || isClosed) return;
    final now = clock();
    emit(WorkloadReady(
      workspaces: _workspaces,
      workspace: ws,
      tasks: tasks,
      workloads: WorkloadEngine.memberWorkloads(ws, tasks, now),
      conflicts: WorkloadEngine.detectConflicts(ws, tasks, now),
      isOwner: ws.isOwner(userId),
      isDemo: repository.isDemo,
    ));
  }
}
