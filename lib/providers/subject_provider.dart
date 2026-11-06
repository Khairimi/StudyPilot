import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:study_app/models/subject.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectProvider with ChangeNotifier {
  List<Subject> _subjects = [];
  final _uuid = const Uuid();
  final _firestore = FirebaseFirestore.instance;

  StreamSubscription<User?>? _authSub;
  String? _uid;
  Box<Subject>? _box;
  // Bumped on every account change so results from an old account's
  // async work are ignored.
  int _generation = 0;

  List<Subject> get subjects => _subjects;

  CollectionReference<Map<String, dynamic>>? get _collection => _uid == null
      ? null
      : _firestore.collection('users').doc(_uid).collection('subjects');

  SubjectProvider() {
    // Fires immediately with the current user, then on every login/logout.
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? user) async {
    final gen = ++_generation;
    _uid = user?.uid;
    _box = null;
    _subjects = [];
    notifyListeners();

    final box = await HiveService.openSubjectsBoxForUser(user?.uid);
    if (gen != _generation) return; // account changed meanwhile
    _box = box;
    _loadSubjects();
    if (box != null) await _syncFromFirestore();
  }

  void _loadSubjects() {
    _subjects = _box?.values.toList() ?? [];
    _subjects.sort((a, b) => b.createdDate.compareTo(a.createdDate));
    notifyListeners();
  }

  // ---- Pending cloud operations (per user, stored in settingsBox) ----
  // Local changes whose Firestore write/delete has not succeeded yet. They
  // stop stale cloud data from overwriting newer local edits or restoring
  // deleted subjects, and are retried on the next sync.

  String _pendingKey(String kind) => 'pendingSubject${kind}_$_uid';

  Set<String> _pending(String kind) {
    if (_uid == null) return {};
    final raw = HiveService.settingsBox.get(_pendingKey(kind));
    return raw is List ? raw.cast<String>().toSet() : <String>{};
  }

  Future<void> _setPending(String kind, Set<String> ids) async {
    if (_uid == null) return;
    await HiveService.settingsBox.put(_pendingKey(kind), ids.toList());
  }

  Future<void> _markPending(String kind, String id, bool pending) async {
    final ids = _pending(kind);
    pending ? ids.add(id) : ids.remove(id);
    await _setPending(kind, ids);
  }

  // ---- Firestore sync ----

  Future<void> _syncFromFirestore() async {
    final collection = _collection;
    final box = _box;
    if (collection == null || box == null) return;
    final gen = _generation;

    // 1. Retry local changes that never reached the cloud.
    await _retryPending(collection, box, gen);
    if (gen != _generation) return;

    // 2. Pull cloud subjects into this user's local box (keyed by id, so
    //    no duplicates). Skip ids with unsynced local deletes/edits.
    try {
      final snapshot = await collection.get();
      if (gen != _generation) return;
      final skip = {..._pending('Deletes'), ..._pending('Upserts')};
      for (final doc in snapshot.docs) {
        if (skip.contains(doc.id)) continue;
        final subject = Subject.fromMap(doc.data());
        await box.put(subject.id, subject);
      }
      _loadSubjects();
    } catch (e) {
      debugPrint('Firestore subject sync (read) failed: $e');
    }
  }

  Future<void> _retryPending(
    CollectionReference<Map<String, dynamic>> collection,
    Box<Subject> box,
    int gen,
  ) async {
    for (final id in _pending('Deletes')) {
      if (gen != _generation) return;
      try {
        await collection.doc(id).delete();
        await _markPending('Deletes', id, false);
      } catch (e) {
        debugPrint('Firestore subject delete retry failed: $e');
        return; // likely offline/permission issue; try again next sync
      }
    }
    for (final id in _pending('Upserts')) {
      if (gen != _generation) return;
      final subject = box.get(id);
      try {
        if (subject != null) {
          await collection.doc(id).set(subject.toMap());
        }
        await _markPending('Upserts', id, false);
      } catch (e) {
        debugPrint('Firestore subject upload retry failed: $e');
        return;
      }
    }
  }

  /// Push one local change to Firestore without blocking or failing the
  /// local operation. On failure it stays pending and is retried later.
  Future<void> _pushToCloud(String id, {required bool isDelete}) async {
    final collection = _collection;
    if (collection == null) return;
    final kind = isDelete ? 'Deletes' : 'Upserts';
    await _markPending(kind, id, true);
    if (isDelete) await _markPending('Upserts', id, false);
    try {
      if (isDelete) {
        await collection.doc(id).delete();
      } else {
        final subject = _box?.get(id);
        if (subject == null) return;
        await collection.doc(id).set(subject.toMap());
      }
      await _markPending(kind, id, false);
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
    final box = _box;
    if (box == null) return;
    await box.put(subject.id, subject);
    _loadSubjects();
    await _pushToCloud(subject.id, isDelete: false);
  }

  void updateSubject(String id, String newName, int newColorValue) async {
    final subject = _box?.get(id);
    if (subject == null) return;
    subject.name = newName;
    subject.colorValue = newColorValue;
    await subject.save();
    _loadSubjects();
    // Full set() instead of update(): also works if the cloud doc is missing.
    await _pushToCloud(id, isDelete: false);
  }

  void deleteSubject(String id) async {
    final box = _box;
    if (box == null) return;
    await box.delete(id);
    _loadSubjects();
    await _pushToCloud(id, isDelete: true);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
