import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_app/database/hive_service.dart';
import 'package:study_app/database/user_session.dart';
import 'package:study_app/models/chapter.dart';
import 'package:study_app/models/todo.dart';
import 'package:study_app/providers/chapter_provider.dart';
import 'package:study_app/providers/study_provider.dart';
import 'package:study_app/providers/todo_provider.dart';

const uidA = 'UserAaaaAAAA111';
const uidB = 'UserBbbbBBBB222';

Chapter _chapter(String id) => Chapter(
      id: id,
      subjectId: 's1',
      title: 'Chapter $id',
      description: '',
      createdDate: DateTime(2026, 1, 1),
    );

/// Records the order of session callbacks.
class _Recorder implements UserScopedState {
  final List<String> events = [];
  @override
  void clearUserState() => events.add('clear');
  @override
  Future<void> loadUserState(String uid) async => events.add('load:$uid');
}

Future<void> _settle(UserSession s) async {
  for (var i = 0; i < 400; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    if (s.status != UserSessionStatus.loading) return;
  }
  fail('session did not settle');
}

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('hive_isolation_');
    Hive.init(dir.path);
    HiveService.registerAdapters();
    await Hive.openBox(HiveService.settingsBoxName);
  });

  tearDown(() async {
    await HiveService.resetForTest();
    await Hive.close();
    await dir.delete(recursive: true);
  });

  group('HiveService per-user storage', () {
    test('data written as A is invisible to B and back again for A', () async {
      expect(await HiveService.activateUser(uidA), isTrue);
      await HiveService.chaptersBox.put('c1', _chapter('c1'));

      expect(await HiveService.activateUser(uidB), isTrue);
      expect(HiveService.chaptersBox.isEmpty, isTrue);
      expect(HiveService.activeUid, uidB);

      await HiveService.activateUser(uidA);
      expect(HiveService.chaptersBox.get('c1')?.title, 'Chapter c1');
    });

    test('signed out: no fallback, user getters throw', () async {
      await HiveService.activateUser(uidA);
      await HiveService.deactivateUser();
      expect(HiveService.activeOrNull, isNull);
      expect(() => HiveService.chaptersBox, throwsA(isA<NoActiveUserError>()));
      expect(() => HiveService.userSettingsBox, throwsA(isA<NoActiveUserError>()));
      // Device-wide settings stay available.
      expect(HiveService.settingsBox.isOpen, isTrue);
    });

    test('stale captured write after a switch cannot reach the new user', () async {
      await HiveService.activateUser(uidA);
      final staleA = HiveService.requireActive();

      await HiveService.activateUser(uidB);
      await expectLater(staleA.chapters.put('late', _chapter('late')), throwsA(anything));
      expect(HiveService.chaptersBox.containsKey('late'), isFalse);
      expect(HiveService.isCurrentSession(staleA.sessionId), isFalse);
    });

    test('legacy shared boxes are never opened, changed or claimed', () async {
      final legacy = await Hive.openBox<Chapter>(HiveService.chaptersBoxName);
      await legacy.put('old', _chapter('old'));
      await legacy.close();

      await HiveService.activateUser(uidA);
      expect(Hive.isBoxOpen(HiveService.chaptersBoxName), isFalse);
      expect(HiveService.chaptersBox.containsKey('old'), isFalse);
      await HiveService.chaptersBox.put('new', _chapter('new'));
      await HiveService.deactivateUser();

      final reopened = await Hive.openBox<Chapter>(HiveService.chaptersBoxName);
      expect(reopened.keys.toList(), ['old']);
    });

    test('uid-tagged sync keys move only to their owner; device keys stay', () async {
      final device = HiveService.settingsBox;
      await device.put('isDarkMode', true);
      await device.put('student_name', 'Legacy Name');
      await device.put('pendingSubjectUpserts_$uidA', ['x1']);

      await HiveService.activateUser(uidB);
      expect(HiveService.userSettingsBox.get('pendingSubjectUpserts'), isNull);
      expect(HiveService.userSettingsBox.get('student_name'), isNull);

      await HiveService.activateUser(uidA);
      expect(HiveService.userSettingsBox.get('pendingSubjectUpserts'), ['x1']);
      expect(device.containsKey('pendingSubjectUpserts_$uidA'), isFalse);
      expect(device.get('isDarkMode'), isTrue);
      expect(device.get('student_name'), 'Legacy Name'); // unowned: untouched
    });
  });

  group('UserSession', () {
    test('clears providers before loading, and on sign-out', () async {
      final rec = _Recorder();
      final ctrl = StreamController<String?>();
      final session = UserSession(uidStream: ctrl.stream, participants: [rec])..start();

      ctrl.add(uidA);
      await _settle(session);
      expect(session.status, UserSessionStatus.ready);

      ctrl.add(uidB);
      await _settle(session);
      ctrl.add(null);
      await _settle(session);

      expect(rec.events, ['clear', 'load:$uidA', 'clear', 'load:$uidB', 'clear']);
      expect(session.status, UserSessionStatus.signedOut);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(HiveService.activeOrNull, isNull);
      await ctrl.close();
      session.dispose();
    });

    test('rapid A→B switch: only B is loaded and active', () async {
      final rec = _Recorder();
      final ctrl = StreamController<String?>();
      final session = UserSession(uidStream: ctrl.stream, participants: [rec])..start();

      ctrl
        ..add(uidA)
        ..add(uidB);
      await _settle(session);

      expect(session.status, UserSessionStatus.ready);
      expect(HiveService.activeUid, uidB);
      expect(rec.events.where((e) => e.startsWith('load')), ['load:$uidB']);
      await ctrl.close();
      session.dispose();
    });

    test('storage failure fails closed with an error state', () async {
      final rec = _Recorder();
      final ctrl = StreamController<String?>();
      final session = UserSession(
        uidStream: ctrl.stream,
        participants: [rec],
        activate: (_) async => throw StateError('disk unavailable'),
      )..start();

      ctrl.add(uidA);
      await _settle(session);

      expect(session.status, UserSessionStatus.error);
      expect(HiveService.activeOrNull, isNull);
      expect(rec.events, isNot(contains('load:$uidA')));
      await ctrl.close();
      session.dispose();
    });
  });

  group('providers across accounts', () {
    test('ChapterProvider and TodoProvider show only the active user\'s data', () async {
      final chapters = ChapterProvider();
      final todos = TodoProvider();
      final ctrl = StreamController<String?>();
      final session =
          UserSession(uidStream: ctrl.stream, participants: [chapters, todos])..start();

      ctrl.add(uidA);
      await _settle(session);
      chapters.addChapter('s1', 'A chapter', '');
      await todos.addTodo('A todo', 'general', null);
      expect(chapters.chapters.length, 1);
      expect(todos.todos.length, 1);

      // In-memory state is cleared synchronously, before B is loaded.
      chapters.clearUserState();
      expect(chapters.chapters, isEmpty);

      ctrl.add(uidB);
      await _settle(session);
      expect(chapters.chapters, isEmpty);
      expect(todos.todos, isEmpty);

      ctrl.add(null);
      await _settle(session);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(todos.todos, isEmpty);
      await todos.addTodo('while signed out', 'general', null); // no-op
      chapters.addChapter('s1', 'while signed out', ''); // no-op

      ctrl.add(uidA);
      await _settle(session);
      expect(chapters.chapters.map((c) => c.title), ['A chapter']);
      expect(todos.todos.map((t) => t.task), ['A todo']);
      await ctrl.close();
      session.dispose();
    });

    test('running study timer is stopped on account switch', () async {
      final study = StudyProvider();
      final ctrl = StreamController<String?>();
      final session = UserSession(uidStream: ctrl.stream, participants: [study])..start();

      ctrl.add(uidA);
      await _settle(session);
      study.startActiveTimer('s1');
      expect(study.isTimerRunning, isTrue);

      ctrl.add(uidB);
      await _settle(session);
      expect(study.isTimerRunning, isFalse);
      expect(study.sessions, isEmpty);
      expect(HiveService.studyTimeBox.isEmpty, isTrue);
      await ctrl.close();
      session.dispose();
    });
  });

  test('Todo box type is per user (sanity)', () async {
    await HiveService.activateUser(uidA);
    expect(HiveService.todosBox, isA<Box<Todo>>());
    expect(HiveService.todosBox.name, HiveService.userBoxName(HiveService.todosBoxName, uidA));
  });
}
