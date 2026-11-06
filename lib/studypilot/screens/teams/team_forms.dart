import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';
import 'package:study_app/studypilot/screens/teams/workspace_overview.dart';

/// Create / join / invite forms. They validate input like the real flows
/// will, but in demo mode NOTHING is saved and the user is told so.

Future<void> _showSheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(SpSpacing.xl, 0, SpSpacing.xl, SpSpacing.xl),
          child: child,
        ),
      ),
    );

Future<void> showCreateWorkspaceSheet(BuildContext context) =>
    _showSheet(context, const _CreateWorkspaceForm());

Future<void> showJoinWorkspaceSheet(BuildContext context, {required List<WorkspaceOverview> mine}) =>
    _showSheet(context, _JoinWorkspaceForm(mine: mine));

Future<void> showInviteMemberSheet(BuildContext context, {required Workspace workspace}) =>
    _showSheet(context, _InviteMemberForm(workspace: workspace));

class _SheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SheetHeader(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: SpSpacing.xs),
        Text(subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: SpSpacing.md),
        const SpDemoModeBanner(),
        const SizedBox(height: SpSpacing.lg),
      ],
    );
  }
}

class _CreateWorkspaceForm extends StatefulWidget {
  const _CreateWorkspaceForm();
  @override
  State<_CreateWorkspaceForm> createState() => _CreateWorkspaceFormState();
}

class _CreateWorkspaceFormState extends State<_CreateWorkspaceForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _description = TextEditingController();
  WorkspaceType _type = WorkspaceType.smallBusiness;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final name = _name.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    showDemoNoticeOn(messenger,
        '"$name" was not created. Creating workspaces will be enabled with Firebase integration.');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader('Create workspace', 'Start a shared space for your team and its projects.'),
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Workspace name'),
            textInputAction: TextInputAction.next,
            validator: TeamValidators.workspaceName,
          ),
          const SizedBox(height: SpSpacing.md),
          DropdownButtonFormField<WorkspaceType>(
            initialValue: _type,
            isExpanded: true, // long labels must not overflow on narrow phones
            decoration: const InputDecoration(labelText: 'Team type'),
            items: [
              for (final t in WorkspaceType.values)
                DropdownMenuItem(value: t, child: Text(workspaceTypeLabel(t))),
            ],
            onChanged: (t) => setState(() => _type = t ?? _type),
          ),
          const SizedBox(height: SpSpacing.md),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: SpSpacing.xl),
          FilledButton(onPressed: _submit, child: const Text('Create workspace (demo)')),
        ],
      ),
    );
  }
}

class _JoinWorkspaceForm extends StatefulWidget {
  final List<WorkspaceOverview> mine;
  const _JoinWorkspaceForm({required this.mine});
  @override
  State<_JoinWorkspaceForm> createState() => _JoinWorkspaceFormState();
}

class _JoinWorkspaceFormState extends State<_JoinWorkspaceForm> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final code = TeamValidators.normaliseCode(_code.text);
    final existing = widget.mine.where((w) => w.workspace.inviteCode.toUpperCase() == code).firstOrNull;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    showDemoNoticeOn(
      messenger,
      existing != null
          ? 'you are already a member of ${existing.workspace.name}. Nothing was changed.'
          : 'joining with code $code is not connected yet. Nothing was changed.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader('Join workspace', 'Enter the 6-character code shared by the workspace owner.'),
          TextFormField(
            controller: _code,
            decoration: const InputDecoration(labelText: 'Invite code', hintText: 'e.g. AB12CD'),
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            validator: TeamValidators.inviteCode,
          ),
          const SizedBox(height: SpSpacing.md),
          FilledButton(onPressed: _submit, child: const Text('Join workspace (demo)')),
        ],
      ),
    );
  }
}

class _InviteMemberForm extends StatefulWidget {
  final Workspace workspace;
  const _InviteMemberForm({required this.workspace});
  @override
  State<_InviteMemberForm> createState() => _InviteMemberFormState();
}

class _InviteMemberFormState extends State<_InviteMemberForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  SpRole _role = SpRole.member;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final email = _email.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    showDemoNoticeOn(messenger, 'no invitation was sent to $email.');
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader('Invite member', 'Invite someone to ${widget.workspace.name}.'),
          TextFormField(
            controller: _email,
            decoration: const InputDecoration(labelText: 'Email address'),
            keyboardType: TextInputType.emailAddress,
            validator: TeamValidators.email,
          ),
          const SizedBox(height: SpSpacing.md),
          SegmentedButton<SpRole>(
            segments: [
              for (final r in SpRole.values) ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          const SizedBox(height: SpSpacing.sm),
          Text(
            'Or share the invite code: ${widget.workspace.inviteCode}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: SpSpacing.xl),
          FilledButton(onPressed: _submit, child: const Text('Send invite (demo)')),
        ],
      ),
    );
  }
}
