// lib/services/classroom_service.dart
import 'package:googleapis/classroom/v1.dart';
import 'auth_service.dart';
import 'google_auth_client.dart';
import 'package:flutter/foundation.dart';

enum ClassroomItemType { assignment, material, announcement }

class ClassroomAssignment {
  final String courseTitle;
  final String title;
  final DateTime? dueDate;
  final String? description;
  final String courseId;
  final String courseWorkId;
  final ClassroomItemType type;
  final DateTime? postedDate;
  final int pdfAttachmentCount;

  ClassroomAssignment({
    required this.courseTitle,
    required this.title,
    this.dueDate,
    this.description,
    required this.courseId,
    required this.courseWorkId,
    this.type = ClassroomItemType.assignment,
    this.postedDate,
    this.pdfAttachmentCount = 0,
  });
}

class ClassroomService {
  static bool get isAvailable => AuthService.googleUser != null;

  static Future<List<ClassroomAssignment>> fetchAllAssignments({
    DateTime? since,
  }) async {
    final googleUser = AuthService.googleUser;
    if (googleUser == null) {
      throw Exception('Sila sign in dengan Google untuk akses Classroom');
    }

    final authHeaders = await googleUser.authHeaders;
    final client = ClassroomApi(GoogleAuthClient(authHeaders));

    final List<ClassroomAssignment> allAssignments = [];

    // ---------- Fetch SEMUA course, handle pagination ----------
    final courses = await _fetchAllCourses(client);
    debugPrint('DEBUG: Total courses fetched = ${courses.length}');

    for (final course in courses) {
      if (course.id == null) continue;
      final courseId = course.id!;
      final courseTitle = course.name ?? 'Untitled Course';

      // ---------- 1. CourseWork (assignments) — handle pagination ----------
      final courseWorkList = await _fetchAllCourseWork(client, courseId);
      debugPrint('DEBUG: $courseTitle -> ${courseWorkList.length} courseWork items');

      for (final work in courseWorkList) {
        final dueDate = _parseDueDate(work.dueDate, work.dueTime);
        final postedDate = _parseTimestamp(work.creationTime);

        if (since != null && postedDate != null && postedDate.isBefore(since)) {
          continue;
        }

        final pdfCount = _countPdfAttachments(work.materials);

        allAssignments.add(
          ClassroomAssignment(
            courseTitle: courseTitle,
            title: work.title ?? 'Untitled Assignment',
            dueDate: dueDate,
            description: work.description,
            courseId: courseId,
            courseWorkId: work.id ?? '',
            type: ClassroomItemType.assignment,
            postedDate: postedDate,
            pdfAttachmentCount: pdfCount,
          ),
        );
      }

      // ---------- 2. CourseWork Materials — handle pagination ----------
      try {
        final materials = await _fetchAllCourseWorkMaterials(client, courseId);
        debugPrint('DEBUG: $courseTitle -> ${materials.length} material items');

        for (final material in materials) {
          final postedDate = _parseTimestamp(material.creationTime);

          if (since != null && postedDate != null && postedDate.isBefore(since)) {
            continue;
          }

          final pdfCount = _countPdfAttachments(material.materials);

          allAssignments.add(
            ClassroomAssignment(
              courseTitle: courseTitle,
              title: material.title ?? 'Untitled Material',
              dueDate: null,
              description: material.description,
              courseId: courseId,
              courseWorkId: material.id ?? '',
              type: ClassroomItemType.material,
              postedDate: postedDate,
              pdfAttachmentCount: pdfCount,
            ),
          );
        }
      } catch (e) {
        debugPrint('Materials fetch error for $courseTitle: $e');
      }

      // ---------- 3. Announcements — handle pagination ----------
      try {
        final announcements = await _fetchAllAnnouncements(client, courseId);

        for (final a in announcements) {
          final postedDate = _parseTimestamp(a.creationTime);

          if (since != null && postedDate != null && postedDate.isBefore(since)) {
            continue;
          }

          allAssignments.add(
            ClassroomAssignment(
              courseTitle: courseTitle,
              title: a.text ?? 'Announcement',
              dueDate: null,
              description: null,
              courseId: courseId,
              courseWorkId: a.id ?? '',
              type: ClassroomItemType.announcement,
              postedDate: postedDate,
              pdfAttachmentCount: 0,
            ),
          );
        }
      } catch (e) {
        debugPrint('Announcements fetch error for $courseTitle: $e');
      }
    }

    debugPrint('DEBUG: Total assignments fetched (all types) = ${allAssignments.length}');
    return allAssignments;
  }

  // ─── Pagination helpers ─────────────────────────────────────────────────

  static Future<List<Course>> _fetchAllCourses(ClassroomApi client) async {
    final List<Course> all = [];
    String? pageToken;

    do {
      final response = await client.courses.list(
        courseStates: ['ACTIVE'],
        pageToken: pageToken,
      );
      all.addAll(response.courses ?? []);
      pageToken = response.nextPageToken;
    } while (pageToken != null);

    return all;
  }

  static Future<List<CourseWork>> _fetchAllCourseWork(
    ClassroomApi client,
    String courseId,
  ) async {
    final List<CourseWork> all = [];
    String? pageToken;

    do {
      final response = await client.courses.courseWork.list(
        courseId,
        pageToken: pageToken,
      );
      all.addAll(response.courseWork ?? []);
      pageToken = response.nextPageToken;
    } while (pageToken != null);

    return all;
  }

  static Future<List<CourseWorkMaterial>> _fetchAllCourseWorkMaterials(
    ClassroomApi client,
    String courseId,
  ) async {
    final List<CourseWorkMaterial> all = [];
    String? pageToken;

    do {
      final response = await client.courses.courseWorkMaterials.list(
        courseId,
        pageToken: pageToken,
      );
      all.addAll(response.courseWorkMaterial ?? []);
      pageToken = response.nextPageToken;
    } while (pageToken != null);

    return all;
  }

  static Future<List<Announcement>> _fetchAllAnnouncements(
    ClassroomApi client,
    String courseId,
  ) async {
    final List<Announcement> all = [];
    String? pageToken;

    do {
      final response = await client.courses.announcements.list(
        courseId,
        pageToken: pageToken,
      );
      all.addAll(response.announcements ?? []);
      pageToken = response.nextPageToken;
    } while (pageToken != null);

    return all;
  }

  // ─── Helpers ────────────────────────────────────────────────────────────

  static int _countPdfAttachments(List<Material>? materials) {
    if (materials == null) return 0;
    int count = 0;
    for (final m in materials) {
      final fileName = m.driveFile?.driveFile?.title;
      if (fileName != null && fileName.toLowerCase().endsWith('.pdf')) {
        count++;
      }
    }
    return count;
  }

  static DateTime? _parseDueDate(Date? dueDate, TimeOfDay? dueTime) {
    if (dueDate == null) return null;
    return DateTime(
      dueDate.year ?? DateTime.now().year,
      dueDate.month ?? 1,
      dueDate.day ?? 1,
      dueTime?.hours ?? 23,
      dueTime?.minutes ?? 59,
    );
  }

  static DateTime? _parseTimestamp(String? isoString) {
    if (isoString == null) return null;
    return DateTime.tryParse(isoString);
  }

  static Future<bool> isSubmitted({
    required String courseId,
    required String courseWorkId,
  }) async {
    final googleUser = AuthService.googleUser;
    if (googleUser == null) return false;

    try {
      final authHeaders = await googleUser.authHeaders;
      final client = ClassroomApi(GoogleAuthClient(authHeaders));

      final submissions =
          await client.courses.courseWork.studentSubmissions.list(
        courseId,
        courseWorkId,
        userId: 'me',
      );

      final submission = submissions.studentSubmissions?.firstOrNull;
      if (submission == null) return false;

      final state = submission.state;
      return state == 'TURNED_IN' || state == 'RETURNED';
    } catch (e) {
      debugPrint('Submission check error: $e');
      return false;
    }
  }
}