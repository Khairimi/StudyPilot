import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:study_app/database/hive_service.dart';

/// Implemented by every provider that holds user-specific data.
abstract class UserScopedState {
  /// Drop all in-memory user data immediately (synchronous) and stop any
  /// running work. Called before storage switches to another account.
  void clearUserState();

  /// Load the newly active user's data from [HiveService.requireActive].
  Future<void> loadUserState(String uid);
}

enum UserSessionStatus { signedOut, loading, ready, error }

/// Keeps local storage and providers in step with the signed-in Firebase
/// user. On every account change it clears provider state first, then
/// switches the per-user Hive boxes, then loads the new user's data.
/// Results from superseded switches are ignored.
class UserSession extends ChangeNotifier {
  final Stream<String?> _uidStream;
  final List<UserScopedState> _participants;
  final Future<bool> Function(String uid) _activate;
  final Future<void> Function() _deactivate;

  StreamSubscription<String?>? _sub;
  int _generation = 0;
  bool _hasUid = false;
  String? _uid;
  UserSessionStatus _status = UserSessionStatus.signedOut;
  Object? _error;

  UserSession({
    required Stream<String?> uidStream,
    required List<UserScopedState> participants,
    Future<bool> Function(String uid)? activate,
    Future<void> Function()? deactivate,
  })  : _uidStream = uidStream,
        _participants = participants,
        _activate = activate ?? HiveService.activateUser,
        _deactivate = deactivate ?? HiveService.deactivateUser;

  UserSessionStatus get status => _status;
  String? get uid => _uid;
  Object? get error => _error;
  bool get isReady => _status == UserSessionStatus.ready;

  void start() {
    _sub ??= _uidStream.listen(_onUid);
  }

  /// Retry loading the current user after an initialisation error.
  Future<void> retry() => _switchTo(_uid);

  void _onUid(String? uid) {
    if (_hasUid && uid == _uid && _status != UserSessionStatus.error) return;
    _hasUid = true;
    _switchTo(uid);
  }

  Future<void> _switchTo(String? uid) async {
    final gen = ++_generation;
    _uid = uid;
    _error = null;

    // 1. Clear every provider before anything else can render.
    for (final p in _participants) {
      try {
        p.clearUserState();
      } catch (e) {
        debugPrint('UserSession: clearUserState failed: $e');
      }
    }

    if (uid == null) {
      _status = UserSessionStatus.signedOut;
      notifyListeners();
      await _deactivate();
      return;
    }

    _status = UserSessionStatus.loading;
    notifyListeners();

    try {
      final activated = await _activate(uid);
      if (gen != _generation || !activated) return; // superseded
      for (final p in _participants) {
        await p.loadUserState(uid);
        if (gen != _generation) return;
      }
      _status = UserSessionStatus.ready;
    } catch (e) {
      if (gen != _generation) return;
      debugPrint('UserSession: failed to open storage for user: $e');
      for (final p in _participants) {
        try {
          p.clearUserState();
        } catch (_) {}
      }
      await _deactivate(); // fail closed: no fallback to shared storage
      if (gen != _generation) return;
      _error = e;
      _status = UserSessionStatus.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
