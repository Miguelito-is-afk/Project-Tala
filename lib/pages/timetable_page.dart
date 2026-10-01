import 'package:flutter/material.dart';

import '../models/timetable_entry.dart';
import '../pages/timetable_entry_editor_dialog.dart';
import '../pages/timetable_event_details_dialog.dart';
import '../view_models/timetable_view_model.dart';

const timetablePixelsPerMinute = 2.4;
const timetableDayHeaderHeight = 56.0;
const timetableHeaderTimelineSpacing = 8.0;
const timetableEntryHorizontalGap = 4.0;
const timetableEntryCardRadius = 6.0;
const timetableWeekdayHeaderRadius = 8.0;

double timetableVerticalOffset({
  required int minutes,
  required int timelineStart,
}) {
  return (minutes - timelineStart) * timetablePixelsPerMinute;
}

double timetableDurationHeight(int durationMinutes) {
  return durationMinutes * timetablePixelsPerMinute;
}

List<int> timetableRulerMinutes({
  required int timelineStart,
  required int timelineEnd,
}) {
  final start = (timelineStart ~/ 30) * 30;
  final end = ((timelineEnd + 29) ~/ 30) * 30;
  return [
    for (var minutes = start; minutes <= end; minutes += 30)
      if (minutes >= timelineStart && minutes <= timelineEnd) minutes,
  ];
}

class TimetableTimelineBounds {
  const TimetableTimelineBounds({required this.start, required this.end});

  final int start;
  final int end;
}

TimetableTimelineBounds timetableTimelineBounds(List<TimetableEntry> entries) {
  var start = 6 * 60;
  var end = 22 * 60;
  for (final entry in entries) {
    if (entry.startMinutes < start) start = entry.startMinutes;
    if (entry.endMinutes > end) end = entry.endMinutes;
  }
  return TimetableTimelineBounds(start: start, end: end);
}

class TimetablePage extends StatelessWidget {
  const TimetablePage({
    required this.viewModel,
    this.activeSubjects = const [],
    super.key,
  });

  final TimetableViewModel viewModel;
  final List<String> activeSubjects;

  static const _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) {
          if (viewModel.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (viewModel.loadErrorMessage != null) {
            return Center(child: Text('Unable to load timetable.'));
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final entries = viewModel.entries
                  .where((entry) => entry.dayOfWeek <= 5)
                  .toList();
              final bounds = timetableTimelineBounds(entries);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1500),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Timetable',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your weekly schedule at a glance.',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 20),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => _openEditor(context),
                            icon: const Icon(Icons.add),
                            label: const Text('Add entry'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (constraints.maxWidth < 800)
                          _buildNarrow(context, bounds)
                        else
                          _buildWide(context, bounds),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildNarrow(BuildContext context, TimetableTimelineBounds bounds) {
    final weekday = viewModel.selectedWeekday.clamp(1, 5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: weekday,
                decoration: const InputDecoration(
                  labelText: 'Day',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (var index = 1; index <= 5; index++)
                    DropdownMenuItem(
                      value: index,
                      child: Text(_weekdayNames[index - 1]),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    viewModel.selectWeekday(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: viewModel.selectToday,
              child: const Text('Today'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DayColumn(
          weekday: weekday,
          label: _weekdayNames[weekday - 1],
          entries: viewModel.entriesForWeekday(weekday),
          bounds: bounds,
          isCurrent: weekday == DateTime.now().weekday,
          onEntryTap: (entry) => _openDetails(context, entry),
        ),
      ],
    );
  }

  Widget _buildWide(BuildContext context, TimetableTimelineBounds bounds) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 58, child: _TimeRuler(bounds: bounds)),
        const SizedBox(width: 8),
        for (var weekday = 1; weekday <= 5; weekday++) ...[
          Expanded(
            child: _DayColumn(
              weekday: weekday,
              label: _weekdayNames[weekday - 1],
              entries: viewModel.entriesForWeekday(weekday),
              bounds: bounds,
              isCurrent: weekday == DateTime.now().weekday,
              onEntryTap: (entry) => _openDetails(context, entry),
            ),
          ),
          if (weekday < 5) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Future<void> _openEditor(
    BuildContext context, [
    TimetableEntry? entry,
  ]) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => TimetableEntryEditorDialog(
        viewModel: viewModel,
        activeSubjects: activeSubjects,
        entry: entry,
      ),
    );
  }

  Future<void> _openDetails(BuildContext context, TimetableEntry entry) async {
    await showDialog<bool>(
      context: context,
      builder: (context) => TimetableEventDetailsDialog(
        viewModel: viewModel,
        activeSubjects: activeSubjects,
        entry: entry,
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.weekday,
    required this.label,
    required this.entries,
    required this.bounds,
    required this.onEntryTap,
    this.isCurrent = false,
  });

  final int weekday;
  final String label;
  final List<TimetableEntry> entries;
  final TimetableTimelineBounds bounds;
  final ValueChanged<TimetableEntry> onEntryTap;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final timelineHeight = timetableDurationHeight(bounds.end - bounds.start);
    final placedEntries = placeTimetableEntries(entries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: timetableDayHeaderHeight,
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(timetableWeekdayHeaderRadius),
            ),
            color: isCurrent
                ? Theme.of(context).colorScheme.primaryContainer
                : null,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: timetableHeaderTimelineSpacing),
        SizedBox(
          height: timelineHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(timetableWeekdayHeaderRadius),
            ),
            child: Stack(
              children: [
                for (final minutes in timetableRulerMinutes(
                  timelineStart: bounds.start,
                  timelineEnd: bounds.end,
                ))
                  Positioned(
                    top: timetableVerticalOffset(
                      minutes: minutes,
                      timelineStart: bounds.start,
                    ),
                    left: 0,
                    right: 0,
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Theme.of(context).dividerColor.withAlpha(90),
                    ),
                  ),
                for (final placedEntry in placedEntries)
                  Positioned(
                    top: timetableVerticalOffset(
                      minutes: placedEntry.entry.startMinutes,
                      timelineStart: bounds.start,
                    ),
                    left: 4,
                    right: 4,
                    height: timetableDurationHeight(
                      placedEntry.entry.endMinutes -
                          placedEntry.entry.startMinutes,
                    ),
                    child: _EntryLane(
                      placedEntry: placedEntry,
                      onTap: onEntryTap,
                    ),
                  ),
                if (entries.isEmpty) const Center(child: Text('No entries')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class TimetableEntryPlacement {
  const TimetableEntryPlacement({
    required this.entry,
    required this.lane,
    required this.laneCount,
  });

  final TimetableEntry entry;
  final int lane;
  final int laneCount;
}

class _EntryLane extends StatelessWidget {
  const _EntryLane({required this.placedEntry, required this.onTap});

  final TimetableEntryPlacement placedEntry;
  final ValueChanged<TimetableEntry> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalGap =
            timetableEntryHorizontalGap * (placedEntry.laneCount - 1);
        final laneWidth =
            (constraints.maxWidth - totalGap) / placedEntry.laneCount;
        return Row(
          children: [
            SizedBox(width: laneWidth * placedEntry.lane),
            SizedBox(
              width: laneWidth,
              child: _EntryBlock(entry: placedEntry.entry, onTap: onTap),
            ),
            if (placedEntry.lane < placedEntry.laneCount - 1)
              const SizedBox(width: timetableEntryHorizontalGap),
            SizedBox(
              width: laneWidth * (placedEntry.laneCount - placedEntry.lane - 1),
            ),
          ],
        );
      },
    );
  }
}

List<TimetableEntryPlacement> placeTimetableEntries(
  List<TimetableEntry> entries,
) {
  final sortedEntries = [...entries]
    ..sort((first, second) {
      final startComparison = first.startMinutes.compareTo(second.startMinutes);
      return startComparison == 0
          ? first.endMinutes.compareTo(second.endMinutes)
          : startComparison;
    });
  final placements = <TimetableEntryPlacement>[];
  var clusterStart = 0;

  while (clusterStart < sortedEntries.length) {
    var clusterEnd = clusterStart + 1;
    var clusterEndMinutes = sortedEntries[clusterStart].endMinutes;
    while (clusterEnd < sortedEntries.length &&
        sortedEntries[clusterEnd].startMinutes < clusterEndMinutes) {
      clusterEndMinutes =
          clusterEndMinutes > sortedEntries[clusterEnd].endMinutes
          ? clusterEndMinutes
          : sortedEntries[clusterEnd].endMinutes;
      clusterEnd++;
    }

    final laneEndTimes = <int>[];
    for (final entry in sortedEntries.sublist(clusterStart, clusterEnd)) {
      var lane = laneEndTimes.indexWhere(
        (laneEnd) => laneEnd <= entry.startMinutes,
      );
      if (lane == -1) {
        lane = laneEndTimes.length;
        laneEndTimes.add(entry.endMinutes);
      } else {
        laneEndTimes[lane] = entry.endMinutes;
      }
      placements.add(
        TimetableEntryPlacement(
          entry: entry,
          lane: lane,
          laneCount: laneEndTimes.length,
        ),
      );
    }

    final clusterLaneCount = laneEndTimes.length;
    for (
      var index = placements.length - (clusterEnd - clusterStart);
      index < placements.length;
      index++
    ) {
      final placement = placements[index];
      placements[index] = TimetableEntryPlacement(
        entry: placement.entry,
        lane: placement.lane,
        laneCount: clusterLaneCount,
      );
    }
    clusterStart = clusterEnd;
  }

  return placements;
}

class _TimeRuler extends StatelessWidget {
  const _TimeRuler({required this.bounds});

  final TimetableTimelineBounds bounds;

  @override
  Widget build(BuildContext context) {
    final timelineHeight = timetableDurationHeight(bounds.end - bounds.start);

    return Column(
      children: [
        const SizedBox(height: timetableDayHeaderHeight),
        const SizedBox(height: timetableHeaderTimelineSpacing),
        SizedBox(
          height: timelineHeight,
          child: Stack(
            children: [
              for (final minutes in timetableRulerMinutes(
                timelineStart: bounds.start,
                timelineEnd: bounds.end,
              ))
                Positioned(
                  top: timetableVerticalOffset(
                    minutes: minutes,
                    timelineStart: bounds.start,
                  ),
                  left: 0,
                  right: 0,
                  child: Text(
                    _formatRulerMinutes(minutes),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatRulerMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    final suffix = hour < 12 ? 'AM' : 'PM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

class _EntryBlock extends StatelessWidget {
  const _EntryBlock({required this.entry, required this.onTap});

  final TimetableEntry entry;
  final ValueChanged<TimetableEntry> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (entry.entryType) {
      TimetableEntryType.breakTime => colors.surfaceContainerHighest,
      TimetableEntryType.consultation => colors.secondaryContainer,
      TimetableEntryType.activity => colors.tertiaryContainer,
      _ => colors.primaryContainer,
    };

    return GestureDetector(
      onTap: () => onTap(entry),
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.hardEdge,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(timetableEntryCardRadius),
        ),
        color: color,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                top: 6,
                left: 6,
                right: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 3,
                      overflow: TextOverflow.clip,
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${_formatMinutes(entry.startMinutes)}–'
                      '${_formatMinutes(entry.endMinutes)}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (entry.subject != null)
                      Text(
                        entry.subject!,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatMinutes(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    final suffix = hour < 12 ? 'AM' : 'PM';
    return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
  }
}
