import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/theme/sp_tokens.dart';

/// Section title with optional subtitle, leading icon and trailing action
/// (e.g. "Smart Priority Task Matrix ............ View all").
class SpSectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SpSectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: SpSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  semanticsLabel: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: SpSpacing.xxs),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (actionLabel != null && onAction != null)
            // Flexible so long action labels shrink instead of overflowing
            // narrow phones.
            Flexible(
              child: TextButton(
                onPressed: onAction,
                child: Text(actionLabel!, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
        ],
      ),
    );
  }
}
