import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  testWidgets('task details shows a compact no-description state', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final task = Task(id: 'no-description', title: 'Short task');
    final viewModel = await _loadedTaskViewModel([task]);
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailsDialog(viewModel: viewModel, task: task),
      ),
    );
    await tester.pumpAndSettle();

    final dialog = tester.getRect(
      find.byKey(const ValueKey('task-details-surface')),
    );
    expect(find.text('No description'), findsOneWidget);
    expect(find.text('No additional details.'), findsOneWidget);
    expect(dialog.height, lessThan(500));
    expect(dialog.width, lessThanOrEqualTo(960));
    expect(tester.takeException(), isNull);
  });

  testWidgets('task details shows the full description and scrolls on tablet', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final description = List.filled(
      90,
      'A complete stored description.',
    ).join('\n');
    final task = Task(
      id: 'long-description',
      title: 'Long task',
      description: description,
    );
    final viewModel = await _loadedTaskViewModel([task]);
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailsDialog(viewModel: viewModel, task: task),
      ),
    );
    await tester.pumpAndSettle();

    final dialog = tester.getRect(
      find.byKey(const ValueKey('task-details-surface')),
    );
    final descriptionText = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    final descriptionScrollable = find.descendant(
      of: find.byType(Scrollbar),
      matching: find.byType(Scrollable),
    );

    expect(find.text('Description'), findsOneWidget);
    expect(descriptionText.data, description);
    expect(descriptionScrollable, findsAtLeastNWidgets(1));
    expect(
      tester
          .state<ScrollableState>(descriptionScrollable.first)
          .position
          .maxScrollExtent,
      greaterThan(0),
    );
    expect(dialog.width, lessThanOrEqualTo(960));
    expect(dialog.height, lessThanOrEqualTo(760));
    expect(tester.takeException(), isNull);
  });

  testWidgets('task details keeps a short description compact', (tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const description = 'Bring the lab notebook.';
    final task = Task(
      id: 'short-description',
      title: 'Short detail task',
      description: description,
    );
    final viewModel = await _loadedTaskViewModel([task]);
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailsDialog(viewModel: viewModel, task: task),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Description'), findsOneWidget);
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      description,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('task-details-surface'))).height,
      lessThan(500),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('task details fits a narrow viewport and wraps its actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final task = Task(
      id: 'mobile-details',
      title: 'Mobile task',
      description: List.filled(90, 'A complete stored description.').join('\n'),
    );
    final viewModel = await _loadedTaskViewModel([task]);
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailsDialog(viewModel: viewModel, task: task),
      ),
    );
    await tester.pumpAndSettle();

    final dialog = tester.getRect(
      find.byKey(const ValueKey('task-details-surface')),
    );
    expect(dialog.left, greaterThanOrEqualTo(0));
    expect(dialog.top, greaterThanOrEqualTo(0));
    expect(dialog.right, lessThanOrEqualTo(390));
    expect(dialog.bottom, lessThanOrEqualTo(844));
    for (final label in ['Mark complete', 'Edit', 'Delete', 'Close']) {
      expect(find.text(label), findsOneWidget);
      final action = tester.getRect(find.text(label));
      expect(action.left, greaterThanOrEqualTo(0));
      expect(action.right, lessThanOrEqualTo(390));
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();
    expect(viewModel.tasks.single.isCompleted, isTrue);
    expect(find.text('Mark incomplete'), findsOneWidget);
  });

  testWidgets('task details fits representative portrait and landscape sizes', (
    tester,
  ) async {
    const viewports = [
      Size(320, 568),
      Size(360, 800),
      Size(390, 844),
      Size(600, 960),
      Size(800, 1280),
      Size(1280, 800),
      Size(844, 390),
    ];
    final viewModel = await _loadedTaskViewModel([]);

    for (var index = 0; index < viewports.length; index++) {
      final viewport = viewports[index];
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      final description = switch (index) {
        0 => '',
        1 => 'Short task details.',
        _ => List.filled(
          100,
          'Full task details remain available to read.',
        ).join('\n'),
      };
      final task = Task(
        id: 'viewport-$index',
        title: 'A responsive task title',
        description: description,
        subject: 'A subject name that can wrap on narrow screens',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: TaskDetailsDialog(viewModel: viewModel, task: task),
        ),
      );
      await tester.pumpAndSettle();

      final dialog = tester.getRect(
        find.byKey(const ValueKey('task-details-surface')),
      );
      expect(dialog.left, greaterThanOrEqualTo(0));
      expect(dialog.top, greaterThanOrEqualTo(0));
      expect(dialog.right, lessThanOrEqualTo(viewport.width));
      expect(dialog.bottom, lessThanOrEqualTo(viewport.height));
      for (final label in ['Edit', 'Delete', 'Close']) {
        expect(find.text(label), findsOneWidget);
        final actionRect = tester.getRect(find.text(label));
        expect(actionRect.left, greaterThanOrEqualTo(0));
        expect(actionRect.right, lessThanOrEqualTo(viewport.width));
        expect(actionRect.bottom, lessThanOrEqualTo(viewport.height));
      }
      expect(tester.takeException(), isNull, reason: 'viewport $viewport');
    }

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('completed task detail only shows a real completion timestamp', (
    tester,
  ) async {
    final viewModel = await _loadedTaskViewModel([]);
    final taskWithoutCompletionTime = Task(
      id: 'completed-without-time',
      title: 'Historical completed task',
      isCompleted: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailsDialog(
          viewModel: viewModel,
          task: taskWithoutCompletionTime,
        ),
      ),
    );
    expect(find.text('Completion date'), findsNothing);

    final completedAt = DateTime.utc(2026, 10, 3, 8, 15);
    final taskWithCompletionTime = taskWithoutCompletionTime.copyWith(
      completedAt: completedAt,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: TaskDetailsDialog(
          viewModel: viewModel,
          task: taskWithCompletionTime,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Completion date'), findsOneWidget);
    expect(find.textContaining('10/3/2026'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'with completedAt');
  });

  testWidgets(
    'task description limit applies to new input and preserves old data',
    (tester) async {
      final existingDescription = 'x' * 1001;
      final task = Task(
        id: 'over-limit',
        title: 'Existing task',
        description: existingDescription,
      );
      await tester.pumpWidget(MaterialApp(home: TaskEditorDialog(task: task)));

      final editDescriptionField = find.byType(TextField).at(1);
      expect(
        tester.widget<TextField>(editDescriptionField).controller!.text,
        existingDescription,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );

      await tester.pumpWidget(const MaterialApp(home: TaskEditorDialog()));
      final addDescriptionField = find.byType(TextField).at(1);
      final addDescriptionWidget = tester.widget<TextField>(
        addDescriptionField,
      );
      await tester.enterText(addDescriptionField, existingDescription);
      expect(addDescriptionWidget.maxLength, 1000);
      expect(
        addDescriptionWidget.inputFormatters!.any(
          (formatter) => formatter is LengthLimitingTextInputFormatter,
        ),
        isTrue,
      );
    },
  );

  testWidgets('task editor remains usable with a narrow keyboard inset', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);

    await tester.pumpWidget(const MaterialApp(home: TaskEditorDialog()));
    await tester.pumpAndSettle();

    expect(find.byType(TaskEditorDialog), findsOneWidget);
    expect(find.text('Create task'), findsOneWidget);
    expect(find.text('0 / 1000'), findsOneWidget);
    final descriptionField = find.byType(TextField).at(1);
    await tester.enterText(descriptionField, 'x' * 37);
    await tester.pump();
    expect(find.text('37 / 1000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
    expect(find.byType(SingleChildScrollView), findsAtLeastNWidgets(1));

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
    expect(find.text('Subject'), findsOneWidget);
    expect(find.text('Science Core'), findsWidgets);
    expect(find.text('Day'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Time'), findsOneWidget);
    expect(find.text('7:30 AM – 8:20 AM'), findsOneWidget);
    expect(find.text('Type'), findsOneWidget);
    expect(find.text('activity'), findsOneWidget);
    expect(find.text('Room'), findsOneWidget);
    expect(find.text('Room 302'), findsOneWidget);
    expect(find.text('Teacher'), findsOneWidget);
    expect(find.text('Teacher A'), findsOneWidget);
    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('Bring materials'), findsOneWidget);
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('timetable-entry-details-surface')),
          )
          .height,
      lessThan(600),
    );
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
  });

  testWidgets(
    'timetable entry details fits phone, tablet, and landscape sizes',
    (tester) async {
      const viewports = [
        Size(320, 568),
        Size(360, 800),
        Size(390, 844),
        Size(600, 960),
        Size(800, 1280),
        Size(1280, 800),
        Size(844, 390),
      ];
      final entry = TimetableEntry(
        id: 'responsive-entry',
        title: 'A long timetable entry title that wraps naturally',
        subject: 'A very long academic subject name that should wrap',
        dayOfWeek: 1,
        startMinutes: 450,
        endMinutes: 500,
        entryType: TimetableEntryType.activity,
        teacher: 'Teacher A',
        room: 'Room 302',
        notes: List.filled(25, 'Complete notes remain readable.').join(' '),
      );
      final viewModel = TimetableViewModel(
        repository: InMemoryTimetableRepository(initialEntries: [entry]),
      );
      await viewModel.load();

      for (final viewport in viewports) {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: TimetableEventDetailsDialog(
              viewModel: viewModel,
              entry: entry,
              activeSubjects: const [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        final dialog = tester.getRect(
          find.byKey(const ValueKey('timetable-entry-details-surface')),
        );
        expect(dialog.left, greaterThanOrEqualTo(0));
        expect(dialog.top, greaterThanOrEqualTo(0));
        expect(dialog.right, lessThanOrEqualTo(viewport.width));
        expect(dialog.bottom, lessThanOrEqualTo(viewport.height));
        expect(find.text('Monday'), findsOneWidget);
        expect(find.text('7:30 AM – 8:20 AM'), findsOneWidget);
        for (final label in ['Edit', 'Delete', 'Close']) {
          expect(find.text(label), findsOneWidget);
          final actionRect = tester.getRect(find.text(label));
          expect(actionRect.left, greaterThanOrEqualTo(0));
          expect(actionRect.right, lessThanOrEqualTo(viewport.width));
          expect(actionRect.bottom, lessThanOrEqualTo(viewport.height));
        }
        expect(tester.takeException(), isNull);
      }

      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    },
  );
}
