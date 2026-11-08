import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/theme/sp_tokens.dart';

/// Base StudyPilot surface: white/slate-900 card, 16px radius, hairline
/// border and a very soft shadow (prototype: rounded-2xl + shadow-xs).
class StudyPilotCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Optional accent stripe on the left (e.g. member or severity colour).
  final Color? accentColor;

  /// Optional override of the background (e.g. a tinted alert card).
  final Color? color;

  const StudyPilotCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SpSpacing.lg),
    this.onTap,
    this.accentColor,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = Padding(padding: padding, child: child);
    if (accentColor != null) {
      // The card sizes to its content; the stripe just fills the left edge.
      // (IntrinsicHeight estimates can be a few pixels short for wrapped
      // text on web, which overflowed the card at the bottom.)
      content = Stack(
        children: [
          Padding(padding: const EdgeInsets.only(left: 4), child: content),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: ColoredBox(color: accentColor!),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surface,
        borderRadius: SpRadius.card,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: SpRadius.card,
        clipBehavior: Clip.antiAlias,
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}
