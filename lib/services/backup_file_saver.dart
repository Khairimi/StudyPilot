// Saves a backup file for the current platform:
//   * web      -> the browser downloads the file (backup_file_saver_web.dart)
//   * Android and other native platforms -> the system share sheet
//     (backup_file_saver_io.dart)
export 'backup_save_status.dart';
export 'backup_file_saver_io.dart' if (dart.library.js_interop) 'backup_file_saver_web.dart';
