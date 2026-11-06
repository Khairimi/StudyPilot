import 'package:flutter/foundation.dart';
import 'package:study_app/models/chapter.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:uuid/uuid.dart';

class ChapterProvider with ChangeNotifier {
  List<Chapter> _allChapters = [];
  final _uuid = const Uuid();

  ChapterProvider() {
    _loadAllChapters();
  }

  List<Chapter> get chapters => _allChapters;

  void _loadAllChapters() {
    _allChapters = HiveService.chaptersBox.values.toList();
    _allChapters.sort((a, b) => a.createdDate.compareTo(b.createdDate));
    notifyListeners();
  }

  void refresh() => _loadAllChapters();

  List<Chapter> getChaptersForSubject(String subjectId) =>
      _allChapters.where((c) => c.subjectId == subjectId).toList();

  // Tambah chapter dengan optional dueDate dari subject
  void addChapter(
    String subjectId,
    String title,
    String description, {
    DateTime? dueDate,
  }) {
    final newChapter = Chapter(
      id: _uuid.v4(),
      subjectId: subjectId,
      title: title,
      description: description,
      createdDate: DateTime.now(),
      dueDate: dueDate,
      isCompleted: false,
    );

    HiveService.chaptersBox.put(newChapter.id, newChapter);
    _loadAllChapters();
  }

  // Tambah chapter dengan id yang ditentukan sendiri (untuk Classroom sync)
  void addChapterWithId({
    required String id,
    required String subjectId,
    required String title,
    required String description,
    DateTime? dueDate,
    String? sourceType,
    String? classroomCourseId,
    String? classroomCourseWorkId,
    int? pdfAttachmentCount,
  }) {
    final newChapter = Chapter(
      id: id,
      subjectId: subjectId,
      title: title,
      description: description,
      createdDate: DateTime.now(),
      dueDate: dueDate,
      isCompleted: false,
      sourceType: sourceType,
      classroomCourseId: classroomCourseId,
      classroomCourseWorkId: classroomCourseWorkId,
      pdfAttachmentCount: pdfAttachmentCount,
    );

    HiveService.chaptersBox.put(newChapter.id, newChapter);
    _loadAllChapters();
  }

  // Upsert untuk Classroom sync — kalau chapter dah wujud, UPDATE dueDate dia
  // (bukan skip), supaya assignment yang dah pernah disync tak stuck dengan
  // dueDate lama/null.
  void upsertChapterFromSync({
    required String id,
    required String subjectId,
    required String title,
    required String description,
    DateTime? dueDate,
    String? sourceType,
    String? classroomCourseId,
    String? classroomCourseWorkId,
    int? pdfAttachmentCount,
    bool? isSubmitted,
  }) {
    final existing = HiveService.chaptersBox.get(id);
    if (existing != null) {
      existing.title = title;
      existing.description = description;
      existing.dueDate = dueDate;
      if (sourceType != null) existing.sourceType = sourceType;
      if (classroomCourseId != null) existing.classroomCourseId = classroomCourseId;
      if (classroomCourseWorkId != null) {
        existing.classroomCourseWorkId = classroomCourseWorkId;
      }
      existing.pdfAttachmentCount = pdfAttachmentCount;
      existing.isSubmitted = isSubmitted;
      existing.save();
    } else {
      final newChapter = Chapter(
        id: id,
        subjectId: subjectId,
        title: title,
        description: description,
        createdDate: DateTime.now(),
        dueDate: dueDate,
        isCompleted: false,
        sourceType: sourceType,
        classroomCourseId: classroomCourseId,
        classroomCourseWorkId: classroomCourseWorkId,
        pdfAttachmentCount: pdfAttachmentCount,
      );
      HiveService.chaptersBox.put(newChapter.id, newChapter);
    }
    _loadAllChapters();
  }

  // Mark as done — user manually complete
  void markAsComplete(String id, {bool completed = true}) {
    final chapter = HiveService.chaptersBox.get(id);
    if (chapter != null) {
      chapter.isCompleted = completed;
      chapter.priority = completed ? 'completed' : null;
      chapter.save();
      _loadAllChapters();
    }
  }

  void updateChapter(String id, String title, String description) {
    final chapter = HiveService.chaptersBox.get(id);
    if (chapter != null) {
      chapter.title = title;
      chapter.description = description;
      chapter.save();
      _loadAllChapters();
    }
  }

  void deleteChapter(String id) {
    HiveService.chaptersBox.delete(id);
    _loadAllChapters();
  }

  void deleteChaptersForSubject(String subjectId) {
    final keysToDelete = HiveService.chaptersBox.values
        .where((c) => c.subjectId == subjectId)
        .map((c) => c.id)
        .toList();
    for (var key in keysToDelete) {
      HiveService.chaptersBox.delete(key);
    }
    _loadAllChapters();
  }
}