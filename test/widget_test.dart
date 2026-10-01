import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/main.dart';
import 'package:academic_planner/models/task.dart';
import 'package:academic_planner/pages/subjects_page.dart';
import 'package:academic_planner/pages/task_details_dialog.dart';
import 'package:academic_planner/repositories/task_repository.dart';
import 'package:academic_planner/services/completed_task_cleanup.dart';
import 'package:academic_planner/view_models/task_view_model.dart';

void main() {
  testWidgets('Project Tala loads successfully with the version label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AcademicPlannerApp());
    await tester.pumpAndSettle();

    expect(find.text('Good day 👋'), findsOneWidget);
    expect(find.text('Project Tala'), findsWidgets);
    expect(find.text('Academic Planner'), findsOneWidget);
    expect(find.text('v0.6.1'), findsOneWidget);
    expect(find.text("Today's tasks"), findsOneWidget);
  });

  testWidgets('adding a subject closes its dialog without controller errors', (
    WidgetTester tester,
  ) async {
    final viewModel = TaskViewModel(taskRepository: InMemoryTaskRepository());
    await viewModel.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubjectsPage(viewModel: viewModel, onSubjectSelected: (_) {}),
        ),
      ),
    );

    await tester.tap(find.text('Add subject'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Economics');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(viewModel.availableSubjects, contains('Economics'));
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Subject name'), findsNothing);
  });

  testWidgets('active subjects expose an edit action and rename dialog', (
    WidgetTester tester,
  ) async {
    final viewModel = TaskViewModel(taskRepository: InMemoryTaskRepository());
    await viewModel.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubjectsPage(viewModel: viewModel, onSubjectSelected: (_) {}),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Subject options').first);
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit subject'), findsOneWidget);
    expect(find.text('Mathematics 5 Level 1'), findsNWidgets(2));
  });

  testWidgets('archived-subject deletion requires confirmation', (
    WidgetTester tester,
  ) async {
    final viewModel = TaskViewModel(taskRepository: InMemoryTaskRepository());
    await viewModel.load();
    await viewModel.addSubject('Unused Archived');
    await viewModel.archiveSubject('Unused Archived');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubjectsPage(viewModel: viewModel, onSubjectSelected: (_) {}),
        ),
      ),
    );

    await tester.tap(find.textContaining('Archived subjects'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete permanently'));
    await tester.pumpAndSettle();
    expect(find.text('Delete archived subject permanently?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(viewModel.archivedSubjects, contains('Unused Archived'));

    await tester.tap(find.byTooltip('Delete permanently'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(viewModel.archivedSubjects, isNot(contains('Unused Archived')));
  });

  testWidgets('blocked archived-subject deletion explains task references', (
    WidgetTester tester,
  ) async {
    final repository = InMemoryTaskRepository();
    final viewModel = TaskViewModel(taskRepository: repository);
    await viewModel.load();
    await viewModel.addSubject('Referenced Archived');
    await viewModel.archiveSubject('Referenced Archived');
    await repository.addTask(
      const Task(
        id: 'reference',
        title: 'Keep this task',
        subject: 'Referenced Archived',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SubjectsPage(viewModel: viewModel, onSubjectSelected: (_) {}),
        ),
      ),
    );

    await tester.tap(find.textContaining('Archived subjects'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete permanently'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'This subject cannot be permanently deleted because it is still '
        'used by 1 tasks and 0 timetable entries.',
      ),
      findsOneWidget,
    );
    expect(viewModel.archivedSubjects, contains('Referenced Archived'));
    expect((await repository.getTasks()).single.id, 'reference');
  });

  testWidgets('Task Details closes safely after immediate completion cleanup', (
    WidgetTester tester,
  ) async {
    final viewModel = TaskViewModel(taskRepository: InMemoryTaskRepository());
    viewModel.setCompletedTaskCleanupPolicy(
      CompletedTaskCleanupPolicy.immediate,
    );
    await viewModel.addTask(const Task(id: 'immediate', title: 'Immediate'));

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TaskDetailsDialog(
                  viewModel: viewModel,
                  task: viewModel.tasks.single,
                ),
              ),
              child: const Text('Open details'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open details'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark complete'));
    await tester.pumpAndSettle();

    expect(find.text('Close'), findsNothing);
    expect(viewModel.tasks, isEmpty);
  });
}
