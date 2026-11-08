import 'package:flutter/widgets.dart';

/// Indexes of the StudyPilot shell tabs.
abstract final class SpTabs {
  static const int home = 0;
  static const int teams = 1;
  static const int tasks = 2;
  static const int reports = 3;
  static const int profile = 4;
}

/// Lets screens inside the shell switch tabs (e.g. Home → Tasks).
class SpShellScope extends InheritedWidget {
  final ValueChanged<int> selectTab;
  const SpShellScope({super.key, required this.selectTab, required super.child});

  static SpShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SpShellScope>();

  @override
  bool updateShouldNotify(SpShellScope oldWidget) => false;
}
