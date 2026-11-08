import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:study_app/services/backup_save_status.dart';

/// Test seams: where the temporary file goes and how it is shared.
@visibleForTesting
Future<Directory> Function() backupTempDirectory = getTemporaryDirectory;

@visibleForTesting
Future<ShareResult> Function(XFile file) shareBackupFile = (file) =>
    Share.shareXFiles([file], subject: 'StudyPilot Backup');

/// Writes [content] to a temporary file and opens the system share sheet.
/// Throws if the file could not be written, so callers never report success
/// for a backup that doesn't exist.
Future<BackupSaveStatus> saveBackupFile(String fileName, String content) async {
  final dir = await backupTempDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(content);
  if (!await file.exists() || await file.length() == 0) {
    throw FileSystemException('Backup file was not written', file.path);
  }

  final result = await shareBackupFile(XFile(file.path, mimeType: 'application/json'));
  return result.status == ShareResultStatus.dismissed ? BackupSaveStatus.cancelled : BackupSaveStatus.shared;
}
