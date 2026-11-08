import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/theme/sp_colors.dart';
import 'package:study_app/studypilot/core/theme/sp_semantics.dart';
import 'package:study_app/studypilot/core/theme/sp_tokens.dart';

/// Small pill label with a soft background (prototype: text-[11px] font-semibold
/// rounded-full px-2 py-0.5).
class SpBadge extends StatelessWidget {
  final String label;
  final SpTone tone;
  final IconData? icon;

  const SpBadge({super.key, required this.label, required this.tone, this.icon});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: tone.foreground,
          height: 1.2,
        );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SpSpacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(SpRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: tone.foreground),
            const SizedBox(width: SpSpacing.xs),
          ],
          Text(label, style: style),
        ],
      ),
    );
  }
}

/// Task status pill (To Do / In Progress / In Review / Completed).
class SpStatusBadge extends StatelessWidget {
  final SpTaskStatus status;
  final bool showIcon;
  const SpStatusBadge({super.key, required this.status, this.showIcon = true});

  @override
  Widget build(BuildContext context) => SpBadge(
        label: status.label,
        tone: status.tone(context),
        icon: showIcon ? status.icon : null,
      );
}

/// Task priority pill. If [score] is given (0–100 Smart Priority score) it
/// is shown next to the label, e.g. "Urgent · 92".
class SpPriorityBadge extends StatelessWidget {
  final SpPriority priority;
  final int? score;
  const SpPriorityBadge({super.key, required this.priority, this.score});

  @override
  Widget build(BuildContext context) => SpBadge(
        label: score == null ? priority.label : '${priority.label} · $score',
        tone: priority.tone(context),
        icon: priority.icon,
      );
}

/// Workload conflict severity pill.
class SpSeverityBadge extends StatelessWidget {
  final SpSeverity severity;
  const SpSeverityBadge({super.key, required this.severity});

  @override
  Widget build(BuildContext context) => SpBadge(
        label: '${severity.label} risk',
        tone: severity.tone(context),
        icon: Icons.warning_amber_rounded,
      );
}

/// Workspace role pill (Owner / Member).
class SpRoleBadge extends StatelessWidget {
  final SpRole role;
  const SpRoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) => SpBadge(
        label: role.label,
        tone: role.tone(context),
        icon: role == SpRole.owner ? Icons.shield_outlined : null,
      );
}
