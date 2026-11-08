import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

/// The workspace currently selected across StudyPilot (Home, Tasks and
/// Workload Insights). [projectId] is a one-off request for Tasks to filter
/// by a project (e.g. after tapping a project card); other screens ignore it.
class WorkspaceSelection {
  final String? workspaceId;
  final String? projectId;
  const WorkspaceSelection(this.workspaceId, {this.projectId});
}

/// Single shared source of truth for the selected workspace. Owned by the
/// StudyPilot shell. Screens validate the id against the signed-in user's
/// own workspaces and never show a workspace they are not a member of.
class WorkspaceSelectionCubit extends Cubit<WorkspaceSelection> {
  WorkspaceSelectionCubit([String? initial]) : super(WorkspaceSelection(initial));

  String? get workspaceId => state.workspaceId;

  void select(String workspaceId) {
    if (workspaceId == state.workspaceId && state.projectId == null) return;
    emit(WorkspaceSelection(workspaceId));
  }

  /// Selects [workspaceId] and asks Tasks to filter by [projectId].
  void focusProject(String workspaceId, String projectId) =>
      emit(WorkspaceSelection(workspaceId, projectId: projectId));
}

/// Connects one screen cubit to the (optional) shared selection.
class WorkspaceSelectionLink {
  final WorkspaceSelectionCubit? _selection;
  StreamSubscription<WorkspaceSelection>? _sub;

  WorkspaceSelectionLink(this._selection, void Function(WorkspaceSelection) onChange) {
    _sub = _selection?.stream.listen(onChange);
  }

  String? get workspaceId => _selection?.workspaceId;

  void publish(String workspaceId) => _selection?.select(workspaceId);

  Future<void> cancel() async => _sub?.cancel();
}
