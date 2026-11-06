import 'package:hive/hive.dart';

part 'chapter.g.dart';

@HiveType(typeId: 1)
class Chapter extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String subjectId;

  @HiveField(2)
  String title;

  @HiveField(3)
  String description;

  @HiveField(4)
  DateTime createdDate;

  @HiveField(5)
  bool isCompleted;

  @HiveField(6)
  DateTime? dueDate;

  @HiveField(7)
  String? priority; // 'q1', 'q2', 'q3', 'q4', 'completed'

  @HiveField(8)
  String? sourceType; // 'assignment' | 'material' | 'announcement' | null (manual)

  @HiveField(9)
  String? classroomCourseId; // Google Classroom course ID (untuk sync/import balik)

  @HiveField(10)
  String? classroomCourseWorkId; // Google Classroom courseWork/material ID

  @HiveField(11)
int? pdfAttachmentCount;

 @HiveField(12)
bool? isSubmitted;

  Chapter({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.description,
    required this.createdDate,
    this.isCompleted = false,
    this.dueDate,
    this.priority,
    this.sourceType,
    this.classroomCourseId,
    this.classroomCourseWorkId,
    this.pdfAttachmentCount,
  });
}