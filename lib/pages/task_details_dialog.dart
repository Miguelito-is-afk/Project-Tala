import 'package:flutter/material.dart';

import '../models/task.dart';
import '../view_models/task_view_model.dart';
import 'task_editor_dialog.dart';

class TaskDetailsDialog extends StatelessWidget {
  const TaskDetailsDialog({
    required this.viewModel,
    required this.task,
    super.key,
  });

  final TaskViewModel viewModel;
  final Task task;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final current = viewModel.tasks.firstWhere(
          (value) => value.id == task.id,
          orElse: () => task,
        );
        return AlertDialog(
          title: Text(current.title),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Detail(label: 'Subject', value: current.subject),
                  _Detail(
                    label: 'Due date',
                    value: current.dueDate == null
                        ? 'No due date'
                        : _formatDate(current.dueDate!),
                  ),
                  _Detail(label: 'Priority', value: current.priority.name),
                  _Detail(
                    label: 'Status',
                    value: current.isCompleted ? 'Completed' : 'Open',
                  ),
                  if (current.description.isNotEmpty)
                    _Detail(label: 'Description', value: current.description),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => _toggle(context, current),
              child: Text(
                current.isCompleted ? 'Mark incomplete' : 'Mark complete',
              ),
            ),
            TextButton(
              onPressed: () => _edit(context, current),
              child: const Text('Edit'),
            ),
            TextButton(
              onPressed: () => _delete(context, current),
              child: const Text('Delete'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context, Task current) async {
    final succeeded = await viewModel.toggleTask(current.id);
    if (!succeeded || !context.mounted) return;
    if (!viewModel.tasks.any((task) => task.id == current.id)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _edit(BuildContext context, Task current) async {
    final updated = await showDialog<Task>(
      context: context,
      builder: (_) => TaskEditorDialog(
        task: current,
        subjects: viewModel.availableSubjects,
      ),
    );
    if (updated != null) await viewModel.updateTask(updated);
  }

  Future<void> _delete(BuildContext context, Task current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This task will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await viewModel.deleteTask(current.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 2),
          Text(value),
        ],
      ),
    );
  }
}
