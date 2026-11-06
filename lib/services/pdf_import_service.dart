// lib/services/pdf_import_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/classroom/v1.dart' as classroom;
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';
import 'google_auth_client.dart';

enum ClassroomResourceType { pdf, link }

class ClassroomResource {
  final String title;
  final ClassroomResourceType type;
  final String? driveFileId; // digunakan bila type == pdf
  final String? url; // digunakan bila type == link

  ClassroomResource({
    required this.title,
    required this.type,
    this.driveFileId,
    this.url,
  });
}

class PdfImportService {
  /// Cari SEMUA resource (PDF, link luar, folder Drive, Google Docs/Slides
  /// native, YouTube, Form) yang attached dalam satu courseWork/material.
  static Future<List<ClassroomResource>> listResources({
    required String courseId,
    required String courseWorkId,
    required String sourceType, // 'assignment' | 'material'
  }) async {
    final googleUser = AuthService.googleUser;
    if (googleUser == null) {
      throw Exception('Sila sign in dengan Google dahulu');
    }

    final authHeaders = await googleUser.authHeaders;
    final client = classroom.ClassroomApi(GoogleAuthClient(authHeaders));

    List<classroom.Material>? materials;

    if (sourceType == 'material') {
      final item = await client.courses.courseWorkMaterials.get(
        courseId,
        courseWorkId,
      );
      materials = item.materials;
    } else {
      final item = await client.courses.courseWork.get(courseId, courseWorkId);
      materials = item.materials;
    }

    if (materials == null) return [];

    final resources = <ClassroomResource>[];

    for (final m in materials) {
      // ── Drive file (boleh jadi PDF binary, atau folder/Google-native doc) ──
      final driveFile = m.driveFile?.driveFile;
      if (driveFile != null) {
        final title = driveFile.title ?? 'Untitled file';
        if (driveFile.id != null && title.toLowerCase().endsWith('.pdf')) {
          resources.add(
            ClassroomResource(
              title: title,
              type: ClassroomResourceType.pdf,
              driveFileId: driveFile.id,
            ),
          );
        } else if (driveFile.alternateLink != null) {
          // Folder, Google Docs/Slides/Sheets native, atau fail bukan-PDF
          // — takde cara reliable extract text/download tanpa export API
          // berasingan, so simpan sebagai link supaya student boleh buka.
          resources.add(
            ClassroomResource(
              title: title,
              type: ClassroomResourceType.link,
              url: driveFile.alternateLink,
            ),
          );
        }
        continue;
      }

      // ── Link luar (contoh: Mozilla, Tutorialspoint) ──
      final link = m.link;
      if (link != null) {
        resources.add(
          ClassroomResource(
            title: link.title ?? (link.url ?? 'Link'),
            type: ClassroomResourceType.link,
            url: link.url,
          ),
        );
        continue;
      }

      // ── Google Form ──
      final form = m.form;
      if (form != null) {
        resources.add(
          ClassroomResource(
            title: form.title ?? 'Google Form',
            type: ClassroomResourceType.link,
            url: form.formUrl,
          ),
        );
        continue;
      }

      // ── YouTube video ──
      // NOTA: nama field ni bergantung versi package googleapis kau.
      // Kalau compile error kat baris ni, IDE autocomplete akan cadangkan
      // nama sebenar (contoh mungkin 'youTubeVideo' bukan 'youtubeVideo').
      final youtube = m.youtubeVideo;
      if (youtube != null) {
        resources.add(
          ClassroomResource(
            title: youtube.title ?? 'YouTube Video',
            type: ClassroomResourceType.link,
            url: youtube.alternateLink,
          ),
        );
        continue;
      }
    }

    return resources;
  }

  /// Download PDF bytes dari Google Drive guna file ID.
  static Future<List<int>> downloadPdfBytes(String fileId) async {
    final googleUser = AuthService.googleUser;
    if (googleUser == null) {
      throw Exception('Sila sign in dengan Google dahulu');
    }

    final authHeaders = await googleUser.authHeaders;
    final client = drive.DriveApi(GoogleAuthClient(authHeaders));

    final media = await client.files.get(
      fileId,
      downloadOptions: drive.DownloadOptions.fullMedia,
    ) as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  /// Simpan PDF bytes ke local storage device, return path fail.
  static Future<String> saveLocalCopy(List<int> bytes, String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final pdfDir = Directory('${appDir.path}/imported_pdfs');
    if (!await pdfDir.exists()) {
      await pdfDir.create(recursive: true);
    }

    final safeFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final file = File('${pdfDir.path}/$safeFileName');
    await file.writeAsBytes(bytes);

    return file.path;
  }

  static void log(String message) => debugPrint('[PdfImportService] $message');
}