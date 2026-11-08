import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/design_system.dart';

/// Temporary content for StudyPilot tabs whose feature phase has not been
/// implemented yet.
class SpPlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const SpPlaceholderTab({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return SpEmptyState(icon: icon, title: title, message: message);
  }
}
