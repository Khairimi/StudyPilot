import 'package:flutter/material.dart';
import 'package:study_app/studypilot/core/design_system.dart';
import 'package:study_app/studypilot/logic/priority_engine.dart';
import 'package:study_app/studypilot/logic/task_math.dart';
import 'package:study_app/studypilot/logic/workload_engine.dart';
import 'package:study_app/studypilot/models/models.dart';
import 'package:study_app/studypilot/screens/dashboard/dashboard_format.dart';
import 'package:study_app/studypilot/screens/tasks/task_filter.dart';

/// Create / edit / status / assign sheets. All are demo previews: input is
/// validated and the Smart Priority is previewed, but NOTHING is saved and
/// the user is told so.

Future<void> _sheet(BuildContext context, Widget child) => showModalBottomSheet<void>(
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

Future<void> showTaskFormSheet(
  BuildContext context, {
  required Workspace workspace,
  required List<Project> projects,
  required String currentUserId,
  required DateTime now,
  TeamTask? existing,
}) =>
    _sheet(
      context,
      _TaskForm(
        workspace: workspace,
        projects: projects,
        currentUserId: currentUserId,
        now: now,
        existing: existing,
      ),
    );

Future<void> showStatusSheet(BuildContext context, {required TeamTask task}) => _sheet(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Change status', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: SpSpacing.md),
          const SpDemoModeBanner(),
          const SizedBox(height: SpSpacing.sm),
          for (final s in SpTaskStatus.values)
            ListTile(
              leading: Icon(s.icon),
              title: Text(s.label),
              trailing: s == task.status ? const Icon(Icons.check_rounded) : null,
              onTap: () {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                if (s != task.status) {
                  showDemoNoticeOn(messenger, 'status was not changed to ${s.label}.');
                }
              },
            ),
        ],
      ),
    );

Future<void> showAssignSheet(
  BuildContext context, {
  required TeamTask task,
  required Workspace workspace,
  required List<TeamTask> allTasks,
  required DateTime now,
}) {
  final loads = {
    for (final w in WorkloadEngine.memberWorkloads(workspace, allTasks, now)) w.userId: w,
  };
  final hours = effectiveHours(task);
  return _sheet(
    context,
    Builder(builder: (context) {
      final theme = Theme.of(context);
      void pick(String? userId, String name) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        if (userId != task.assigneeId) {
          showDemoNoticeOn(messenger, '"${task.title}" was not reassigned to $name.');
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Assign task', style: theme.textTheme.titleLarge),
          const SizedBox(height: SpSpacing.xs),
          Text('Current load vs ${hoursText(workspace.workloadThresholdHours)} capacity',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: SpSpacing.md),
          const SpDemoModeBanner(),
          const SizedBox(height: SpSpacing.sm),
          for (final m in workspace.members)
            () {
              final load = loads[m.userId];
              final current = load?.activeHours ?? 0;
              final isCurrent = m.userId == task.assigneeId;
              final after = isCurrent ? current : current + (task.isActive ? hours : 0);
              final tooMuch = !isCurrent && task.isActive && after >= workspace.workloadThresholdHours;
              return ListTile(
                leading: SpMemberAvatar(name: m.displayName, colorSeed: m.userId, size: 34),
                title: Text(m.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  tooMuch
                      ? '${hoursText(current)} now · ${hoursText(after)} after: over capacity'
                      : '${hoursText(current)} assigned',
                  style: tooMuch ? TextStyle(color: theme.colorScheme.error) : null,
                ),
                trailing: isCurrent ? const Icon(Icons.check_rounded) : null,
                onTap: () => pick(m.userId, m.displayName),
              );
            }(),
          ListTile(
            leading: const Icon(Icons.person_off_outlined),
            title: const Text('Unassigned'),
            trailing: task.assigneeId == null ? const Icon(Icons.check_rounded) : null,
            onTap: () => pick(null, 'nobody'),
          ),
        ],
      );
    }),
  );
}

class _TaskForm extends StatefulWidget {
  final Workspace workspace;
  final List<Project> projects;
  final String currentUserId;
  final DateTime now;
  final TeamTask? existing;

  const _TaskForm({
    required this.workspace,
    required this.projects,
    required this.currentUserId,
    required this.now,
    this.existing,
  });

  @override
  State<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<_TaskForm> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _hours = TextEditingController(text: _initialHours(widget.existing));

  static String _initialHours(TeamTask? t) {
    final h = t?.estimatedHours ?? 0;
    if (h <= 0) return '';
    return h == h.roundToDouble() ? h.toInt().toString() : h.toString();
  }
  late String? _projectId =
      widget.existing?.projectId ?? (widget.projects.isEmpty ? null : widget.projects.first.id);
  late String? _assigneeId = widget.existing?.assigneeId ?? widget.currentUserId;
  late SpPriority _priority = widget.existing?.priority ?? SpPriority.medium;
  late SpTaskStatus _status = widget.existing?.status ?? SpTaskStatus.todo;
  late DateTime? _due = widget.existing?.dueAt;

  bool get _isNew => widget.existing == null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _hours.dispose();
    super.dispose();
  }

  TeamTask get _draft => TeamTask(
        id: widget.existing?.id ?? 'draft',
        workspaceId: widget.workspace.id,
        projectId: _projectId ?? '',
        title: _title.text.trim(),
        createdBy: widget.currentUserId,
        createdAt: widget.existing?.createdAt ?? widget.now,
        assigneeId: _assigneeId,
        priority: _priority,
        status: _status,
        dueAt: _due,
        estimatedHours: TaskValidators.parseHours(_hours.text),
        subtasks: widget.existing?.subtasks ?? const [],
      );

  Future<void> _pickDate(FormFieldState<DateTime?> field) async {
    final today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final initial = _due ?? today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) && _isNew ? today : initial,
      firstDate: _isNew ? today : DateTime(today.year - 1),
      lastDate: DateTime(today.year + 3),
    );
    if (picked == null) return;
    setState(() => _due = DateTime(picked.year, picked.month, picked.day, 17));
    field.didChange(_due);
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final title = _title.text.trim();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    showDemoNoticeOn(
      messenger,
      _isNew ? '"$title" was not created.' : 'changes to "$title" were not saved.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = PriorityEngine.score(_draft, widget.now);

    return Form(
      key: _form,
      onChanged: () => setState(() {}), // refresh the live priority preview
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_isNew ? 'New task' : 'Edit task', style: theme.textTheme.titleLarge),
          const SizedBox(height: SpSpacing.md),
          const SpDemoModeBanner(),
          const SizedBox(height: SpSpacing.lg),
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
            textInputAction: TextInputAction.next,
            validator: TaskValidators.title,
          ),
          const SizedBox(height: SpSpacing.md),
          TextFormField(
            controller: _description,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
            maxLines: 2,
          ),
          const SizedBox(height: SpSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _projectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Project'),
            items: [
              for (final p in widget.projects)
                DropdownMenuItem(value: p.id, child: Text(p.title, overflow: TextOverflow.ellipsis)),
            ],
            validator: TaskValidators.project,
            onChanged: (v) => setState(() => _projectId = v),
          ),
          const SizedBox(height: SpSpacing.md),
          DropdownButtonFormField<String?>(
            initialValue: _assigneeId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Assignee'),
            items: [
              for (final m in widget.workspace.members)
                DropdownMenuItem(value: m.userId, child: Text(m.displayName, overflow: TextOverflow.ellipsis)),
              const DropdownMenuItem(value: null, child: Text('Unassigned')),
            ],
            onChanged: (v) => setState(() => _assigneeId = v),
          ),
          const SizedBox(height: SpSpacing.md),
          Text('Priority', style: theme.textTheme.labelLarge),
          const SizedBox(height: SpSpacing.xs),
          Wrap(
            spacing: SpSpacing.sm,
            children: [
              for (final p in SpPriority.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _priority == p,
                  onSelected: (_) => setState(() => _priority = p),
                ),
            ],
          ),
          if (!_isNew) ...[
            const SizedBox(height: SpSpacing.md),
            DropdownButtonFormField<SpTaskStatus>(
              initialValue: _status,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status'),
              items: [for (final s in SpTaskStatus.values) DropdownMenuItem(value: s, child: Text(s.label))],
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
          ],
          const SizedBox(height: SpSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FormField<DateTime?>(
                  initialValue: _due,
                  validator: (_) => TaskValidators.dueDate(_due, widget.now, isNew: _isNew),
                  builder: (field) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _pickDate(field),
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: Text(
                          _due == null ? 'No due date' : dueLabel(_due, widget.now),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_due != null)
                        TextButton(
                          onPressed: () {
                            setState(() => _due = null);
                            field.didChange(null);
                          },
                          child: const Text('Clear date'),
                        ),
                      if (field.hasError)
                        Padding(
                          padding: const EdgeInsets.only(top: SpSpacing.xs),
                          child: Text(field.errorText!,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: SpSpacing.md),
              SizedBox(
                width: 120,
                child: TextFormField(
                  controller: _hours,
                  decoration: const InputDecoration(labelText: 'Est. hours'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: TaskValidators.hours,
                ),
              ),
            ],
          ),
          const SizedBox(height: SpSpacing.lg),
          StudyPilotCard(
            padding: const EdgeInsets.all(SpSpacing.md),
            child: Row(
              children: [
                SpScoreBadge(score: preview.score),
                const SizedBox(width: SpSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Smart Priority preview', style: theme.textTheme.labelLarge),
                      Text(preview.reasons.join(' · '),
                          style: theme.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SpSpacing.xl),
          FilledButton(
            onPressed: _submit,
            child: Text(_isNew ? 'Create task (demo)' : 'Save changes (demo)'),
          ),
        ],
      ),
    );
  }
}
