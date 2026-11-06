import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/theme/sp_colors.dart';
import 'package:study_app/studypilot/core/theme/sp_tokens.dart';

/// Tells the user plainly that an action was NOT saved (demo mode).
void showDemoNotice(BuildContext context, String message) =>
    showDemoNoticeOn(ScaffoldMessenger.of(context), message);

/// Same as [showDemoNotice], for callers that captured the messenger before
/// closing a sheet or route.
void showDemoNoticeOn(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(
        children: [
          const Icon(Icons.science_outlined, size: 18, color: Colors.white),
          const SizedBox(width: SpSpacing.sm),
          Expanded(child: Text('Demo only: $message')),
        ],
      ),
    ));
}

/// Inline banner for forms that run in demo mode.
class SpDemoModeBanner extends StatelessWidget {
  final String message;
  const SpDemoModeBanner({
    super.key,
    this.message = 'Demo mode: nothing you submit here will be saved.',
  });

  @override
  Widget build(BuildContext context) {
    final tone = SpTone.info(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: SpSpacing.md, vertical: SpSpacing.sm),
      decoration: BoxDecoration(color: tone.background, borderRadius: SpRadius.control),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 18, color: tone.foreground),
          const SizedBox(width: SpSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: tone.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
