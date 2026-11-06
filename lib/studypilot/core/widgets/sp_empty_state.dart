import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/theme/sp_tokens.dart';

/// Centered empty state: tinted icon, title, message and optional action
/// (e.g. "No workspaces yet" + "Create workspace").
class SpEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SpEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(SpSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(SpRadius.lg + 4),
                ),
                child: Icon(icon, size: 30, color: theme.colorScheme.onPrimaryContainer),
              ),
              const SizedBox(height: SpSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (message != null) ...[
                const SizedBox(height: SpSpacing.xs + 2),
                Text(message!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
              ],
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: SpSpacing.lg),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
