import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/theme/sp_colors.dart';
import 'package:study_app/studypilot/core/theme/sp_tokens.dart';

/// Rounded linear progress bar with optional label and value text, used for
/// project progress, member contribution and workload capacity.
class SpProgressBar extends StatelessWidget {
  /// 0.0 – 1.0 (values outside the range are clamped).
  final double value;
  final String? label;

  /// Text shown on the right; defaults to the percentage.
  final String? valueText;
  final Color? color;
  final double height;

  const SpProgressBar({
    super.key,
    required this.value,
    this.label,
    this.valueText,
    this.color,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    final barColor = color ?? theme.colorScheme.primary;
    final showHeader = label != null || valueText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader)
          Padding(
            padding: const EdgeInsets.only(bottom: SpSpacing.xs + 2),
            child: Row(
              children: [
                if (label != null)
                  Expanded(
                    child: Text(label!,
                        style: theme.textTheme.labelMedium,
                        overflow: TextOverflow.ellipsis),
                  )
                else
                  const Spacer(),
                Text(
                  valueText ?? '${(v * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        Semantics(
          value: '${(v * 100).round()}%',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(SpRadius.pill),
            child: LinearProgressIndicator(
              value: v,
              minHeight: height,
              color: barColor,
              backgroundColor: theme.colorScheme.surfaceContainerHigh,
            ),
          ),
        ),
      ],
    );
  }
}

/// Picks a capacity colour: green under 70%, amber up to 100%, rose above.
/// Used for workload bars (e.g. assigned hours / threshold).
Color spCapacityColor(double ratio) {
  if (ratio > 1.0) return SpColors.rose600;
  if (ratio >= 0.7) return SpColors.amber500;
  return SpColors.emerald600;
}
