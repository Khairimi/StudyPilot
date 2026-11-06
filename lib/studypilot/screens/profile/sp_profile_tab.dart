import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:study_app/providers/theme_provider.dart';
import 'package:study_app/screens/global/auth_screens.dart';
import 'package:study_app/screens/global/main_screen.dart';
import 'package:study_app/services/auth_service.dart';
import 'package:study_app/studypilot/core/design_system.dart';

/// StudyPilot Profile tab (minimal for Phase 2): account header, theme
/// toggle, entry to the legacy StudyFlow tools, and sign out.
class SpProfileTab extends StatelessWidget {
  const SpProfileTab({super.key});

  Future<void> _signOut(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthService.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthEntryScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : (user?.email?.split('@').first ?? 'StudyPilot user');
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();

    return ListView(
      padding: const EdgeInsets.all(SpSpacing.lg),
      children: [
        StudyPilotCard(
          child: Row(
            children: [
              SpMemberAvatar(
                name: name,
                colorSeed: user?.uid,
                photoUrl: user?.photoURL,
                size: 56,
              ),
              const SizedBox(width: SpSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                    if (user?.email != null)
                      Text(user!.email!, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SpSpacing.xl),
        const SpSectionHeading(title: 'Preferences'),
        StudyPilotCard(
          padding: EdgeInsets.zero,
          child: SwitchListTile(
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('Dark mode'),
            value: themeProvider.isDarkMode,
            onChanged: themeProvider.toggleTheme,
          ),
        ),
        const SizedBox(height: SpSpacing.xl),
        const SpSectionHeading(
          title: 'StudyFlow Tools',
          subtitle: 'Your original CSC660 subjects, notes, flashcards, timer and attendance.',
        ),
        StudyPilotCard(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Open StudyFlow Tools'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MainScreen()),
            ),
          ),
        ),
        const SizedBox(height: SpSpacing.xl),
        OutlinedButton.icon(
          onPressed: () => _signOut(context),
          icon: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
          label: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
        ),
      ],
    );
  }
}
