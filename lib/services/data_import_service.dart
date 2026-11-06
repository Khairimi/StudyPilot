import 'dart:convert';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/models/mappers/subject_mapper.dart';
import 'package:study_app/models/mappers/chapter_mapper.dart';
import 'package:study_app/models/mappers/note_mapper.dart';
import 'package:study_app/models/mappers/study_session_mapper.dart';
import 'package:study_app/models/mappers/flashcard_mapper.dart';
import 'package:study_app/models/mappers/todo_mapper.dart';
import 'package:study_app/models/mappers/academic_mapper.dart';
import 'package:study_app/models/mappers/timestamp_mapper.dart';
import 'package:study_app/models/mappers/mind_map_mapper.dart';


class ImportResult {
  final bool success;
  final String message;
  final Map<String, int> counts;

  const ImportResult({
    required this.success,
    required this.message,
    this.counts = const {},
  });
}

class DataImportService {
  static const int supportedVersion = 1;

  /// Parse and import data from a JSON string.
  ///
  /// If [clearFirst] is true, all existing Hive data is removed before import.
  static Future<ImportResult> importFromJsonString(
    String jsonString, {
    bool clearFirst = true,
  }) async {
    // ── Parse ──────────────────────────────────────────────────────────────
    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return const ImportResult(
          success: false, message: 'Invalid JSON — please check your input.');
    }

    // ── Validate version ───────────────────────────────────────────────────
    final version = data['version'];
    if (version == null) {
      return const ImportResult(
          success: false, message: 'Missing "version" field in backup file.');
    }
    if (version is! int || version > supportedVersion) {
      return ImportResult(
          success: false,
          message:
              'Unsupported backup version "$version". This app supports version $supportedVersion.');
    }

    // ── Validate required keys ─────────────────────────────────────────────
    for (final key in ['subjects', 'chapters', 'notes']) {
      if (data[key] == null) {
        return ImportResult(
            success: false,
            message: 'Backup is missing required section "$key".');
      }
    }

    // ── Target: the signed-in user's own storage only ─────────────────────
    // Captured once so the whole import goes to the same user even if the
    // account changes mid-way (stale writes then fail on closed boxes).
    final b = HiveService.activeOrNull;
    if (b == null) {
      return ImportResult(success: false, message: 'Sign in before importing a backup.');
    }

    // ── Clear existing data ────────────────────────────────────────────────
    if (clearFirst) {
      await b.subjects.clear();
      await b.chapters.clear();
      await b.notes.clear();
      await b.studyTime.clear();
      await b.flashcards.clear();
      await b.todos.clear();
      await b.academicSubjects.clear();
      await b.attendanceRecords.clear();
      await b.classSchedules.clear();
      await b.timestamps.clear();
      await b.mindMaps.clear();
    }

    // ── Helper to safely cast list ─────────────────────────────────────────
    List<Map<String, dynamic>> asList(String key) {
      final raw = data[key];
      if (raw == null) return [];
      return (raw as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }

    final counts = <String, int>{};

    // ── Import in dependency order ─────────────────────────────────────────
    try {
      // Subjects
      final subjects = asList('subjects');
      for (final m in subjects) {
        final s = m.toSubject();
        await b.subjects.put(s.id, s);
      }
      counts['subjects'] = subjects.length;

      // Chapters
      final chapters = asList('chapters');
      for (final m in chapters) {
        final c = m.toChapter();
        await b.chapters.put(c.id, c);
      }
      counts['chapters'] = chapters.length;

      // Notes (includes blocks)
      final notes = asList('notes');
      for (final m in notes) {
        final n = m.toNote();
        await b.notes.put(n.id, n);
      }
      counts['notes'] = notes.length;

      // Study Sessions
      final sessions = asList('studySessions');
      for (final m in sessions) {
        final s = m.toStudySession();
        await b.studyTime.put(s.id, s);
      }
      counts['studySessions'] = sessions.length;

      // Flashcards
      final flashcards = asList('flashcards');
      for (final m in flashcards) {
        final f = m.toFlashcard();
        await b.flashcards.put(f.id, f);
      }
      counts['flashcards'] = flashcards.length;

      // Todos (includes sub-tasks)
      final todos = asList('todos');
      for (final m in todos) {
        final t = m.toTodo();
        await b.todos.put(t.id, t);
      }
      counts['todos'] = todos.length;

      // Academic Subjects
      final academicSubjects = asList('academicSubjects');
      for (final m in academicSubjects) {
        final a = m.toSubjectAttendance();
        await b.academicSubjects.put(a.id, a);
      }
      counts['academicSubjects'] = academicSubjects.length;

      // Attendance Records
      final records = asList('attendanceRecords');
      for (final m in records) {
        final r = m.toAttendanceRecord();
        await b.attendanceRecords.put(r.id, r);
      }
      counts['attendanceRecords'] = records.length;

      // Class Schedules
      final schedules = asList('classSchedules');
      for (final m in schedules) {
        final s = m.toClassSchedule();
        await b.classSchedules.put(s.id, s);
      }
      counts['classSchedules'] = schedules.length;

      // Timestamps
      final timestamps = asList('timestamps');
      for (final m in timestamps) {
        final t = m.toTimestamp();
        await b.timestamps.put(t.id, t);
      }
      counts['timestamps'] = timestamps.length;

      // Mind Maps
      final mindMaps = asList('mindMaps');
      for (final m in mindMaps) {
        final mm = m.toMindMap();
        await b.mindMaps.put(mm.id, mm);
      }
      counts['mindMaps'] = mindMaps.length;

      

      // Settings
      final settings = data['settings'] as Map<String, dynamic>?;
      // Only user-specific keys are restored, into this user's settings.
      // Device-wide settings and other users' keys are never imported.
      final name = settings?['student_name'];
      if (name is String && name.isNotEmpty) {
        await b.settings.put('student_name', name);
      }
    } catch (e) {
      return ImportResult(
          success: false,
          message: 'Import failed while restoring data: $e');
    }

    final total = counts.values.fold(0, (a, b) => a + b);
    return ImportResult(
      success: true,
      message: 'Successfully imported $total items.',
      counts: counts,
    );
  }
}
