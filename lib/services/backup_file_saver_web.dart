import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:study_app/services/backup_save_status.dart';
import 'package:web/web.dart' as web;

/// Downloads [content] as a file through the browser. path_provider and the
/// share sheet are not available on web, so this uses a Blob and a temporary
/// download link. The file goes to the browser's normal downloads location.
Future<BackupSaveStatus> saveBackupFile(String fileName, String content) async {
  final bytes = utf8.encode(content);
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'application/json'));
  final url = web.URL.createObjectURL(blob);
  try {
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName
      ..style.display = 'none';
    web.document.body!.append(link);
    link.click();
    link.remove();
  } catch (_) {
    web.URL.revokeObjectURL(url);
    rethrow;
  }
  // Keep the object URL alive long enough for the browser to start the download.
  Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  return BackupSaveStatus.downloaded;
}
