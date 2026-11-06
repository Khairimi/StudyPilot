import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:study_app/models/subject.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/database/user_session.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectProvider with ChangeNotifier implements UserScopedState {
  List<Subject> _subjects = [];
  final _uuid = const Uuid();

  /// Boxes of the user this provider currently serves (captured on load).
  /// Every operation uses these, so a late async step can never read or
  /// write another account's storage.
  UserBoxes? _boxes;

  // Bumped on every account change so async results from an old account
  // are ignored.
  int _generation = 0;

  List<Subject> get subjects => _subjects;

  CollectionReference<Map<String, dynamic>> _collectionFor(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid).collection('subjects');

  @override
  void clearUserState() {
    _generation++;
    _boxes = null;
    _subjects = [];
    notifyListeners();
  }

  @override
  Future<void> loadUserState(String uid) async {
    final boxes = HiveService.activeOrNull;
    if (boxes == null || boxes.uid != uid) return;
    _generation++;
    _boxes = boxes;
    _loadSubjects();
    // Cloud sync runs in the background; it must not block the UI gate.
    unawaited(_syncFromFirestore());
  }

  bool _isCurrent(int gen, UserBoxes boxes) =>
      gen == _generation && identical(_boxes, boxes);

  void _loadSubjects() {
    _subjects = _boxes?.subjects.values.toList() ?? [];
    _subjects.sort((a, b) => b.createdDate.compareTo(a.createdDate));
    notifyListeners();
  }

  // ---- Pending cloud operations (in the user's own settings box) ----
  // Local changes whose Firestore write/delete has not succeeded yet. They
  // stop stale cloud data from overwriting newer local edits or restoring
  // deleted subjects, and are retried on the next sync.

  static String _pendingKey(String kind) => 'pendingSubject$kind';

  Set<String> _pending(UserBoxes boxes, String kind) {
    final raw = boxes.settings.get(_pendingKey(kind));
    return raw is List ? raw.cast<String>().toSet() : <String>{};
  }

  Future<void> _markPending(UserBoxes boxes, String kind, String id, bool pending) async {
    final ids = _pending(boxes, kind);
    pending ? ids.add(id) : ids.remove(id);
    await boxes.settings.put(_pendingKey(kind), ids.toList());
  }

  // ---- Firestore sync ----

  Future<void> _syncFromFirestore() async {
    final boxes = _boxes;
    if (boxes == null) return;
    final gen = _generation;
    final collection = _collectionFor(boxes.uid);

    // 1. Retry local changes that never reached the cloud.
    await _retryPending(collection, boxes, gen);
    if (!_isCurrent(gen, boxes)) return;

    // 2. Pull cloud subjects into this user's local box (keyed by id, so
    //    no duplicates). Skip ids with unsynced local deletes/edits.
    try {
      final snapshot = await collection.get();
      if (!_isCurrent(gen, boxes)) return;
      final skip = {..._pending(boxes, 'Deletes'), ..._pending(boxes, 'Upserts')};
      for (final doc in snapshot.docs) {
        if (skip.contains(doc.id)) continue;
        final subject = Subject.fromMap(doc.data());
        await boxes.subjects.put(subject.id, subject);
      }
      if (_isCurrent(gen, boxes)) _loadSubjects();
    } catch (e) {
      debugPrint('Firestore subject sync (read) failed: $e');
    }
  }

  Future<void> _retryPending(
    CollectionReference<Map<String, dynamic>> collection,
    UserBoxes boxes,
    int gen,
  ) async {
    try {
      for (final id in _pending(boxes, 'Deletes')) {
        if (!_isCurrent(gen, boxes)) return;
        await collection.doc(id).delete();
        await _markPending(boxes, 'Deletes', id, false);
      }
      for (final id in _pending(boxes, 'Upserts')) {
        if (!_isCurrent(gen, boxes)) return;
        final subject = boxes.subjects.get(id);
        if (subject != null) await collection.doc(id).set(subject.toMap());
        await _markPending(boxes, 'Upserts', id, false);
      }
    } catch (e) {
      // Likely offline / permission issue (or storage closed after an
      // account switch); stays pending and is retried next sync.
      debugPrint('Firestore subject retry failed: $e');
    }
  }

  /// Push one local change to Firestore without blocking or failing the
  /// local operation. On failure it stays pending and is retried later.
  Future<void> _pushToCloud(UserBoxes boxes, String id, {required bool isDelete}) async {
    final kind = isDelete ? 'Deletes' : 'Upserts';
    final collection = _collectionFor(boxes.uid);
    try {
      await _markPending(boxes, kind, id, true);
      if (isDelete) await _markPending(boxes, 'Upserts', id, false);
      if (isDelete) {
        await collection.doc(id).delete();
      } else {
        final subject = boxes.subjects.get(id);
        if (subject == null) return;
        await collection.doc(id).set(subject.toMap());
      }
      await _markPending(boxes, kind, id, false);
    } catch (e) {
      debugPrint('Firestore subject ${isDelete ? 'delete' : 'save'} failed '
          '(kept locally, will retry): $e');
    }
  }

  void refresh() {
    _loadSubjects();
    _syncFromFirestore();
  }

  void addSubject(String name, int colorValue) {
    final newSubject = Subject(
      id: _uuid.v4(),
      name: name,
      colorValue: colorValue,
      createdDate: DateTime.now(),
    );
    _saveSubject(newSubject);
  }

  void addSubjectModel(Subject subject) {
    _saveSubject(subject);
  }

  Future<void> _saveSubject(Subject subject) async {
    final boxes = _boxes;
    if (boxes == null) return;
    await boxes.subjects.put(subject.id, subject);
    if (identical(_boxes, boxes)) _loadSubjects();
    await _pushToCloud(boxes, subject.id, isDelete: false);
  }

  void updateSubject(String id, String newName, int newColorValue) async {
    final boxes = _boxes;
    final subject = boxes?.subjects.get(id);
    if (boxes == null || subject == null) return;
    subject.name = newName;
    subject.colorValue = newColorValue;
    await subject.save();
    if (identical(_boxes, boxes)) _loadSubjects();
    // Full set() instead of update(): also works if the cloud doc is missing.
    await _pushToCloud(boxes, id, isDelete: false);
  }

  void deleteSubject(String id) async {
    final boxes = _boxes;
    if (boxes == null) return;
    await boxes.subjects.delete(id);
    if (identical(_boxes, boxes)) _loadSubjects();
    await _pushToCloud(boxes, id, isDelete: true);
  }
}
