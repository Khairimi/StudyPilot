import 'package:flutter/widgets.dart';

/// Minimal identity of the signed-in user for StudyPilot screens.
@immutable
class SpUserInfo {
  final String uid;
  final String displayName;
  const SpUserInfo({required this.uid, required this.displayName});
}

/// Provides [SpUserInfo] to StudyPilot tabs (set up by the shell).
class SpUserScope extends InheritedWidget {
  final SpUserInfo user;
  const SpUserScope({super.key, required this.user, required super.child});

  static SpUserInfo of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SpUserScope>();
    assert(scope != null, 'SpUserScope not found: wrap StudyPilot screens in the shell.');
    return scope!.user;
  }

  @override
  bool updateShouldNotify(SpUserScope oldWidget) =>
      oldWidget.user.uid != user.uid || oldWidget.user.displayName != user.displayName;
}
