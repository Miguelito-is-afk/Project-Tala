import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/subjects.dart';
import '../models/task.dart';

const int taskDescriptionMaxLength = 1000;

class TaskEditorDialog extends StatefulWidget {
  const TaskEditorDialog({
    this.task,
    this.subjects = const [reminderSubject, ...appSubjects],
    super.key,
  });

  /// Null means we are creating a new task.
  /// Non-null means we are editing an existing task.
  final Task? task;
  final List<String> subjects;

  @override
  State<TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<TaskEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _subjectController;

  late TaskPriority _priority;
  late String _selectedSubject;

  DateTime? _dueDate;

  bool get _isEditing => widget.task != null;

  bool get _isCustomSubject => _selectedSubject == customSubjectOption;

  bool get _canSave {
    final titleIsValid = _titleController.text.trim().isNotEmpty;
    final descriptionIsValid =
        _descriptionController.text.length <= taskDescriptionMaxLength;

    if (!titleIsValid || !descriptionIsValid) {
      return false;
    }

    if (_isCustomSubject) {
      final customSubject = _subjectController.text.trim();

      if (customSubject.isEmpty) {
        return false;
      }

      if (customSubject.toLowerCase() == reminderSubject.toLowerCase()) {
        return false;
      }
    }

    return true;
  }

  String? get _descriptionError {
    final description = _descriptionController.text;
    if (description.length > taskDescriptionMaxLength) {
      return 'Description must be 1000 characters or fewer.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();

    final task = widget.task;

    _titleController = TextEditingController(text: task?.title ?? '');

    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );

    final storedSubject = task?.subject.trim();

    if (storedSubject == null ||
        storedSubject.isEmpty ||
        storedSubject == reminderSubject) {
      _selectedSubject = reminderSubject;
      _subjectController = TextEditingController();
    } else if (widget.subjects.contains(storedSubject)) {
      _selectedSubject = storedSubject;
      _subjectController = TextEditingController();
    } else {
      _selectedSubject = customSubjectOption;
      _subjectController = TextEditingController(text: storedSubject);
    }

    _priority = task?.priority ?? TaskPriority.medium;
    _dueDate = task?.dueDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit task' : 'Add task'),
      content: SizedBox(
        width: math.max(
          0.0,
          math.min(560.0, MediaQuery.sizeOf(context).width - 80),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: !_isEditing,
                onChanged: (_) {
                  setState(() {});
                },
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  hintText: 'e.g. Finish Biology report',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                maxLength: taskDescriptionMaxLength,
                maxLines: 4,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                onChanged: (_) => setState(() {}),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(taskDescriptionMaxLength),
                ],
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional details',
                  border: const OutlineInputBorder(),
                  counterText:
                      '${_descriptionController.text.length} / $taskDescriptionMaxLength',
                  errorText: _descriptionError,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedSubject,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: reminderSubject,
                    child: Text(
                      'Reminder / No subject',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...widget.subjects
                      .where((subject) => subject != reminderSubject)
                      .map(
                        (subject) => DropdownMenuItem<String>(
                          value: subject,
                          child: Text(
                            subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                  const DropdownMenuItem<String>(
                    value: customSubjectOption,
                    child: Text('Custom subject...'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _selectedSubject = value;

                    if (value != customSubjectOption) {
                      _subjectController.clear();
                    }
                  });
                },
              ),
              if (_isCustomSubject) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _subjectController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    setState(() {});
                  },
                  decoration: const InputDecoration(
                    labelText: 'Custom subject',
                    hintText: 'e.g. Scholarship',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
                items: TaskPriority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(_priorityLabel(priority)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _priority = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickDueDate,
                      icon: const Icon(Icons.calendar_today_outlined),
                      label: Text(
                        _dueDate == null
                            ? 'Choose due date'
                            : _formatDate(_dueDate!),
                      ),
                    ),
                    if (_dueDate != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _dueDate = null;
                          });
                        },
                        child: const Text('Remove due date'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: Text(_isEditing ? 'Save changes' : 'Create task'),
        ),
      ],
    );
  }

  Future<void> _pickDueDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      initialDate: _dueDate ?? DateTime.now(),
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      _dueDate = selectedDate;
    });
  }

  void _save() {
    final title = _titleController.text.trim();

    if (title.isEmpty) {
      return;
    }

    final subject = _getSubjectForSaving();

    if (_isCustomSubject && subject == reminderSubject) {
      return;
    }

    final description = _descriptionController.text;
    if (description.length > taskDescriptionMaxLength) {
      return;
    }

    if (_isEditing) {
      final existingTask = widget.task!;

      final updatedTask = existingTask.copyWith(
        title: title,
        description: description.trim(),
        subject: subject,
        dueDate: _dueDate,
        clearDueDate: _dueDate == null,
        priority: _priority,
        updatedAt: DateTime.now().toUtc(),
      );

      Navigator.of(context).pop(updatedTask);
      return;
    }

    final newTask = Task.create(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      description: description.trim(),
      subject: subject,
      dueDate: _dueDate,
      priority: _priority,
    );

    Navigator.of(context).pop(newTask);
  }

  String _getSubjectForSaving() {
    if (_selectedSubject == reminderSubject) {
      return reminderSubject;
    }

    if (_selectedSubject == customSubjectOption) {
      final customSubject = _subjectController.text.trim();

      return customSubject.isEmpty ? reminderSubject : customSubject;
    }

    return _selectedSubject;
  }

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  String _formatDate(DateTime date) {
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

    return '${months[localDate.month - 1]} '
        '${localDate.day}, '
        '${localDate.year}';
  }
}
