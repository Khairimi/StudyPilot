import 'package:flutter/foundation.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/database/user_session.dart';
import 'package:study_app/models/academic/subject_attendance.dart';
import 'package:study_app/models/academic/attendance_record.dart';
import 'package:study_app/models/academic/class_schedule.dart';

class AcademicProvider extends ChangeNotifier implements UserScopedState {
  /// Active user's boxes, or null when signed out. Multi-step operations
  /// capture this once so later awaits cannot switch to another user.
  UserBoxes? get _boxes => HiveService.activeOrNull;

  @override
  void clearUserState() => notifyListeners();

  @override
  Future<void> loadUserState(String uid) async => notifyListeners();

  // ── Subject CRUD ──

  List<SubjectAttendance> get subjects => _boxes?.academicSubjects.values.toList() ?? [];

  Future<void> addSubject(String name, double requiredPercentage) async {
    final b = _boxes;
    if (b == null) return;
    final s = SubjectAttendance(subjectName: name, requiredPercentage: requiredPercentage);
    await b.academicSubjects.put(s.id, s);
    notifyListeners();
  }

  Future<void> deleteSubject(String id) async {
    final b = _boxes;
    if (b == null) return;
    await b.academicSubjects.delete(id);
    // Delete related records & schedules
    final recordKeys = b.attendanceRecords.values.where((r) => r.subjectId == id).map((r) => r.id).toList();
    for (var k in recordKeys) { await b.attendanceRecords.delete(k); }
    final schedKeys = b.classSchedules.values.where((s) => s.subjectId == id).map((s) => s.id).toList();
    for (var k in schedKeys) { await b.classSchedules.delete(k); }
    notifyListeners();
  }

  Future<void> clearAllData() async {
    final b = _boxes;
    if (b == null) return;
    await b.academicSubjects.clear();
    await b.attendanceRecords.clear();
    await b.classSchedules.clear();
    notifyListeners();
  }

  void refresh() {
    notifyListeners();
  }

  // ── Attendance Marking ──

  Future<void> markAttendance(String subjectId, String status, {String? note}) async {
    final b = _boxes;
    if (b == null) return;
    final subject = b.academicSubjects.get(subjectId);
    if (subject == null) return;

    subject.totalClasses++;
    if (status == 'present') subject.attendedClasses++;
    await subject.save();

    final record = AttendanceRecord(subjectId: subjectId, status: status, note: note);
    await b.attendanceRecords.put(record.id, record);
    notifyListeners();
  }

  Future<void> deleteRecord(String recordId) async {
    final b = _boxes;
    if (b == null) return;
    final record = b.attendanceRecords.get(recordId);
    if (record == null) return;

    final subject = b.academicSubjects.get(record.subjectId);
    if (subject != null) {
      subject.totalClasses--;
      if (record.status == 'present') subject.attendedClasses--;
      await subject.save();
    }
    await b.attendanceRecords.delete(recordId);
    notifyListeners();
  }

  List<AttendanceRecord> getRecordsForSubject(String subjectId) {
    final records = _boxes?.attendanceRecords.values.where((r) => r.subjectId == subjectId).toList() ?? [];
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  // ── Schedule CRUD ──

  List<ClassSchedule> get schedules => _boxes?.classSchedules.values.toList() ?? [];

  List<ClassSchedule> getScheduleForDay(int dayOfWeek) {
    final list = _boxes?.classSchedules.values.where((s) => s.dayOfWeek == dayOfWeek).toList() ?? [];
    list.sort((a, b) => a.startTime.compareTo(b.startTime));
    return list;
  }

  List<ClassSchedule> getScheduleForSubject(String subjectId) {
    return _boxes?.classSchedules.values.where((s) => s.subjectId == subjectId).toList() ?? [];
  }

  Future<void> addSchedule(String subjectId, int dayOfWeek, String startTime, String endTime, String? room) async {
    final b = _boxes;
    if (b == null) return;
    final s = ClassSchedule(subjectId: subjectId, dayOfWeek: dayOfWeek, startTime: startTime, endTime: endTime, room: room);
    await b.classSchedules.put(s.id, s);
    notifyListeners();
  }

  Future<void> deleteSchedule(String id) async {
    final b = _boxes;
    if (b == null) return;
    await b.classSchedules.delete(id);
    notifyListeners();
  }

  // ── Dashboard Stats ──

  double get overallAttendance {
    if (subjects.isEmpty) return 100.0;
    int totalAll = 0, attendedAll = 0;
    for (var s in subjects) {
      totalAll += s.totalClasses;
      attendedAll += s.attendedClasses;
    }
    return totalAll == 0 ? 100.0 : (attendedAll / totalAll) * 100;
  }

  int get subjectsAtRisk => subjects.where((s) => !s.isSafe && s.totalClasses > 0).length;

  int get missedThisMonth {
    final now = DateTime.now();
    return _boxes?.attendanceRecords.values
            .where((r) => r.status == 'absent' && r.date.year == now.year && r.date.month == now.month)
            .length ??
        0;
  }

  String? getSubjectName(String subjectId) {
    final s = _boxes?.academicSubjects.get(subjectId);
    return s?.subjectName;
  }
}
