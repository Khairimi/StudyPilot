import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/models/subject.dart';
import 'package:study_app/services/backup_file_saver.dart';
import 'package:study_app/services/backup_file_saver_io.dart' as io_saver;
import 'package:study_app/services/data_export_service.dart';

const uidA = 'UserAaaaAAAA111';
const uidB = 'UserBbbbBBBB222';

Subject subject(String id, String name) =>
    Subject(id: id, name: name, colorValue: 4283215696, createdDate: DateTime(2026, 11, 8), weightage: 20);

/// The keys of a backup file. Changing them would break importing old backups.
const expectedKeys = {
  'version',
  'exportedAt',
  'subjects',
  'chapters',
  'notes',
  'studySessions',
  'flashcards',
  'todos',
  'academicSubjects',
  'attendanceRecords',
  'classSchedules',
  'timestamps',
  'mindMaps',
  'settings',
};

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_export_');
    Hive.init(dir.path);
    HiveService.registerAdapters();
    await Hive.openBox(HiveService.settingsBoxName);
  });

  tearDown(() async {
    DataExportService.fileSaver = saveBackupFile;
    await HiveService.resetForTest();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('DataExportService.exportToFile', () {
    test('saves the signed-in user backup with the unchanged format and file name', () async {
      await HiveService.activateUser(uidA);
      await HiveService.requireActive().subjects.put('s1', subject('s1', 'Algorithms'));

      String? savedName, savedContent;
      DataExportService.fileSaver = (name, content) async {
        savedName = name;
        savedContent = content;
        return BackupSaveStatus.downloaded;
      };

      final result = await DataExportService.exportToFile();

      expect(result.outcome, ExportOutcome.downloaded);
      expect(result.isSuccess, isTrue);
      expect(result.message, contains(savedName!));
      expect(savedName, matches(RegExp(r'^studyflow_backup_\d{8}\.json$')));
      final data = jsonDecode(savedContent!) as Map<String, dynamic>;
      expect(data.keys.toSet(), expectedKeys);
      expect(data['version'], 1);
      expect((data['subjects'] as List).single['name'], 'Algorithms');
      // Same data as the clipboard export: one format for both.
      expect(jsonDecode(DataExportService.exportToJsonString())['subjects'], data['subjects']);
    });

    test('contains only the signed-in user data, never another account', () async {
      await HiveService.activateUser(uidA);
      await HiveService.requireActive().subjects.put('a1', subject('a1', 'Only A'));
      await HiveService.activateUser(uidB);
      await HiveService.requireActive().subjects.put('b1', subject('b1', 'Only B'));

      late String content;
      DataExportService.fileSaver = (name, text) async {
        content = text;
        return BackupSaveStatus.downloaded;
      };
      await DataExportService.exportToFile();
      expect(content, contains('Only B'));
      expect(content, isNot(contains('Only A')));
    });

    test('exporting does not change the stored data', () async {
      await HiveService.activateUser(uidA);
      final box = HiveService.requireActive().subjects;
      await box.put('s1', subject('s1', 'Algorithms'));
      DataExportService.fileSaver = (name, content) async => BackupSaveStatus.downloaded;
      await DataExportService.exportToFile();
      expect(box.keys, ['s1']);
      expect(box.get('s1')!.name, 'Algorithms');
    });

    test('nobody signed in: no file is saved and the message says so', () async {
      var saved = false;
      DataExportService.fileSaver = (name, content) async {
        saved = true;
        return BackupSaveStatus.downloaded;
      };
      final result = await DataExportService.exportToFile();
      expect(saved, isFalse);
      expect(result.outcome, ExportOutcome.notSignedIn);
      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
      expect(result.message, contains('No backup was created'));
    });

    test('a failing file save is reported as a failure, not a success', () async {
      await HiveService.activateUser(uidA);
      DataExportService.fileSaver = (name, content) async => throw StateError('disk full');
      final result = await DataExportService.exportToFile();
      expect(result.outcome, ExportOutcome.failed);
      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
      expect(result.message, isNot(contains('disk full')));
    });

    test('closing the share sheet is cancelled: not a success and not an error', () async {
      await HiveService.activateUser(uidA);
      DataExportService.fileSaver = (name, content) async => BackupSaveStatus.cancelled;
      final result = await DataExportService.exportToFile();
      expect(result.outcome, ExportOutcome.cancelled);
      expect(result.isSuccess, isFalse);
      expect(result.isError, isFalse);
      expect(result.message, contains('No backup was saved'));
    });

    test('backupFileName keeps the existing format', () {
      expect(DataExportService.backupFileName(DateTime(2026, 3, 9)), 'studyflow_backup_20260309.json');
    });
  });

  // Android / native path: a temporary file plus the share sheet.
  group('native saver (share sheet)', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('backup_tmp_');
      io_saver.backupTempDirectory = () async => temp;
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('writes the file, shares exactly that file and reports shared', () async {
      XFile? shared;
      io_saver.shareBackupFile = (file) async {
        shared = file;
        return const ShareResult('x', ShareResultStatus.success);
      };
      final status = await io_saver.saveBackupFile('studyflow_backup_20260101.json', '{"version": 1}');
      expect(status, BackupSaveStatus.shared);
      expect(shared!.mimeType, 'application/json');
      expect(shared!.path, endsWith('studyflow_backup_20260101.json'));
      expect(await File('${temp.path}/studyflow_backup_20260101.json').readAsString(), '{"version": 1}');
    });

    test('a dismissed share sheet is reported as cancelled', () async {
      io_saver.shareBackupFile = (file) async => const ShareResult('', ShareResultStatus.dismissed);
      expect(await io_saver.saveBackupFile('b.json', '{}'), BackupSaveStatus.cancelled);
    });

    test('when the platform cannot tell the outcome, the file is reported as shared', () async {
      io_saver.shareBackupFile = (file) async => const ShareResult('', ShareResultStatus.unavailable);
      expect(await io_saver.saveBackupFile('b.json', '{}'), BackupSaveStatus.shared);
    });

    test('an unwritable location throws before anything is shared', () async {
      var shareCalled = false;
      io_saver.shareBackupFile = (file) async {
        shareCalled = true;
        return const ShareResult('', ShareResultStatus.success);
      };
      io_saver.backupTempDirectory = () async => Directory('${temp.path}/missing/dir');
      await expectLater(io_saver.saveBackupFile('b.json', '{}'), throwsA(isA<FileSystemException>()));
      expect(shareCalled, isFalse);
    });
  });
}
