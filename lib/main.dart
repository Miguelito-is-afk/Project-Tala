import 'package:flutter/material.dart';

import 'dart:async';

import 'pages/calendar_page.dart';
import 'pages/settings_page.dart';
import 'pages/subjects_page.dart';
import 'pages/tasks_page.dart';
import 'pages/task_details_dialog.dart';
import 'pages/timetable_page.dart';
import 'app/home_dashboard.dart';
import 'models/timetable_entry.dart';
import 'repositories/task_repository.dart';
import 'repositories/timetable_repository.dart';
import 'services/timetable_notification_service.dart';
import 'services/timetable_reminder_settings.dart';
import 'view_models/task_view_model.dart';
import 'view_models/timetable_view_model.dart';

import 'package:flutter/foundation.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const AcademicPlannerApp());
}

TaskRepository createTaskRepository() {
  if (kIsWeb) {
    return InMemoryTaskRepository();
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return SqliteTaskRepository();

    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return InMemoryTaskRepository();
  }
}

TimetableRepository createTimetableRepository() {
  if (kIsWeb) {
    return InMemoryTimetableRepository();
  }

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return SqliteTimetableRepository();

    case TargetPlatform.windows:
    case TargetPlatform.linux:
    case TargetPlatform.fuchsia:
      return InMemoryTimetableRepository();
  }
}

class AcademicPlannerApp extends StatelessWidget {
  const AcademicPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tala',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({
    this.taskRepository,
    this.timetableRepository,
    this.notificationService,
    this.settingsStore,
    super.key,
  });

  final TaskRepository? taskRepository;
  final TimetableRepository? timetableRepository;
  final TimetableNotificationService? notificationService;
  final TimetableReminderSettingsStore? settingsStore;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  late final TaskViewModel _taskViewModel;
  late final TimetableViewModel _timetableViewModel;
  late final TimetableNotificationService _notificationService;
  late final TimetableReminderSettingsStore _settingsStore;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _notificationService =
        widget.notificationService ?? LocalTimetableNotificationService();
    _settingsStore =
        widget.settingsStore ??
        SharedPreferencesTimetableReminderSettingsStore();
    _timetableViewModel = TimetableViewModel(
      repository: widget.timetableRepository ?? createTimetableRepository(),
      notificationService: _notificationService,
    );
    _taskViewModel = TaskViewModel(
      taskRepository: widget.taskRepository ?? createTaskRepository(),
      onSubjectRenamed: _timetableViewModel.load,
    );

    unawaited(_initializeTasks());
    unawaited(_initializeTimetable());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taskViewModel.dispose();
    _timetableViewModel.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_taskViewModel.load());
    }
  }

  static const destinations = [
    _Destination(
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Home',
    ),
    _Destination(
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      label: 'Tasks',
    ),
    _Destination(
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: 'Calendar',
    ),
    _Destination(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
      label: 'Subjects',
    ),
    _Destination(
      icon: Icons.view_week_outlined,
      selectedIcon: Icons.view_week,
      label: 'Timetable',
    ),
    _Destination(
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 600) {
          return _buildMobileLayout();
        }

        if (width < 1000) {
          return _buildTabletLayout(extended: false);
        }

        return _buildTabletLayout(extended: true);
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: destinations.map((destination) {
          return NavigationDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: destination.label,
          );
        }).toList(),
      ),
      floatingActionButton: _selectedIndex <= 1
          ? FloatingActionButton(
              onPressed: _addTask,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildTabletLayout({required bool extended}) {
    return Scaffold(
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              extended: extended,
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: _AppLogo(extended: extended),
              ),
              destinations: destinations.map((destination) {
                return NavigationRailDestination(
                  icon: Icon(destination.icon),
                  selectedIcon: Icon(destination.selectedIcon),
                  label: Text(destination.label),
                );
              }).toList(),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Scaffold(
              body: _buildPage(),
              floatingActionButton: _selectedIndex <= 1
                  ? FloatingActionButton.extended(
                      onPressed: _addTask,
                      icon: const Icon(Icons.add),
                      label: const Text('Add task'),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return HomePage(
          viewModel: _taskViewModel,
          timetableViewModel: _timetableViewModel,
          onAddTask: _addTask,
          onNavigate: _onDestinationSelected,
        );
      case 1:
        return TasksPage(viewModel: _taskViewModel);
      case 2:
        return CalendarPage(viewModel: _taskViewModel);
      case 3:
        return SubjectsPage(
          viewModel: _taskViewModel,
          onSubjectSelected: (subject) {
            _taskViewModel.setSubjectFilter(subject);
            _onDestinationSelected(1);
          },
        );
      case 4:
        return TimetablePage(
          viewModel: _timetableViewModel,
          activeSubjects: _taskViewModel.availableSubjects,
        );
      case 5:
        return SettingsPage(
          viewModel: _timetableViewModel,
          taskViewModel: _taskViewModel,
          settingsStore: _settingsStore,
        );
      default:
        return HomePage(
          viewModel: _taskViewModel,
          timetableViewModel: _timetableViewModel,
          onAddTask: _addTask,
          onNavigate: _onDestinationSelected,
        );
    }
  }

  Future<void> _initializeTasks() async {
    try {
      final settings = await _settingsStore.load();
      _taskViewModel.setCompletedTaskCleanupPolicy(
        settings.completedTaskCleanupPolicy,
      );
    } catch (error) {
      debugPrint('Unable to restore completed task cleanup setting: $error');
    }
    await _taskViewModel.load();
  }

  Future<void> _initializeTimetable() async {
    await _timetableViewModel.load();
    try {
      final settings = await _settingsStore.load();
      await _timetableViewModel.setReminderSettings(
        enabled: settings.enabled,
        offsetMinutes: settings.offsetMinutes,
      );
    } catch (error) {
      // Settings loading must not prevent the timetable from appearing.
      debugPrint('Unable to restore timetable reminder settings: $error');
    }
    try {
      await _notificationService.initialize();
    } catch (error) {
      debugPrint('Unable to initialize timetable notifications: $error');
    }
  }

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _addTask() async {
    final task = await showTaskEditorDialog(
      context,
      subjects: _taskViewModel.availableSubjects,
    );

    if (task == null || !mounted) {
      return;
    }

    await _taskViewModel.addTask(task);
  }
}

class HomePage extends StatefulWidget {
  const HomePage({
    required this.viewModel,
    required this.timetableViewModel,
    required this.onAddTask,
    required this.onNavigate,
    super.key,
  });

  final TaskViewModel viewModel;
  final TimetableViewModel timetableViewModel;
  final Future<void> Function() onAddTask;
  final ValueChanged<int> onNavigate;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        widget.viewModel,
        widget.timetableViewModel,
      ]),
      builder: (context, _) {
        final now = DateTime.now();
        final happening = currentTimetableEvents(
          widget.timetableViewModel.entries,
          now: now,
        );
        final nextClasses = nextSubjectClasses(
          widget.timetableViewModel.entries,
          now: now,
        );
        final todayTasks = tasksDueToday(widget.viewModel.tasks, now: now);
        final overdue = overdueTaskCount(widget.viewModel.tasks, now: now);
        final nextSevenDays = openTasksDueWithinNextSevenDays(
          widget.viewModel.tasks,
          now: now,
        );
        final workload = subjectWorkload(widget.viewModel.tasks, now: now);
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Tala',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Academic Planner',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(width: 8),
                        const Chip(
                          label: Text('BETA'),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Good day 👋',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Here is what is happening with your academics.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 32),

                    _SectionHeading(title: 'Happening now'),
                    const SizedBox(height: 12),
                    if (happening.isEmpty)
                      const _DashboardEmptyState(
                        text: 'Nothing scheduled right now',
                      )
                    else
                      ...happening.map(
                        (entry) => _HappeningCard(entry: entry, now: now),
                      ),

                    const SizedBox(height: 32),
                    _SectionHeading(title: "Today's tasks"),
                    const SizedBox(height: 12),
                    if (todayTasks.isEmpty)
                      _buildTodayEmptyState(context)
                    else
                      ...todayTasks
                          .take(5)
                          .map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: TaskCard(
                                task: task,
                                onToggle: () =>
                                    widget.viewModel.toggleTask(task.id),
                                onTap: () => showDialog(
                                  context: context,
                                  builder: (_) => TaskDetailsDialog(
                                    viewModel: widget.viewModel,
                                    task: task,
                                  ),
                                ),
                              ),
                            ),
                          ),
                    if (todayTasks.length > 5)
                      TextButton(
                        onPressed: () => widget.onNavigate(1),
                        child: const Text('View all tasks'),
                      ),

                    const SizedBox(height: 32),
                    _SectionHeading(title: 'Next classes'),
                    const SizedBox(height: 12),
                    if (nextClasses.isEmpty)
                      const _DashboardEmptyState(text: 'No upcoming classes')
                    else
                      ...nextClasses.map(
                        (entry) => _ClassCard(
                          entry: entry,
                          showDay: entry.dayOfWeek != now.weekday,
                        ),
                      ),

                    const SizedBox(height: 32),
                    _SectionHeading(title: 'Academic overview'),
                    const SizedBox(height: 12),
                    _AcademicOverview(
                      openTasks: widget.viewModel.incompleteTaskCount,
                      dueToday: todayTasks.length,
                      overdue: overdue,
                      nextSevenDays: nextSevenDays,
                      workload: workload,
                    ),

                    const SizedBox(height: 32),

                    LayoutBuilder(
                      builder: (context, constraints) {
                        final cardWidth = constraints.maxWidth >= 800
                            ? (constraints.maxWidth - 32) / 3
                            : constraints.maxWidth;

                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _SummaryCard(
                                title: 'Open',
                                value:
                                    '${widget.viewModel.incompleteTaskCount}',
                                subtitle: 'tasks',
                                icon: Icons.today,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _SummaryCard(
                                title: 'Due today',
                                value: '${todayTasks.length}',
                                subtitle: 'tasks',
                                icon: Icons.upcoming,
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _SummaryCard(
                                title: 'Overdue',
                                value: '$overdue',
                                subtitle: 'open tasks',
                                icon: Icons.warning_amber,
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    Text(
                      'Quick actions',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: widget.onAddTask,
                          icon: const Icon(Icons.add_task),
                          label: const Text('Add task'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => widget.onNavigate(2),
                          icon: const Icon(Icons.calendar_month),
                          label: const Text('View calendar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => widget.onNavigate(3),
                          icon: const Icon(Icons.menu_book),
                          label: const Text('Subjects'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTodayEmptyState(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.event_available,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No tasks due today',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Your assignments and deadlines for today will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(text),
          ],
        ),
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.entry, this.showDay = false});

  final TimetableEntry entry;
  final bool showDay;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.school_outlined),
        title: Text(entry.subject!),
        subtitle: Text(
          '${_dayLabel(entry.dayOfWeek, showDay)}'
          '${showDay ? ' · ' : ''}${_formatTime(entry.startMinutes)} – '
          '${_formatTime(entry.endMinutes)}',
        ),
      ),
    );
  }

  static String _dayLabel(int day, bool visible) {
    if (!visible) return '';
    return const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ][day - 1];
  }

  static String _formatTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final displayHour = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;
    return '$displayHour:${minute.toString().padLeft(2, '0')} '
        '${hour >= 12 ? 'PM' : 'AM'}';
  }
}

class _HappeningCard extends StatelessWidget {
  const _HappeningCard({required this.entry, required this.now});

  final TimetableEntry entry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (entry.room?.trim().isNotEmpty == true) 'Room: ${entry.room}',
      if (entry.teacher?.trim().isNotEmpty == true) 'Teacher: ${entry.teacher}',
      if (entry.notes.trim().isNotEmpty) entry.notes,
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (entry.subject?.trim().isNotEmpty == true)
              Text(
                entry.subject!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 4),
            Text(
              '${_format(entry.startMinutes)} – ${_format(entry.endMinutes)}',
            ),
            const SizedBox(height: 4),
            Text(timetableMinutesRemaining(entry, now: now)),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: timetableEventProgress(entry, now: now),
            ),
            if (metadata.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...metadata.map(Text.new),
            ],
          ],
        ),
      ),
    );
  }

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

class _AcademicOverview extends StatelessWidget {
  const _AcademicOverview({
    required this.openTasks,
    required this.dueToday,
    required this.overdue,
    required this.nextSevenDays,
    required this.workload,
  });

  final int openTasks;
  final int dueToday;
  final int overdue;
  final int nextSevenDays;
  final Map<String, int> workload;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                _Metric(label: 'Open tasks', value: openTasks),
                _Metric(label: 'Due today', value: dueToday),
                _Metric(label: 'Overdue', value: overdue),
                _Metric(label: 'Next 7 days', value: nextSevenDays),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Subject workload',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (workload.isEmpty)
              const Text('Not enough data yet')
            else
              ...workload.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(entry.key)),
                      Text('${entry.value}'),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('This section will be built next.'),
          ],
        ),
      ),
    );
  }
}

class _AppLogo extends StatelessWidget {
  const _AppLogo({required this.extended});

  final bool extended;

  @override
  Widget build(BuildContext context) {
    if (!extended) {
      return Icon(
        Icons.school,
        color: Theme.of(context).colorScheme.primary,
        size: 28,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.school,
          color: Theme.of(context).colorScheme.primary,
          size: 28,
        ),
        const SizedBox(width: 12),
        Text(
          'Tala',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _Destination {
  const _Destination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
