import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/models/task.dart';
import 'package:academic_planner/models/timetable_entry.dart';
import 'package:academic_planner/pages/calendar_page.dart';
import 'package:academic_planner/pages/task_details_dialog.dart';
import 'package:academic_planner/pages/task_editor_dialog.dart';
import 'package:academic_planner/pages/timetable_event_details_dialog.dart';
import 'package:academic_planner/repositories/task_repository.dart';
import 'package:academic_planner/repositories/timetable_repository.dart';
import 'package:academic_planner/view_models/task_view_model.dart';
import 'package:academic_planner/view_models/timetable_view_model.dart';

Future<TaskViewModel> _loadedTaskViewModel(List<Task> tasks) async {
  final repository = InMemoryTaskRepository();
  final viewModel = TaskViewModel(taskRepository: repository);
  await viewModel.load();
  for (final task in tasks) {
    await viewModel.addTask(task);
  }
  return viewModel;
}

void main() {
  testWidgets('task details displays fields, scrolls, and toggles status', (
    tester,
  ) async {
    final today = DateTime.now();
    final task = Task(
      id: 'details',
      title: 'Read chapter',
      description: List.filled(30, 'Long description line').join('\n'),
      subject: 'Science Core',
      dueDate: today,
      priority: TaskPriority.high,
    );
    final viewModel = await _loadedTaskViewModel([task]);

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailsDialog(viewModel: viewModel, task: task),
      ),
    );

    expect(find.text('Read chapter'), findsOneWidget);
    expect(find.text('Science Core'), findsOneWidget);
    expect(find.textContaining('${today.month}/${today.day}/'), findsOneWidget);
    expect(find.text('high'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);

    await tester.tap(find.text('Mark complete'));
    await tester.pump();
    expect(viewModel.tasks.single.isCompleted, isTrue);
    expect(find.text('Mark incomplete'), findsOneWidget);
  });

  testWidgets('task details edit opens the existing editor', (tester) async {
    final task = Task(id: 'edit', title: 'Edit me');
    final viewModel = await _loadedTaskViewModel([task]);

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailsDialog(viewModel: viewModel, task: task),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskEditorDialog), findsOneWidget);
    expect(find.text('Edit task'), findsOneWidget);
  });

  testWidgets('task details delete uses the view model deletion flow', (
    tester,
  ) async {
    final task = Task(id: 'delete', title: 'Delete me');
    final viewModel = await _loadedTaskViewModel([task]);

    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailsDialog(viewModel: viewModel, task: task),
      ),
    );
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(viewModel.tasks, isEmpty);
  });

  testWidgets(
    'calendar task opens task details and count thresholds are colored',
    (tester) async {
      final today = DateTime.now();
      final tasks = List.generate(
        4,
        (index) => Task(
          id: 'calendar-$index',
          title: 'Calendar task $index',
          dueDate: today,
        ),
      );
      final viewModel = await _loadedTaskViewModel(tasks);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CalendarPage(viewModel: viewModel)),
        ),
      );

      final count = find.byKey(const ValueKey('calendar-task-count-4'));
      expect(count, findsOneWidget);
      expect(tester.widget<Text>(count).style?.color, Colors.red);
      await tester.ensureVisible(find.text('Calendar task 0'));
      await tester.tap(find.text('Calendar task 0'));
      await tester.pumpAndSettle();
      expect(find.text('Calendar task 0'), findsWidgets);
      expect(find.text('Mark complete'), findsOneWidget);
    },
  );

  testWidgets('calendar count thresholds retain numeric colors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            final primary = Theme.of(context).colorScheme.primary;
            expect(calendarTaskCountColor(context, 1), primary);
            expect(calendarTaskCountColor(context, 2), Colors.orange);
            expect(calendarTaskCountColor(context, 3), Colors.orange);
            expect(calendarTaskCountColor(context, 4), Colors.red);
            return const SizedBox();
          },
        ),
      ),
    );
  });

  testWidgets('timetable event details displays metadata and actions', (
    tester,
  ) async {
    const entry = TimetableEntry(
      id: 'event',
      title: 'Science lab',
      subject: 'Science Core',
      dayOfWeek: 1,
      startMinutes: 450,
      endMinutes: 500,
      entryType: TimetableEntryType.activity,
      room: 'Room 302',
      teacher: 'Teacher A',
      notes: 'Bring materials',
    );
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(initialEntries: [entry]),
    );
    await viewModel.load();

    await tester.pumpWidget(
      MaterialApp(
        home: TimetableEventDetailsDialog(
          viewModel: viewModel,
          entry: entry,
          activeSubjects: const ['Science Core'],
        ),
      ),
    );

    expect(find.text('Science lab'), findsOneWidget);
    expect(find.textContaining('Subject: Science Core'), findsOneWidget);
    expect(find.textContaining('Time: 7:30 AM – 8:20 AM'), findsOneWidget);
    expect(find.textContaining('Type: activity'), findsOneWidget);
    expect(find.textContaining('Room: Room 302'), findsOneWidget);
    expect(find.textContaining('Teacher: Teacher A'), findsOneWidget);
    expect(find.textContaining('Notes: Bring materials'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });
}
