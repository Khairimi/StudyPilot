import 'package:study_app/studypilot/models/models.dart';

/// Read access to a user's team workspaces and their projects/tasks.
/// Phase 4 uses [DemoWorkspaceRepository]; a Firestore implementation will
/// replace it in the Firebase integration phase without changing the UI.
abstract class WorkspaceRepository {
  /// True when the data is sample data (UI must label it as demo).
  bool get isDemo;

  Future<List<Workspace>> workspacesFor(String userId);
  Future<List<Project>> projectsFor(String workspaceId);
  Future<List<TeamTask>> tasksFor(String workspaceId);
}
