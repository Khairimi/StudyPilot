import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/theme/sp_colors.dart';

/// Shared vocabulary for the six CSC661 features. Defined with the design
/// system so badges look identical everywhere; later task/workload models
/// should reuse these enums rather than redefine them.

enum SpPriority { urgent, high, medium, low }

enum SpTaskStatus { todo, inProgress, inReview, completed }

enum SpSeverity { high, medium, low }

enum SpRole { owner, member }

extension SpPriorityX on SpPriority {
  String get label => switch (this) {
        SpPriority.urgent => 'Urgent',
        SpPriority.high => 'High',
        SpPriority.medium => 'Medium',
        SpPriority.low => 'Low',
      };

  IconData get icon => switch (this) {
        SpPriority.urgent => Icons.priority_high_rounded,
        SpPriority.high => Icons.keyboard_double_arrow_up_rounded,
        SpPriority.medium => Icons.drag_handle_rounded,
        SpPriority.low => Icons.keyboard_arrow_down_rounded,
      };

  SpTone tone(BuildContext context) => switch (this) {
        SpPriority.urgent => SpTone.danger(context),
        SpPriority.high => SpTone.warning(context),
        SpPriority.medium => SpTone.brand(context),
        SpPriority.low => SpTone.neutral(context),
      };
}

extension SpTaskStatusX on SpTaskStatus {
  String get label => switch (this) {
        SpTaskStatus.todo => 'To Do',
        SpTaskStatus.inProgress => 'In Progress',
        SpTaskStatus.inReview => 'In Review',
        SpTaskStatus.completed => 'Completed',
      };

  IconData get icon => switch (this) {
        SpTaskStatus.todo => Icons.radio_button_unchecked_rounded,
        SpTaskStatus.inProgress => Icons.timelapse_rounded,
        SpTaskStatus.inReview => Icons.rate_review_outlined,
        SpTaskStatus.completed => Icons.check_circle_rounded,
      };

  SpTone tone(BuildContext context) => switch (this) {
        SpTaskStatus.todo => SpTone.neutral(context),
        SpTaskStatus.inProgress => SpTone.brand(context),
        SpTaskStatus.inReview => SpTone.info(context),
        SpTaskStatus.completed => SpTone.success(context),
      };
}

extension SpSeverityX on SpSeverity {
  String get label => switch (this) {
        SpSeverity.high => 'High',
        SpSeverity.medium => 'Medium',
        SpSeverity.low => 'Low',
      };

  SpTone tone(BuildContext context) => switch (this) {
        SpSeverity.high => SpTone.danger(context),
        SpSeverity.medium => SpTone.warning(context),
        SpSeverity.low => SpTone.info(context),
      };
}

extension SpRoleX on SpRole {
  String get label => switch (this) {
        SpRole.owner => 'Owner',
        SpRole.member => 'Member',
      };

  SpTone tone(BuildContext context) => switch (this) {
        SpRole.owner => SpTone.brand(context),
        SpRole.member => SpTone.neutral(context),
      };
}
