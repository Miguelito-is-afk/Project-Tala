import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../view_models/timetable_view_model.dart';
import 'timetable_entry_editor_dialog.dart';

class TimetableEventDetailsDialog extends StatelessWidget {
  const TimetableEventDetailsDialog({
    required this.viewModel,
    required this.entry,
    required this.activeSubjects,
    super.key,
  });

  final TimetableViewModel viewModel;
  final TimetableEntry entry;
  final List<String> activeSubjects;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(entry.title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (entry.subject?.trim().isNotEmpty == true)
              _Field('Subject', entry.subject!),
            _Field('Day', _dayName(entry.dayOfWeek)),
            _Field(
              'Time',
              '${_format(entry.startMinutes)} – ${_format(entry.endMinutes)}',
            ),
            _Field('Type', entry.entryType.name),
            if (entry.teacher?.trim().isNotEmpty == true)
              _Field('Teacher', entry.teacher!),
            if (entry.room?.trim().isNotEmpty == true)
              _Field('Room', entry.room!),
            if (entry.notes.trim().isNotEmpty) _Field('Notes', entry.notes),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => _edit(context), child: const Text('Edit')),
        TextButton(
          onPressed: () => _delete(context),
          child: const Text('Delete'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => TimetableEntryEditorDialog(
        viewModel: viewModel,
        activeSubjects: activeSubjects,
        entry: entry,
      ),
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete timetable entry?'),
        content: const Text('This event will be permanently removed.'),
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
      await viewModel.deleteTimetableEntry(entry.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  static String _dayName(int day) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][day - 1];

  static String _format(int minutes) {
    final hour = minutes ~/ 60;
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '$displayHour:${(minutes % 60).toString().padLeft(2, '0')} '
        '${hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('$label: $value'),
    );
  }
}
