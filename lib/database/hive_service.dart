import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:study_app/models/subject.dart';
import 'package:study_app/models/chapter.dart';
import 'package:study_app/models/note.dart';
import 'package:study_app/models/block.dart';
import 'package:study_app/models/study_session.dart';
import 'package:study_app/models/todo.dart';
import 'package:study_app/models/todo_subtask.dart';
import 'package:study_app/models/flashcard.dart';
import 'package:study_app/models/mind_map.dart';
import 'package:study_app/models/academic/subject_attendance.dart';
import 'package:study_app/models/academic/attendance_record.dart';
import 'package:study_app/models/academic/class_schedule.dart';
import 'package:study_app/models/timestamp.dart';

/// Thrown when user data is accessed while no signed-in user's storage is
/// active. There is deliberately no fallback to the legacy shared boxes.
class NoActiveUserError extends StateError {
  NoActiveUserError() : super('No signed-in user storage is active.');
}

/// All Hive boxes belonging to one Firebase user, opened as
/// `<boxName>_<uid>`. Capture this object at the start of any async
/// operation so later writes cannot land in another user's storage.
class UserBoxes {
  final String uid;
  final int sessionId;
  final Box<Subject> subjects;
  final Box<Chapter> chapters;
  final Box<Note> notes;
  final Box<StudySession> studyTime;
  final Box<Todo> todos;
  final Box<Flashcard> flashcards;
  final Box<MindMap> mindMaps;
  final Box<SubjectAttendance> academicSubjects;
  final Box<AttendanceRecord> attendanceRecords;
  final Box<ClassSchedule> classSchedules;
  final Box<Timestamp> timestamps;

  /// User-specific settings (e.g. display name, sync bookkeeping).
  final Box settings;

  UserBoxes._({
    required this.uid,
    required this.sessionId,
    required this.subjects,
    required this.chapters,
    required this.notes,
    required this.studyTime,
    required this.todos,
    required this.flashcards,
    required this.mindMaps,
    required this.academicSubjects,
    required this.attendanceRecords,
    required this.classSchedules,
    required this.timestamps,
    required this.settings,
  });

  List<Box> get all => [
        subjects, chapters, notes, studyTime, todos, flashcards, mindMaps,
        academicSubjects, attendanceRecords, classSchedules, timestamps, settings,
      ];
}

class HiveService {
  // Base box names. The original names are also the legacy *shared* boxes
  // from CSC660, which are kept on disk untouched and are never opened.
  static const String subjectsBoxName = 'subjectsBox';
  static const String chaptersBoxName = 'chaptersBox';
  static const String notesBoxName = 'notesBox';
  static const String studyTimeBoxName = 'studyTimeBox';
  static const String settingsBoxName = 'settingsBox'; // device-wide
  static const String todosBoxName = 'todosBox';
  static const String flashcardsBoxName = 'flashcardsBox';
  static const String mindMapsBoxName = 'mindMapsBox';
  static const String academicSubjectsBoxName = 'academicSubjectsBox';
  static const String attendanceRecordsBoxName = 'attendanceRecordsBox';
  static const String classSchedulesBoxName = 'classSchedulesBox';
  static const String timestampsBoxName = 'timestampsBox';
  static const String userSettingsBoxName = 'userSettingsBox';

  /// Every user-data box base name (legacy shared boxes use these names).
  static const List<String> legacySharedBoxNames = [
    subjectsBoxName, chaptersBoxName, notesBoxName, studyTimeBoxName,
    todosBoxName, flashcardsBoxName, mindMapsBoxName, academicSubjectsBoxName,
    attendanceRecordsBoxName, classSchedulesBoxName, timestampsBoxName,
  ];

  // Kekal nama box lama untuk one-time cleanup — lihat _cleanupLegacyDrawingsBox()
  static const String _legacyDrawingsBoxName = 'drawingsBox';

  static Future<void> init() async {
    await Hive.initFlutter();
    registerAdapters();
    // Only the device-wide settings box is opened at startup. User data is
    // opened per signed-in user by activateUser().
    await Hive.openBox(settingsBoxName);
    await _cleanupLegacyDrawingsBox();
  }

  static void registerAdapters() {
    void reg<T>(TypeAdapter<T> a) {
      if (!Hive.isAdapterRegistered(a.typeId)) Hive.registerAdapter<T>(a);
    }

    reg(SubjectAdapter());
    reg(ChapterAdapter());
    reg(NoteAdapter());
    reg(BlockTypeAdapter());
    reg(BlockAdapter());
    reg(StudySessionAdapter());
    reg(TodoAdapter());
    reg(TodoSubTaskAdapter());
    reg(FlashcardAdapter());
    reg(MindMapNodeAdapter());
    reg(MindMapAdapter());
    reg(SubjectAttendanceAdapter());
    reg(AttendanceRecordAdapter());
    reg(ClassScheduleAdapter());
    reg(TimestampAdapter());
    // DrawingAdapter dah dibuang — Freehand Canvas feature discontinued
  }

  // One-time cleanup: buang fail box lama 'drawingsBox' dari disk kalau wujud.
  static Future<void> _cleanupLegacyDrawingsBox() async {
    try {
      final exists = await Hive.boxExists(_legacyDrawingsBoxName);
      if (exists) {
        await Hive.deleteBoxFromDisk(_legacyDrawingsBoxName);
      }
    } catch (_) {
      // Selamat diabaikan — cleanup je, bukan critical path
    }
  }

  // ---------------------------------------------------------------------
  // Per-user session
  // ---------------------------------------------------------------------

  static UserBoxes? _active;
  static int _sessionId = 0;
  static Future<void> _queue = Future.value();

  /// Increments on every activate/deactivate.
  static int get sessionId => _sessionId;

  /// True if [id] is still the current, active session.
  static bool isCurrentSession(int id) => _active != null && id == _sessionId;

  static UserBoxes? get activeOrNull => _active;
  static String? get activeUid => _active?.uid;

  static UserBoxes requireActive() {
    final a = _active;
    if (a == null) throw NoActiveUserError();
    return a;
  }

  static String userBoxName(String base, String uid) => '${base}_$uid'.toLowerCase();

  // Runs storage operations one at a time so a box is never opened while
  // it is still being closed by a previous switch.
  static Future<T> _serial<T>(Future<T> Function() op) {
    final result = _queue.then((_) => op());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// Immediately stops serving the current user's data, then closes their
  /// boxes (non-destructive: data stays on disk).
  static Future<void> deactivateUser() {
    _sessionId++;
    final old = _active;
    _active = null;
    return _serial(() => _closeAll(old));
  }

  /// Opens [uid]'s boxes and makes them active. Returns false if a newer
  /// activate/deactivate superseded this call. Throws if opening fails, in
  /// which case no user storage is active (fail closed).
  static Future<bool> activateUser(String uid) {
    _sessionId++;
    final id = _sessionId;
    final old = _active;
    _active = null;
    return _serial(() async {
      await _closeAll(old);
      if (id != _sessionId) return false;
      final boxes = await _openUserBoxes(uid, id);
      if (id != _sessionId) {
        await _closeAll(boxes);
        return false;
      }
      _active = boxes;
      return true;
    });
  }

  static Future<void> _closeAll(UserBoxes? boxes) async {
    if (boxes == null) return;
    for (final b in boxes.all) {
      try {
        if (b.isOpen) await b.close();
      } catch (e) {
        debugPrint('Hive close failed for ${b.name}: $e');
      }
    }
  }

  static Future<UserBoxes> _openUserBoxes(String uid, int id) async {
    Future<Box<T>> open<T>(String base) => Hive.openBox<T>(userBoxName(base, uid));

    final boxes = UserBoxes._(
      uid: uid,
      sessionId: id,
      subjects: await open<Subject>(subjectsBoxName),
      chapters: await open<Chapter>(chaptersBoxName),
      notes: await open<Note>(notesBoxName),
      studyTime: await open<StudySession>(studyTimeBoxName),
      todos: await open<Todo>(todosBoxName),
      flashcards: await open<Flashcard>(flashcardsBoxName),
      mindMaps: await open<MindMap>(mindMapsBoxName),
      academicSubjects: await open<SubjectAttendance>(academicSubjectsBoxName),
      attendanceRecords: await open<AttendanceRecord>(attendanceRecordsBoxName),
      classSchedules: await open<ClassSchedule>(classSchedulesBoxName),
      timestamps: await open<Timestamp>(timestampsBoxName),
      settings: await open<dynamic>(userSettingsBoxName),
    );
    await _moveUidTaggedDeviceKeys(uid, boxes.settings);
    return boxes;
  }

  /// Subject-sync bookkeeping was briefly stored in the device box as
  /// `pendingSubject<Kind>_<uid>`. Those keys carry the owner's uid, so they
  /// are moved into that user's own settings box. Nothing else is touched.
  static Future<void> _moveUidTaggedDeviceKeys(String uid, Box userSettings) async {
    final device = settingsBox;
    for (final kind in const ['Deletes', 'Upserts']) {
      final oldKey = 'pendingSubject${kind}_$uid';
      final newKey = 'pendingSubject$kind';
      if (!device.containsKey(oldKey)) continue;
      final value = device.get(oldKey);
      if (!userSettings.containsKey(newKey) && value is List) {
        await userSettings.put(newKey, value.cast<String>().toList());
      }
      await device.delete(oldKey);
    }
  }

  @visibleForTesting
  static Future<void> resetForTest() async {
    await deactivateUser();
    _queue = Future.value();
  }

  // ---------------------------------------------------------------------
  // Accessors. User-data getters throw NoActiveUserError when signed out.
  // ---------------------------------------------------------------------

  /// Device-wide settings (e.g. dark mode). Not for user data.
  static Box get settingsBox => Hive.box(settingsBoxName);

  static Box get userSettingsBox => requireActive().settings;
  static Box<Subject> get subjectsBox => requireActive().subjects;
  static Box<Chapter> get chaptersBox => requireActive().chapters;
  static Box<Note> get notesBox => requireActive().notes;
  static Box<StudySession> get studyTimeBox => requireActive().studyTime;
  static Box<Todo> get todosBox => requireActive().todos;
  static Box<Flashcard> get flashcardsBox => requireActive().flashcards;
  static Box<MindMap> get mindMapsBox => requireActive().mindMaps;
  static Box<SubjectAttendance> get academicSubjectsBox => requireActive().academicSubjects;
  static Box<AttendanceRecord> get attendanceRecordsBox => requireActive().attendanceRecords;
  static Box<ClassSchedule> get classSchedulesBox => requireActive().classSchedules;
  static Box<Timestamp> get timestampsBox => requireActive().timestamps;
}
