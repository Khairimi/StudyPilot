import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:study_app/models/chapter.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/database/user_session.dart';
import 'package:uuid/uuid.dart';

class ChapterProvider with ChangeNotifier implements UserScopedState {
  List<Chapter> _allChapters = [];
  final _uuid = const Uuid();

  /// Active user's box, or null when signed out (operations become no-ops).
  Box<Chapter>? get _box => HiveService.activeOrNull?.chapters;

  List<Chapter> get chapters => _allChapters;

  @override
  void clearUserState() {
    _allChapters = [];
    notifyListeners();
  }

  @override
  Future<void> loadUserState(String uid) async => _loadAllChapters();

  void _loadAllChapters() {
    _allChapters = _box?.values.toList() ?? [];
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
    final box = _box;
    if (box == null) return;
    final newChapter = Chapter(
      id: _uuid.v4(),
      subjectId: subjectId,
      title: title,
      description: description,
      createdDate: DateTime.now(),
      dueDate: dueDate,
      isCompleted: false,
    );

    box.put(newChapter.id, newChapter);
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
    final box = _box;
    if (box == null) return;
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

    box.put(newChapter.id, newChapter);
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
    final box = _box;
    if (box == null) return;
    final existing = box.get(id);
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
      box.put(newChapter.id, newChapter);
    }
    _loadAllChapters();
  }

  // Mark as done — user manually complete
  void markAsComplete(String id, {bool completed = true}) {
    final chapter = _box?.get(id);
    if (chapter != null) {
      chapter.isCompleted = completed;
      chapter.priority = completed ? 'completed' : null;
      chapter.save();
      _loadAllChapters();
    }
  }

  void updateChapter(String id, String title, String description) {
    final chapter = _box?.get(id);
    if (chapter != null) {
      chapter.title = title;
      chapter.description = description;
      chapter.save();
      _loadAllChapters();
    }
  }

  void deleteChapter(String id) {
    final box = _box;
    if (box == null) return;
    box.delete(id);
    _loadAllChapters();
  }

  void deleteChaptersForSubject(String subjectId) {
    final box = _box;
    if (box == null) return;
    final keysToDelete =
        box.values.where((c) => c.subjectId == subjectId).map((c) => c.id).toList();
    for (var key in keysToDelete) {
      box.delete(key);
    }
    _loadAllChapters();
  }
}
