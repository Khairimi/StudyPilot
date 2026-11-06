import 'package:study_app/studypilot/core/domain_enums.dart' show enumByName;
import 'package:study_app/studypilot/models/model_utils.dart';

enum ProjectStatus { active, onHold, completed }

/// A shared project inside a workspace. Kept deliberately simple (no
/// sprints/milestone tracking); progress is derived from its tasks.
class Project {
  final String id;
  final String workspaceId;
  final String title;
  final String description;
  final ProjectStatus status;
  final DateTime? dueDate;
  final String createdBy;
  final DateTime createdAt;

  const Project({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.createdBy,
    required this.createdAt,
    this.description = '',
    this.status = ProjectStatus.active,
    this.dueDate,
  });

  Project copyWith({
    String? title,
    String? description,
    ProjectStatus? status,
    Object? dueDate = unset,
  }) =>
      Project(
        id: id,
        workspaceId: workspaceId,
        title: title ?? this.title,
        description: description ?? this.description,
        status: status ?? this.status,
        dueDate: identical(dueDate, unset) ? this.dueDate : dueDate as DateTime?,
        createdBy: createdBy,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'workspaceId': workspaceId,
        'title': title,
        'description': description,
        'status': status.name,
        'dueDate': isoOrNull(dueDate),
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Project.fromMap(Map<String, dynamic> m) => Project(
        id: m['id'] as String? ?? '',
        workspaceId: m['workspaceId'] as String? ?? '',
        title: m['title'] as String? ?? '',
        description: m['description'] as String? ?? '',
        status: enumByName(ProjectStatus.values, m['status'], ProjectStatus.active),
        dueDate: parseDate(m['dueDate']),
        createdBy: m['createdBy'] as String? ?? '',
        createdAt: parseDate(m['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
}
