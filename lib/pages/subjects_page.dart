import 'package:flutter/material.dart';

import '../app/motion.dart';
import '../app/subjects.dart';
import '../models/task.dart';
import '../view_models/task_view_model.dart';

class SubjectsPage extends StatefulWidget {
  const SubjectsPage({
    required this.viewModel,
    required this.onSubjectSelected,
    super.key,
  });

  final TaskViewModel viewModel;
  final ValueChanged<String> onSubjectSelected;

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> {
  TaskViewModel get viewModel => widget.viewModel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth >= 1000
                      ? 48.0
                      : 24.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 24,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subjects',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'See how your tasks are distributed across subjects.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _addSubject,
                          icon: const Icon(Icons.add),
                          label: const Text('Add subject'),
                        ),
                        if (viewModel.archivedSubjects.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _showArchivedSubjects,
                            icon: const Icon(Icons.archive_outlined),
                            label: Text(
                              'Archived subjects '
                              '(${viewModel.archivedSubjects.length})',
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        Text(
                          'Active subjects',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cardWidth = constraints.maxWidth >= 800
                                ? (constraints.maxWidth - 16) / 2
                                : constraints.maxWidth;

                            return Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              children: viewModel.availableSubjects.map((
                                subject,
                              ) {
                                return SizedBox(
                                  width: cardWidth,
                                  child: _SubjectCard(
                                    subject: subject,
                                    tasks: viewModel.tasksForSubject(subject),
                                    nextDueTask: viewModel
                                        .nextDueTaskForSubject(subject),
                                    onTap: () =>
                                        widget.onSubjectSelected(subject),
                                    onArchive: subject == reminderSubject
                                        ? null
                                        : () => _archiveSubject(subject),
                                    onEdit: subject == reminderSubject
                                        ? null
                                        : () => _editSubject(subject),
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _addSubject() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _AddSubjectDialog(),
    );

    if (name == null || !mounted) {
      return;
    }

    final added = await viewModel.addSubject(name);
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added ? 'Subject added.' : 'Subject is empty or already exists.',
        ),
      ),
    );
  }

  Future<void> _archiveSubject(String subject) async {
    final shouldArchive = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Archive $subject?'),
          content: const Text(
            'Existing tasks will keep this subject and will not be changed.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Archive'),
            ),
          ],
        );
      },
    );

    if (shouldArchive != true || !mounted) {
      return;
    }

    await viewModel.archiveSubject(subject);
  }

  Future<void> _editSubject(String subject) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _EditSubjectDialog(initialName: subject),
    );
    if (name == null || !mounted) return;

    final renamed = await viewModel.renameSubject(subject, name);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          renamed
              ? 'Subject renamed.'
              : 'Subject name is blank or already exists.',
        ),
      ),
    );
  }

  Future<void> _showArchivedSubjects() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Archived subjects'),
          content: SizedBox(
            width: 420,
            child: ListView(
              shrinkWrap: true,
              children: viewModel.archivedSubjects.map((subject) {
                return ListTile(
                  title: Text(subject),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await viewModel.restoreSubject(subject);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: const Text('Restore'),
                      ),
                      IconButton(
                        tooltip: 'Delete permanently',
                        onPressed: () =>
                            _deleteArchivedSubject(context, subject),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteArchivedSubject(
    BuildContext context,
    String subject,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete archived subject permanently?'),
        content: Text(
          '$subject will be permanently removed from Project Tala. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final result = await viewModel.deleteArchivedSubject(subject);
    if (!context.mounted) return;
    if (result.deleted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Archived subject deleted.')),
      );
      return;
    }

    final message =
        result.taskReferenceCount > 0 || result.timetableReferenceCount > 0
        ? 'This subject cannot be permanently deleted because it is still '
              'used by ${result.taskReferenceCount} tasks and '
              '${result.timetableReferenceCount} timetable entries.'
        : viewModel.errorMessage ?? 'Subject deletion was not completed.';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Subject not deleted'),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _AddSubjectDialog extends StatefulWidget {
  const _AddSubjectDialog();

  @override
  State<_AddSubjectDialog> createState() => _AddSubjectDialogState();
}

class _AddSubjectDialogState extends State<_AddSubjectDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add subject'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Subject name',
          hintText: 'e.g. Economics',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}

class _EditSubjectDialog extends StatefulWidget {
  const _EditSubjectDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditSubjectDialog> createState() => _EditSubjectDialogState();
}

class _EditSubjectDialogState extends State<_EditSubjectDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Subject name cannot be blank.');
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit subject'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: 'Subject name',
          border: const OutlineInputBorder(),
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _SubjectCard extends StatelessWidget {
  const _SubjectCard({
    required this.subject,
    required this.tasks,
    required this.nextDueTask,
    required this.onTap,
    required this.onArchive,
    required this.onEdit,
  });

  final String subject;
  final List<Task> tasks;
  final Task? nextDueTask;
  final VoidCallback onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final completedCount = tasks.where((task) => task.isCompleted).length;
    final incompleteCount = tasks.length - completedCount;
    final displayName = subject == reminderSubject ? 'Reminder' : subject;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Icon(
                      subject == reminderSubject
                          ? Icons.notifications_none_outlined
                          : Icons.menu_book_outlined,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      displayName,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (onArchive != null || onEdit != null)
                    PopupMenuButton<String>(
                      tooltip: 'Subject options',
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit!();
                        } else {
                          onArchive!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                        if (onArchive != null)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Text('Archive'),
                          ),
                      ],
                    )
                  else
                    const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _Stat(label: 'Total', value: '${tasks.length}'),
                  _Stat(label: 'Open', value: '$incompleteCount'),
                  _Stat(label: 'Done', value: '$completedCount'),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                nextDueTask == null
                    ? 'No upcoming due tasks'
                    : 'Next due: ${nextDueTask!.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (nextDueTask != null)
                Text(
                  _formatDueDate(nextDueTask!.dueDate!),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final localDate = date.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[localDate.month - 1]} ${localDate.day}, '
        '${localDate.year}';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedValueText(
            value,
            style: Theme.of(context).textTheme.titleLarge!
                .copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
