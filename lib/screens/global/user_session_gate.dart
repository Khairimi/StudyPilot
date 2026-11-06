import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_app/database/user_session.dart';

/// Shows a blocking overlay while the signed-in user's local storage is
/// loading, or an error with Retry / Sign out if it failed. The app's
/// Navigator stays mounted underneath, so no route state is lost.
class UserSessionGate extends StatelessWidget {
  final Widget child;

  /// Sign-out action for the error state (overridable in tests).
  final Future<void> Function()? onSignOut;

  const UserSessionGate({super.key, required this.child, this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<UserSession>();
    final status = session.status;
    final blocking =
        status == UserSessionStatus.loading || status == UserSessionStatus.error;

    return Stack(
      children: [
        // Hidden from input and semantics while blocked.
        ExcludeSemantics(
          excluding: blocking,
          child: AbsorbPointer(absorbing: blocking, child: child),
        ),
        if (blocking)
          Positioned.fill(
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Center(
                  child: status == UserSessionStatus.loading
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading your data…'),
                          ],
                        )
                      : _ErrorPanel(
                          onRetry: session.retry,
                          onSignOut: onSignOut ?? () => FirebaseAuth.instance.signOut(),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;

  const _ErrorPanel({required this.onRetry, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.storage_rounded, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text('Couldn\'t open your local data', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Your data has not been changed. Try again, or sign out and sign back in.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
          const SizedBox(height: 8),
          TextButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ),
    );
  }
}
