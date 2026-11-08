import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/database/user_session.dart';
import 'package:study_app/models/flashcard.dart';

class FlashcardProvider extends ChangeNotifier implements UserScopedState {
  /// Active user's box, or null when signed out (operations become no-ops).
  Box<Flashcard>? get _flashcardsBox => HiveService.activeOrNull?.flashcards;

  @override
  void clearUserState() => notifyListeners();

  @override
  Future<void> loadUserState(String uid) async => notifyListeners();

  List<Flashcard> get flashcards => _flashcardsBox?.values.toList() ?? [];

  List<Flashcard> getFlashcardsForContext(String? subjectId, String? chapterId) {
    final box = _flashcardsBox;
    if (box == null) return [];
    if (subjectId == 'general') {
      return box.values.where((fc) => fc.subjectId == 'general').toList();
    }
    return box.values.where((fc) => fc.subjectId == subjectId && fc.chapterId == chapterId).toList();
  }

  Future<void> addFlashcard(String front, String back, String? subjectId, String? chapterId) async {
    final box = _flashcardsBox;
    if (box == null) return;
    final fc = Flashcard(front: front, back: back, subjectId: subjectId, chapterId: chapterId);
    await box.put(fc.id, fc);
    notifyListeners();
  }

  Future<void> deleteFlashcard(String id) async {
    final box = _flashcardsBox;
    if (box == null) return;
    await box.delete(id);
    notifyListeners();
  }
}
