import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/theme/sp_colors.dart';
import 'package:study_app/studypilot/core/theme/sp_tokens.dart';

/// Smart Priority score tile (0–100): rose ≥70, amber ≥40, otherwise brand.
class SpScoreBadge extends StatelessWidget {
  final int score;
  final double size;
  const SpScoreBadge({super.key, required this.score, this.size = 44});

  static SpTone toneFor(BuildContext context, int score) => score >= 70
      ? SpTone.danger(context)
      : score >= 40
          ? SpTone.warning(context)
          : SpTone.brand(context);

  @override
  Widget build(BuildContext context) {
    final tone = toneFor(context, score);
    return Semantics(
      label: 'Smart Priority score $score',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(SpRadius.md)),
        child: Text(
          '$score',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: tone.foreground,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
              ),
        ),
      ),
    );
  }
}
