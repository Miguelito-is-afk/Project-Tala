import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../view_models/timetable_view_model.dart';

class TimetableEntryEditorDialog extends StatefulWidget {
  const TimetableEntryEditorDialog({
    required this.viewModel,
    this.activeSubjects = const [],
    this.entry,
    super.key,
  });

  final TimetableViewModel viewModel;
  final List<String> activeSubjects;
  final TimetableEntry? entry;

  @override
  State<TimetableEntryEditorDialog> createState() =>
      _TimetableEntryEditorDialogState();
}

String? validateTimetableEntryFields({
  required String title,
  required int dayOfWeek,
  required int startMinutes,
  required int endMinutes,
}) {
  if (title.trim().isEmpty) return 'Title cannot be blank.';
  if (dayOfWeek < 1 || dayOfWeek > 5) {
    return 'Day must be Monday through Friday.';
  }
  if (startMinutes < 0 ||
      startMinutes > 1440 ||
      endMinutes < 0 ||
      endMinutes > 1440) {
    return 'Times must be within 00:00 and 24:00.';
  }
  if (startMinutes >= endMinutes) {
    return 'Start time must be before end time.';
  }
  return null;
}

class _TimetableEntryEditorDialogState
    extends State<TimetableEntryEditorDialog> {
  static const _noSubject = '__no_subject__';
  late final TextEditingController _titleController;
  late String _subject;
  late final TextEditingController _teacherController;
  late final TextEditingController _roomController;
  late final TextEditingController _notesController;
  late int _dayOfWeek;
  late int _startMinutes;
  late int _endMinutes;
  late TimetableEntryType _entryType;
  String? _validationError;
  bool _isSaving = false;

  bool get _isEditing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _titleController = TextEditingController(text: entry?.title ?? '');
    _subject = entry?.subject ?? _noSubject;
    _teacherController = TextEditingController(text: entry?.teacher ?? '');
    _roomController = TextEditingController(text: entry?.room ?? '');
    _notesController = TextEditingController(text: entry?.notes ?? '');
    _dayOfWeek = entry?.dayOfWeek ?? widget.viewModel.selectedWeekday;
    _startMinutes = entry?.startMinutes ?? 480;
    _endMinutes = entry?.endMinutes ?? 540;
    _entryType = entry?.entryType ?? TimetableEntryType.classSession;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _teacherController.dispose();
    _roomController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Timetable Entry' : 'Add Timetable Entry'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: !_isEditing,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _subjectOptions.contains(_subject)
                    ? _subject
                    : _subject,
                decoration: const InputDecoration(
                  labelText: 'Subject (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: _noSubject,
                    child: Text('No subject'),
                  ),
                  for (final subject in _subjectOptions.where(
                    (subject) => subject != _noSubject,
                  ))
                    DropdownMenuItem(value: subject, child: Text(subject)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _subject = value);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _dayOfWeek,
                decoration: const InputDecoration(
                  labelText: 'Day',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (var day = 1; day <= 5; day++)
                    DropdownMenuItem(value: day, child: Text(_dayName(day))),
                ],
                onChanged: (value) =>
                    setState(() => _dayOfWeek = value ?? _dayOfWeek),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _timeButton('Start', _startMinutes, true)),
                  const SizedBox(width: 12),
                  Expanded(child: _timeButton('End', _endMinutes, false)),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TimetableEntryType>(
                initialValue: _entryType,
                decoration: const InputDecoration(
                  labelText: 'Entry type',
                  border: OutlineInputBorder(),
                ),
                items: TimetableEntryType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(_typeName(type)),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _entryType = value ?? _entryType),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _teacherController,
                decoration: const InputDecoration(
                  labelText: 'Teacher (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _roomController,
                decoration: const InputDecoration(
                  labelText: 'Room (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_validationError != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _validationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_isEditing)
          TextButton(
            onPressed: _isSaving ? null : _delete,
            child: const Text('Delete'),
          ),
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isEditing ? 'Save changes' : 'Add entry'),
        ),
      ],
    );
  }

  Widget _timeButton(String label, int minutes, bool isStart) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      onPressed: _isSaving
          ? null
          : () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                  hour: minutes ~/ 60,
                  minute: minutes % 60,
                ),
              );
              if (picked != null) {
                setState(() {
                  final value = picked.hour * 60 + picked.minute;
                  if (isStart) {
                    _startMinutes = value;
                  } else {
                    _endMinutes = value;
                  }
                });
              }
            },
      child: Text('$label\n${_formatMinutes(minutes)}'),
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final validationError = validateTimetableEntryFields(
      title: title,
      dayOfWeek: _dayOfWeek,
      startMinutes: _startMinutes,
      endMinutes: _endMinutes,
    );
    if (validationError != null) {
      setState(() => _validationError = validationError);
      return;
    }

    setState(() {
      _validationError = null;
      _isSaving = true;
    });
    final entry = TimetableEntry(
      id: widget.entry?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      dayOfWeek: _dayOfWeek,
      startMinutes: _startMinutes,
      endMinutes: _endMinutes,
      subject: _subject == _noSubject ? null : _subject,
      teacher: _optional(_teacherController.text),
      room: _optional(_roomController.text),
      entryType: _entryType,
      notes: _notesController.text.trim(),
    );
    final success = _isEditing
        ? await widget.viewModel.updateTimetableEntry(entry)
        : await widget.viewModel.addTimetableEntry(entry);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSaving = false;
        _validationError =
            widget.viewModel.mutationErrorMessage ?? 'Unable to save entry.';
      });
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete timetable entry?'),
        content: const Text('This entry will be permanently removed.'),
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
    if (confirmed != true) return;
    setState(() => _isSaving = true);
    final success = await widget.viewModel.deleteTimetableEntry(
      widget.entry!.id,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSaving = false;
        _validationError =
            widget.viewModel.mutationErrorMessage ?? 'Unable to delete entry.';
      });
    }
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> get _subjectOptions {
    final subjects = <String>[...widget.activeSubjects];
    if (widget.entry?.subject != null &&
        !subjects.contains(widget.entry!.subject)) {
      subjects.add(widget.entry!.subject!);
    }
    return subjects;
  }

  static String _dayName(int day) =>
      const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'][day - 1];

  static String _typeName(TimetableEntryType type) {
    return switch (type) {
      TimetableEntryType.classSession => 'Class',
      TimetableEntryType.breakTime => 'Break',
      TimetableEntryType.consultation => 'Consultation',
      TimetableEntryType.activity => 'Activity',
      TimetableEntryType.other => 'Other',
    };
  }

  static String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '$displayHour:${minute.toString().padLeft(2, '0')}';
  }
}
