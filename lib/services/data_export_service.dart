import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:study_app/services/backup_file_saver.dart';
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


class DataExportService {
  static const int exportVersion = 1;

  /// Build a JSON-serializable map of the signed-in user's data only.
  /// Throws [NoActiveUserError] when no user storage is active.
  static Map<String, dynamic> buildExportMap() {
    final b = HiveService.requireActive();
    return {
      'version': exportVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'subjects':
          b.subjects.values.map((s) => s.toMap()).toList(),
      'chapters':
          b.chapters.values.map((c) => c.toMap()).toList(),
      'notes': b.notes.values.map((n) => n.toMap()).toList(),
      'studySessions':
          b.studyTime.values.map((s) => s.toMap()).toList(),
      'flashcards':
          b.flashcards.values.map((f) => f.toMap()).toList(),
      'todos': b.todos.values.map((t) => t.toMap()).toList(),
      'academicSubjects':
          b.academicSubjects.values.map((a) => a.toMap()).toList(),
      'attendanceRecords': b.attendanceRecords.values
          .map((r) => r.toMap())
          .toList(),
      'classSchedules':
          b.classSchedules.values.map((s) => s.toMap()).toList(),
      'timestamps':
          b.timestamps.values.map((t) => t.toMap()).toList(),
      'mindMaps':
          b.mindMaps.values.map((m) => m.toMap()).toList(),
      'settings': {
        if (b.settings.containsKey('student_name'))
          'student_name': b.settings.get('student_name'),
      },
    };
  }

  /// Encode the export map as a JSON string.
  static String exportToJsonString() {
    return const JsonEncoder.withIndent('  ').convert(buildExportMap());
  }

  /// Copy the JSON string to the system clipboard.
  static Future<void> exportToClipboard() async {
    final json = exportToJsonString();
    await Clipboard.setData(ClipboardData(text: json));
  }

  /// File name for a backup made at [now]. Unchanged from earlier versions.
  static String backupFileName(DateTime now) =>
      'studyflow_backup_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';

  /// Test seam for the platform file saver.
  @visibleForTesting
  static Future<BackupSaveStatus> Function(String fileName, String content) fileSaver = saveBackupFile;

  /// Saves the signed-in user's backup as a file: a browser download on web,
  /// the share sheet on Android. Never throws; the result says what really
  /// happened, so a missing backup is never reported as success.
  static Future<ExportResult> exportToFile() async {
    final String json;
    try {
      json = exportToJsonString();
    } on NoActiveUserError {
      return const ExportResult(ExportOutcome.notSignedIn, 'Sign in to export your data. No backup was created.');
    } catch (e) {
      debugPrint('Backup export failed while reading data: $e');
      return const ExportResult(ExportOutcome.failed, 'Export failed: your data could not be read. No backup was created.');
    }

    final fileName = backupFileName(DateTime.now());
    try {
      final status = await fileSaver(fileName, json);
      return switch (status) {
        BackupSaveStatus.downloaded => ExportResult(
          ExportOutcome.downloaded,
          'Backup downloaded as $fileName. Check your browser\'s downloads.',
          fileName: fileName,
        ),
        BackupSaveStatus.shared => ExportResult(
          ExportOutcome.shared,
          'Backup $fileName is ready. Choose where to save it in the share sheet.',
          fileName: fileName,
        ),
        BackupSaveStatus.cancelled => const ExportResult(
          ExportOutcome.cancelled,
          'Export cancelled. No backup was saved.',
        ),
      };
    } catch (e) {
      debugPrint('Backup export failed while saving the file: $e');
      return const ExportResult(ExportOutcome.failed, 'Export failed: the backup file could not be saved.');
    }
  }
}

enum ExportOutcome { downloaded, shared, cancelled, notSignedIn, failed }

/// Result of [DataExportService.exportToFile], with a message for the user.
class ExportResult {
  final ExportOutcome outcome;
  final String message;
  final String? fileName;

  const ExportResult(this.outcome, this.message, {this.fileName});

  /// A backup file was produced (downloaded, or handed to the share sheet).
  bool get isSuccess => outcome == ExportOutcome.downloaded || outcome == ExportOutcome.shared;

  /// Something went wrong (as opposed to the user cancelling).
  bool get isError => outcome == ExportOutcome.failed || outcome == ExportOutcome.notSignedIn;
}
