import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/branding.dart';
import '../app/motion.dart';
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
    final viewport = MediaQuery.sizeOf(context);
    final dialogWidth = math.max(0.0, math.min(760.0, viewport.width - 48));
    final dialogMaxHeight = math.max(
      0.0,
      math.min(720.0, viewport.height - 48),
    );
    final fields = <_EntryDetailData>[
      if (entry.subject?.trim().isNotEmpty == true)
        _EntryDetailData('Subject', entry.subject!.trim()),
      _EntryDetailData('Day', _dayName(entry.dayOfWeek)),
      _EntryDetailData(
        'Time',
        '${_format(entry.startMinutes)} – ${_format(entry.endMinutes)}',
      ),
      _EntryDetailData('Type', entry.entryType.name),
      if (entry.teacher?.trim().isNotEmpty == true)
        _EntryDetailData('Teacher', entry.teacher!.trim()),
      if (entry.room?.trim().isNotEmpty == true)
        _EntryDetailData('Room', entry.room!.trim()),
    ];

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogMaxHeight,
        ),
        child: SizedBox(
          width: dialogWidth,
          child: AnimatedSize(
            alignment: Alignment.topCenter,
            duration: accessibleMotionDuration(context),
            curve: Curves.easeInOutCubic,
            child: Container(
              key: const ValueKey('timetable-entry-details-surface'),
              constraints: BoxConstraints(maxHeight: dialogMaxHeight),
              decoration: BoxDecoration(
                color: talaSurface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: talaBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (entry.subject?.trim().isNotEmpty == true) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: talaSky,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              entry.subject!.trim(),
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: talaBlue,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          entry.title,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: talaInk,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: talaBorder),
                  Flexible(
                    fit: FlexFit.loose,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final wide = constraints.maxWidth >= 520;
                        final itemWidth = wide
                            ? (constraints.maxWidth - 12) / 2
                            : constraints.maxWidth;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final field in fields)
                                SizedBox(
                                  width: itemWidth,
                                  child: _EntryDetailCard(data: field),
                                ),
                              if (entry.notes.trim().isNotEmpty)
                                SizedBox(
                                  width: constraints.maxWidth,
                                  child: _NotesCard(notes: entry.notes),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1, color: talaBorder),
                  _EntryDetailActions(
                    onEdit: () => _edit(context),
                    onDelete: () => _delete(context),
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

class _EntryDetailData {
  const _EntryDetailData(this.label, this.value);

  final String label;
  final String value;
}

class _EntryDetailCard extends StatelessWidget {
  const _EntryDetailCard({required this.data});

  final _EntryDetailData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: talaPaper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: talaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            data.label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: talaInk.withValues(alpha: 0.64),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.value,
            softWrap: true,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: talaInk, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  const _NotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: talaPaper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: talaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Notes',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: talaInk.withValues(alpha: 0.64),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            notes,
            softWrap: true,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: talaInk, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _EntryDetailActions extends StatelessWidget {
  const _EntryDetailActions({
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final actions = [
            TextButton(onPressed: onEdit, child: const Text('Edit')),
            TextButton(onPressed: onDelete, child: const Text('Delete')),
            FilledButton(onPressed: onClose, child: const Text('Close')),
          ];
          return Wrap(
            alignment: constraints.maxWidth < 440
                ? WrapAlignment.center
                : WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: actions,
          );
        },
      ),
    );
  }
}
