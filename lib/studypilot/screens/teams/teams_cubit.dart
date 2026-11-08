import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:study_app/studypilot/data/workspace_repository.dart';
import 'package:study_app/studypilot/screens/teams/workspace_overview.dart';

sealed class TeamsState {
  const TeamsState();
}

class TeamsLoading extends TeamsState {
  const TeamsLoading();
}

class TeamsError extends TeamsState {
  final String message;
  const TeamsError(this.message);
}

class TeamsReady extends TeamsState {
  final List<WorkspaceOverview> workspaces;
  final bool isDemo;
  const TeamsReady({required this.workspaces, required this.isDemo});

  WorkspaceOverview? byId(String id) {
    for (final w in workspaces) {
      if (w.workspace.id == id) return w;
    }
    return null;
  }
}

/// Loads the user's workspaces with their projects and tasks (read-only).
class TeamsCubit extends Cubit<TeamsState> {
  final WorkspaceRepository repository;
  final String userId;
  int _request = 0;

  TeamsCubit({required this.repository, required this.userId}) : super(const TeamsLoading());

  Future<void> load() async {
    final req = ++_request;
    emit(const TeamsLoading());
    try {
      final workspaces = await repository.workspacesFor(userId);
      final overviews = await Future.wait([
        for (final ws in workspaces)
          () async {
            final (projects, tasks) =
                await (repository.projectsFor(ws.id), repository.tasksFor(ws.id)).wait;
            return WorkspaceOverview(
              workspace: ws,
              projects: List.unmodifiable(projects),
              tasks: List.unmodifiable(tasks),
            );
          }(),
      ]);
      if (req != _request || isClosed) return;
      emit(TeamsReady(workspaces: overviews, isDemo: repository.isDemo));
    } catch (_) {
      if (req == _request && !isClosed) emit(const TeamsError('Could not load your workspaces.'));
    }
  }
}
