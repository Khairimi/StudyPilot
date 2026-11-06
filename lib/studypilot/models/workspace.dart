import 'package:study_app/studypilot/core/domain_enums.dart';
import 'package:study_app/studypilot/models/model_utils.dart';

/// Kind of team. StudyPilot targets small business teams, with university
/// project groups as pilot users.
enum WorkspaceType { smallBusiness, universityProject, other }

/// A user's membership and role in a workspace.
class WorkspaceMember {
  final String userId;
  final String displayName;
  final SpRole role;
  final DateTime joinedAt;

  const WorkspaceMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
  });

  bool get isOwner => role == SpRole.owner;

  WorkspaceMember copyWith({String? displayName, SpRole? role}) => WorkspaceMember(
        userId: userId,
        displayName: displayName ?? this.displayName,
        role: role ?? this.role,
        joinedAt: joinedAt,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'displayName': displayName,
        'role': role.name,
        'joinedAt': joinedAt.toIso8601String(),
      };

  factory WorkspaceMember.fromMap(Map<String, dynamic> m) => WorkspaceMember(
        userId: m['userId'] as String? ?? '',
        displayName: m['displayName'] as String? ?? '',
        role: enumByName(SpRole.values, m['role'], SpRole.member),
        joinedAt: parseDate(m['joinedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}

/// A team workspace (Workspace → Project → Task).
class Workspace {
  /// Default weekly capacity used by workload conflict detection when a
  /// workspace has not configured its own (prototype default: 15h).
  static const double defaultWorkloadThresholdHours = 15;

  final String id;
  final String name;
  final WorkspaceType type;
  final String description;
  final String ownerId;
  final String inviteCode;
  final List<WorkspaceMember> members;
  final double workloadThresholdHours;
  final DateTime createdAt;

  const Workspace({
    required this.id,
    required this.name,
    required this.type,
    required this.ownerId,
    required this.inviteCode,
    required this.members,
    required this.createdAt,
    this.description = '',
    this.workloadThresholdHours = defaultWorkloadThresholdHours,
  });

  /// Member user ids (also stored for Firestore membership queries/rules).
  List<String> get memberIds => [for (final m in members) m.userId];

  WorkspaceMember? memberById(String userId) {
    for (final m in members) {
      if (m.userId == userId) return m;
    }
    return null;
  }

  bool isMember(String userId) => memberById(userId) != null;

  bool isOwner(String userId) => memberById(userId)?.isOwner ?? false;

  Workspace copyWith({
    String? name,
    WorkspaceType? type,
    String? description,
    String? inviteCode,
    List<WorkspaceMember>? members,
    double? workloadThresholdHours,
  }) =>
      Workspace(
        id: id,
        name: name ?? this.name,
        type: type ?? this.type,
        description: description ?? this.description,
        ownerId: ownerId,
        inviteCode: inviteCode ?? this.inviteCode,
        members: members ?? this.members,
        workloadThresholdHours: workloadThresholdHours ?? this.workloadThresholdHours,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type.name,
        'description': description,
        'ownerId': ownerId,
        'inviteCode': inviteCode,
        'members': [for (final m in members) m.toMap()],
        'memberIds': memberIds,
        'workloadThresholdHours': workloadThresholdHours,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Workspace.fromMap(Map<String, dynamic> m) {
    final threshold = parseDouble(m['workloadThresholdHours'], defaultWorkloadThresholdHours);
    return Workspace(
      id: m['id'] as String? ?? '',
      name: m['name'] as String? ?? '',
      type: enumByName(WorkspaceType.values, m['type'], WorkspaceType.other),
      description: m['description'] as String? ?? '',
      ownerId: m['ownerId'] as String? ?? '',
      inviteCode: m['inviteCode'] as String? ?? '',
      members: [for (final mm in parseMapList(m['members'])) WorkspaceMember.fromMap(mm)],
      workloadThresholdHours: threshold > 0 ? threshold : defaultWorkloadThresholdHours,
      createdAt: parseDate(m['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
