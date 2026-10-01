import 'package:flutter/material.dart';

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
          child: Text(
            'Calendar',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        OutlinedButton(onPressed: _goToToday, child: const Text('Today')),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final days = _calendarDays(_displayedMonth);
    final monthLabel = _monthLabel(_displayedMonth);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _previousMonth,
                  tooltip: 'Previous month',
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  tooltip: 'Next month',
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: _weekdayLabels.map((label) {
                return Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: days.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                return _buildDayCell(context, days[index]);
              },
            ),
          ],
        ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        setState(() {
          _selectedDate = date;
          _displayedMonth = DateTime(date.year, date.month);
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : null,
            border: isToday
                ? Border.all(color: colorScheme.primary, width: 1.5)
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${date.day}',
                style: TextStyle(
                  color: isCurrentMonth
                      ? colorScheme.onSurface
                      : colorScheme.onSurface.withValues(alpha: 0.35),
                  fontWeight: isSelected || isToday
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 18,
                child: taskCount == 0
                    ? null
                    : Text(
                        '$taskCount',
                        key: ValueKey('calendar-task-count-$taskCount'),
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
        Text(
          _selectedDayLabel(),
          style: Theme.of(context).textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No tasks due on this day.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
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
