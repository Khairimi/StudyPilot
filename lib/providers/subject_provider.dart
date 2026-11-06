import 'package:flutter/foundation.dart';
import 'package:study_app/models/subject.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubjectProvider with ChangeNotifier {
  List<Subject> _subjects = [];
  final _uuid = const Uuid();
  final _firestore = FirebaseFirestore.instance;

  List<Subject> get subjects => _subjects;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _collection => _uid == null
      ? null
      : _firestore.collection('users').doc(_uid).collection('subjects');

  SubjectProvider() {
    _loadSubjects();
    _syncFromFirestore();
  }

  void _loadSubjects() {
    _subjects = HiveService.subjectsBox.values.toList();
    _subjects.sort((a, b) => b.createdDate.compareTo(a.createdDate));
    notifyListeners();
  }

  Future<void> _syncFromFirestore() async {
    if (_collection == null) return;
    try {
      final snapshot = await _collection!.get();
      for (final doc in snapshot.docs) {
        final subject = Subject.fromMap(doc.data() as Map<String, dynamic>);
        await HiveService.subjectsBox.put(subject.id, subject);
      }
      _loadSubjects();
    } catch (e) {
      debugPrint('Firestore sync error: $e');
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
    await HiveService.subjectsBox.put(subject.id, subject);
    await _collection?.doc(subject.id).set(subject.toMap());
    _loadSubjects();
  }

  void updateSubject(String id, String newName, int newColorValue) async {
    if (HiveService.subjectsBox.containsKey(id)) {
      final subject = HiveService.subjectsBox.get(id);
      if (subject != null) {
        subject.name = newName;
        subject.colorValue = newColorValue;
        await subject.save();
        await _collection?.doc(id).update({
          'name': newName,
          'colorValue': newColorValue,
        });
        _loadSubjects();
      }
    }
  }

  void deleteSubject(String id) async {
    await HiveService.subjectsBox.delete(id);
    await _collection?.doc(id).delete();
    _loadSubjects();
  }
}