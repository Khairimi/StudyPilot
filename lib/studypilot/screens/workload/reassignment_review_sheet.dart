import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/logic/priority_engine.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';
import 'package:study_app/studypilot/screens/workload/reassignment_preview.dart';

/// Owner-only review of a suggested reassignment. Approve and Reject are
/// demo previews: no task is changed and the owner is told so. StudyPilot
/// never reassigns tasks automatically.
Future<void> showReassignmentReview(
  BuildContext context, {
  required ReassignmentPreview preview,
  required String Function(String? id) memberName,
  required DateTime now,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(SpSpacing.xl, 0, SpSpacing.xl, SpSpacing.xl),
        child: _ReviewBody(preview: preview, memberName: memberName, now: now),
      ),
    );

class _ReviewBody extends StatelessWidget {
  final ReassignmentPreview preview;
  final String Function(String? id) memberName;
  final DateTime now;
  const _ReviewBody({required this.preview, required this.memberName, required this.now});

  void _decide(BuildContext context, {required bool approve}) {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    showDemoNoticeOn(
      messenger,
      approve
          ? '"${preview.task.title}" was not reassigned. No task data changed.'
          : 'the suggestion was dismissed for this preview only. Nothing was saved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = preview;
    final fromName = memberName(p.from.userId);
    final toName = memberName(p.to.userId);
    final score = PriorityEngine.score(p.task, now).score;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Review reassignment', style: theme.textTheme.titleLarge),
        const SizedBox(height: SpSpacing.xs),
        Text('Owner approval is required. StudyPilot never reassigns tasks automatically.',
            style: theme.textTheme.bodyMedium),
        const SizedBox(height: SpSpacing.md),
        const SpDemoModeBanner(message: 'Demo mode: approving or rejecting will not change any task.'),
        const SizedBox(height: SpSpacing.lg),
        StudyPilotCard(
          padding: const EdgeInsets.all(SpSpacing.md),
          child: Row(
            children: [
              SpScoreBadge(score: score, size: 40),
              const SizedBox(width: SpSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.task.title, style: theme.textTheme.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text('${hoursText(p.taskHours)} · ${dueLabel(p.task.dueAt, now)}',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpSpacing.md),
        _MemberChange(
          label: 'From',
          name: fromName,
          userId: p.from.userId,
          before: p.from.activeHours,
          after: p.fromHoursAfter,
          threshold: p.threshold,
        ),
        const SizedBox(height: SpSpacing.sm),
        _MemberChange(
          label: 'To',
          name: toName,
          userId: p.to.userId,
          before: p.to.activeHours,
          after: p.toHoursAfter,
          threshold: p.threshold,
        ),
        const SizedBox(height: SpSpacing.md),
        _Check(ok: p.targetStaysHealthy, text: p.targetStaysHealthy
            ? '$toName stays under capacity'
            : '$toName would reach capacity'),
        _Check(ok: p.resolvesConflict, text: p.resolvesConflict
            ? 'Clears this conflict for $fromName'
            : 'Reduces, but does not fully clear, this conflict'),
        const SizedBox(height: SpSpacing.xl),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _decide(context, approve: false),
                child: const Text('Reject (demo)', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
            const SizedBox(width: SpSpacing.md),
            Expanded(
              child: FilledButton(
                onPressed: () => _decide(context, approve: true),
                child: const Text('Approve (demo)', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MemberChange extends StatelessWidget {
  final String label;
  final String name;
  final String userId;
  final double before;
  final double after;
  final double threshold;

  const _MemberChange({
    required this.label,
    required this.name,
    required this.userId,
    required this.before,
    required this.after,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = threshold > 0 ? after / threshold : 0.0;
    return StudyPilotCard(
      padding: const EdgeInsets.all(SpSpacing.md),
      child: Row(
        children: [
          SpMemberAvatar(name: name, colorSeed: userId, size: 32),
          const SizedBox(width: SpSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('$label: $name', style: theme.textTheme.labelLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: SpSpacing.xs),
                SpProgressBar(
                  value: ratio,
                  color: spCapacityColor(ratio),
                  label: '${hoursText(before)} → ${hoursText(after)}',
                  valueText: 'of ${hoursText(threshold)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool ok;
  final String text;
  const _Check({required this.ok, required this.text});

  @override
  Widget build(BuildContext context) {
    final tone = ok ? SpTone.success(context) : SpTone.warning(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SpSpacing.xxs + 1),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.info_outline_rounded, size: 18, color: tone.foreground),
          const SizedBox(width: SpSpacing.sm),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
