import 'package:flutter/material.dart';

import '../app/branding.dart';
import '../app/motion.dart';
import '../models/task.dart';
import '../view_models/task_view_model.dart';
import 'tasks_page.dart';
import 'task_details_dialog.dart';

DateTime calendarSelectionForMonth(
  DateTime displayedMonth,
  DateTime selectedDate,
  int monthDelta,
) {
  final targetMonth = DateTime(
    displayedMonth.year,
    displayedMonth.month + monthDelta,
  );
  final lastDay = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
  final selectedDay = selectedDate.day > lastDay ? lastDay : selectedDate.day;

  return DateTime(targetMonth.year, targetMonth.month, selectedDay);
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({required this.viewModel, super.key});

  final TaskViewModel viewModel;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

Color calendarTaskCountColor(BuildContext context, int taskCount) {
  final colorScheme = Theme.of(context).colorScheme;
  return taskCount >= 4
      ? Colors.red
      : taskCount >= 2
      ? Colors.orange
      : colorScheme.primary;
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _selectedDate;
  late DateTime _displayedMonth;

  TaskViewModel get viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();

    final today = DateTime.now();
    _selectedDate = DateTime(today.year, today.month, today.day);
    _displayedMonth = DateTime(today.year, today.month);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) {
          final selectedTasks = viewModel.tasksDueOn(_selectedDate);

          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 1000
                  ? 48.0
                  : 24.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 24),
                        _buildCalendar(context),
                        const SizedBox(height: 24),
                        _buildSelectedDay(context, selectedTasks),
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

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calendar',
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold, color: talaInk),
              ),
              const SizedBox(height: 4),
              Text(
                'Academic plan overview',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: talaInk.withValues(alpha: 0.72)),
              ),
            ],
          ),
        ),
        FilledButton.tonal(onPressed: _goToToday, child: const Text('Today')),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final days = _calendarDays(_displayedMonth);
    final monthLabel = _monthLabel(_displayedMonth);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: talaSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: talaBorder),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: talaSky,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left, color: talaBlue),
                ),
                Expanded(
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold, color: talaInk),
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right, color: talaBlue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: _weekdayLabels.map((label) {
              return Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: talaInk.withValues(alpha: 0.68),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final childAspectRatio = constraints.maxWidth < 250
                  ? 0.72
                  : constraints.maxWidth < 320
                  ? 0.9
                  : 1.05;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: days.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: childAspectRatio,
                ),
                itemBuilder: (context, index) {
                  return _buildDayCell(context, days[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(BuildContext context, DateTime date) {
    final isCurrentMonth =
        date.month == _displayedMonth.month &&
        date.year == _displayedMonth.year;
    final isSelected = _isSameDay(date, _selectedDate);
    final isToday = _isSameDay(date, DateTime.now());
    final taskCount = viewModel.tasksDueOn(date).length;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() {
          _selectedDate = date;
          _displayedMonth = DateTime(date.year, date.month);
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: AnimatedContainer(
          duration: accessibleMotionDuration(context),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected ? talaSky : null,
            border: Border.all(
              color: isToday ? talaBlue : Colors.transparent,
              width: isToday ? 1.5 : 0,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedDefaultTextStyle(
                duration: accessibleMotionDuration(context),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  color: isCurrentMonth
                      ? isSelected
                            ? talaBlue
                            : talaInk
                      : talaInk.withValues(alpha: 0.35),
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.w600,
                ),
                child: Text('${date.day}'),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 18,
                child: taskCount == 0
                    ? null
                    : AnimatedValueText(
                        '$taskCount',
                        valueKey: ValueKey('calendar-task-count-$taskCount'),
                        style: TextStyle(
                          color: calendarTaskCountColor(context, taskCount),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDay(BuildContext context, List<Task> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: talaSky,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _selectedDayLabel(),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: talaBlue),
          ),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: talaSurface,
              border: Border.all(color: talaBorder),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Center(
              child: Text(
                'No tasks due on this day.',
                style: Theme.of(context).textTheme.bodyLarge
                    ?.copyWith(color: talaInk.withValues(alpha: 0.72)),
              ),
            ),
          )
        else
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TaskCard(
                task: task,
                onToggle: () => viewModel.toggleTask(task.id),
                onTap: () => showDialog(
                  context: context,
                  builder: (_) =>
                      TaskDetailsDialog(viewModel: viewModel, task: task),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _previousMonth() {
    setState(() {
      _selectedDate = calendarSelectionForMonth(
        _displayedMonth,
        _selectedDate,
        -1,
      );
      _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    });
  }

  void _nextMonth() {
    setState(() {
      _selectedDate = calendarSelectionForMonth(
        _displayedMonth,
        _selectedDate,
        1,
      );
      _displayedMonth = DateTime(_selectedDate.year, _selectedDate.month);
    });
  }

  void _goToToday() {
    final today = DateTime.now();

    setState(() {
      _selectedDate = DateTime(today.year, today.month, today.day);
      _displayedMonth = DateTime(today.year, today.month);
    });
  }

  List<DateTime> _calendarDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month);
    final leadingDays = firstDay.weekday - DateTime.monday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalDays = leadingDays + daysInMonth;
    final gridDays = totalDays + (7 - totalDays % 7) % 7;

    return List.generate(
      gridDays,
      (index) => firstDay.add(Duration(days: index - leadingDays)),
    );
  }

  String _monthLabel(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.year}';
  }

  String _selectedDayLabel() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[_selectedDate.month - 1]} ${_selectedDate.day}, '
        '${_selectedDate.year}';
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  static const _weekdayLabels = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
}
