import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/models/timetable_entry.dart';
import 'package:academic_planner/pages/timetable_entry_editor_dialog.dart';
import 'package:academic_planner/repositories/timetable_repository.dart';
import 'package:academic_planner/view_models/timetable_view_model.dart';

void main() {
  testWidgets('add dialog saves a valid entry', (tester) async {
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(initialEntries: const []),
    );
    await viewModel.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimetableEntryEditorDialog(viewModel: viewModel)),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'New entry');
    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();

    expect(viewModel.entries, hasLength(1));
    expect(viewModel.entries.single.title, 'New entry');
    expect(viewModel.entries.single.subject, isNull);
  });

  testWidgets('subject dropdown exposes active subjects and saves selection', (
    tester,
  ) async {
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(initialEntries: const []),
    );
    await viewModel.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimetableEntryEditorDialog(
            viewModel: viewModel,
            activeSubjects: const ['Mathematics 5 Level 1'],
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'New entry');
    expect(find.text('No subject'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    expect(find.text('Mathematics 5 Level 1'), findsOneWidget);
    expect(find.text('Physics'), findsNothing);
    await tester.tap(find.text('Mathematics 5 Level 1').last);
    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add entry'),
    );
    addButton.onPressed!();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();

    expect(viewModel.entries.single.subject, 'Mathematics 5 Level 1');
  });

  testWidgets('edit dialog preserves the entry ID', (tester) async {
    const entry = TimetableEntry(
      id: 'existing',
      title: 'Existing',
      dayOfWeek: 1,
      startMinutes: 480,
      endMinutes: 540,
    );
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(initialEntries: [entry]),
    );
    await viewModel.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimetableEntryEditorDialog(viewModel: viewModel, entry: entry),
        ),
      ),
    );

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(viewModel.entries.single.id, 'existing');
    expect(viewModel.entries.single.title, 'Existing');
  });

  testWidgets('editing preserves a legacy subject not in the active registry', (
    tester,
  ) async {
    const entry = TimetableEntry(
      id: 'legacy',
      title: 'Legacy class',
      subject: 'Archived Subject',
      dayOfWeek: 1,
      startMinutes: 480,
      endMinutes: 540,
    );
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(initialEntries: [entry]),
    );
    await viewModel.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimetableEntryEditorDialog(
            viewModel: viewModel,
            activeSubjects: const ['Mathematics 5 Level 1'],
            entry: entry,
          ),
        ),
      ),
    );

    expect(find.text('Archived Subject'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(viewModel.entries.single.subject, 'Archived Subject');
  });

  testWidgets('rejects a blank title and invalid time range', (tester) async {
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(initialEntries: const []),
    );
    await viewModel.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimetableEntryEditorDialog(viewModel: viewModel)),
      ),
    );

    await tester.tap(find.text('Add entry'));
    await tester.pump();
    expect(find.text('Title cannot be blank.'), findsOneWidget);
    expect(
      validateTimetableEntryFields(
        title: 'Invalid',
        dayOfWeek: 1,
        startMinutes: 600,
        endMinutes: 600,
      ),
      'Start time must be before end time.',
    );
    expect(viewModel.entries, isEmpty);
  });

  testWidgets('delete confirmation removes an existing entry', (tester) async {
    const entry = TimetableEntry(
      id: 'delete-me',
      title: 'Delete me',
      dayOfWeek: 1,
      startMinutes: 480,
      endMinutes: 540,
    );
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(initialEntries: [entry]),
    );
    await viewModel.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TimetableEntryEditorDialog(viewModel: viewModel, entry: entry),
        ),
      ),
    );

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(viewModel.entries, isEmpty);
  });
}
