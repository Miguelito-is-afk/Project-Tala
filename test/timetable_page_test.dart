import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/app/timetable.dart';
import 'package:academic_planner/models/timetable_entry.dart';
import 'package:academic_planner/pages/timetable_page.dart';
import 'package:academic_planner/repositories/timetable_repository.dart';
import 'package:academic_planner/view_models/timetable_view_model.dart';

void main() {
  testWidgets('renders seeded timetable entries and weekdays', (tester) async {
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(),
    );
    await viewModel.load();

    await tester.pumpWidget(
      MaterialApp(home: TimetablePage(viewModel: viewModel)),
    );

    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Monday'), findsOneWidget);
    expect(find.text('Tuesday'), findsOneWidget);
    expect(find.text('Flag Ceremony'), findsOneWidget);
    expect(find.text('Science Core'), findsWidgets);
  });

  testWidgets('wide layout shows a time ruler and overlapping entries', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(
        initialEntries: const [
          TimetableEntry(
            id: 'first',
            title: 'First',
            dayOfWeek: 5,
            startMinutes: 900,
            endMinutes: 960,
          ),
          TimetableEntry(
            id: 'overlap',
            title: 'Overlap',
            dayOfWeek: 5,
            startMinutes: 930,
            endMinutes: 990,
          ),
        ],
      ),
    );
    await viewModel.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimetablePage(viewModel: viewModel)),
      ),
    );

    expect(find.text('3:00 PM'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Overlap'), findsOneWidget);
  });

  test('places non-overlapping entries in one lane', () {
    final placements = placeTimetableEntries([
      _entry('first', 60, 120),
      _entry('second', 120, 180),
    ]);

    expect(placements.every((placement) => placement.laneCount == 1), isTrue);
  });

  test('uses the shared vertical timeline scale', () {
    expect(timetableDurationHeight(20), closeTo(48, 0.001));
    expect(timetableDurationHeight(30), closeTo(72, 0.001));
    expect(timetableDurationHeight(50), closeTo(120, 0.001));
    expect(timetableDurationHeight(100), closeTo(240, 0.001));
    expect(
      timetableVerticalOffset(minutes: 480, timelineStart: 450),
      closeTo(72, 0.001),
    );
    expect(timetableRulerMinutes(timelineStart: 450, timelineEnd: 510), [
      450,
      480,
      510,
    ]);
  });

  testWidgets('wraps long entry titles without a nested card scroll view', (
    tester,
  ) async {
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(
        initialEntries: const [
          TimetableEntry(
            id: 'long-title',
            title: 'Research Laboratory/Consultation/Home Bound',
            dayOfWeek: 1,
            startMinutes: 450,
            endMinutes: 550,
            subject: 'Science Core',
          ),
        ],
      ),
    );
    await viewModel.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimetablePage(viewModel: viewModel)),
      ),
    );

    expect(
      find.text('Research Laboratory/Consultation/Home Bound'),
      findsOneWidget,
    );
    expect(find.byType(FittedBox), findsNothing);
    expect(
      find.descendant(
        of: find.byType(TimetablePage),
        matching: find.byType(SingleChildScrollView),
      ),
      findsOneWidget,
    );
  });

  test('places overlapping entries in separate lanes', () {
    final placements = placeTimetableEntries([
      _entry('first', 60, 120),
      _entry('second', 90, 150),
    ]);

    expect(placements.map((placement) => placement.lane), [0, 1]);
    expect(placements.every((placement) => placement.laneCount == 2), isTrue);
  });

  test('returns to one lane after an overlap cluster', () {
    final placements = placeTimetableEntries([
      _entry('first', 60, 120),
      _entry('second', 90, 150),
      _entry('later', 150, 210),
    ]);

    expect(placements.last.lane, 0);
    expect(placements.last.laneCount, 1);
  });

  test('handles chained overlap clusters correctly', () {
    final placements = placeTimetableEntries([
      _entry('a', 60, 120),
      _entry('b', 90, 150),
      _entry('c', 150, 210),
    ]);

    expect(placements[0].laneCount, 2);
    expect(placements[1].laneCount, 2);
    expect(placements[2].laneCount, 1);
  });

  testWidgets('narrow layout switches the selected weekday', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 800));
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(
        initialEntries: const [
          TimetableEntry(
            id: 'monday',
            title: 'Monday entry',
            dayOfWeek: 1,
            startMinutes: 450,
            endMinutes: 500,
          ),
          TimetableEntry(
            id: 'tuesday',
            title: 'Tuesday entry',
            dayOfWeek: 2,
            startMinutes: 450,
            endMinutes: 500,
          ),
        ],
      ),
    );
    await viewModel.load();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 500,
          height: 800,
          child: Scaffold(body: TimetablePage(viewModel: viewModel)),
        ),
      ),
    );

    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tuesday').last);
    await tester.pumpAndSettle();

    expect(viewModel.selectedWeekday, 2);
    expect(find.text('Tuesday entry'), findsOneWidget);
  });

  testWidgets('renders an empty timetable without crashing', (tester) async {
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(initialEntries: const []),
    );
    await viewModel.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimetablePage(viewModel: viewModel)),
      ),
    );

    expect(find.text('No entries'), findsWidgets);
  });

  testWidgets('add action opens editor and entry taps open details', (
    tester,
  ) async {
    const entry = TimetableEntry(
      id: 'editable',
      title: 'Editable entry',
      dayOfWeek: 1,
      startMinutes: 480,
      endMinutes: 540,
    );
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(initialEntries: [entry]),
    );
    await viewModel.load();
    viewModel.selectWeekday(1);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimetablePage(viewModel: viewModel)),
      ),
    );

    await tester.tap(find.text('Add entry'));
    await tester.pumpAndSettle();
    expect(find.text('Add Timetable Entry'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Editable entry'));
    await tester.pumpAndSettle();
    expect(find.text('Editable entry'), findsWidgets);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Timetable Entry'), findsOneWidget);
  });

  testWidgets('mutation errors keep the timetable page visible', (
    tester,
  ) async {
    final viewModel = TimetableViewModel(
      repository: _MutationFailingRepository(),
    );
    await viewModel.load();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TimetablePage(viewModel: viewModel)),
      ),
    );

    await tester.tap(find.text('Add entry').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Will fail');
    await tester.tap(find.text('Add entry').last);
    await tester.pumpAndSettle();

    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Unable to load timetable.'), findsNothing);
    expect(find.textContaining('add failed'), findsOneWidget);
  });

  test('seed data remains available to the page repository', () {
    expect(grade11TimetableEntries, isNotEmpty);
  });

  test(
    'uses default timeline bounds and expands for early and late entries',
    () {
      final normal = timetableTimelineBounds(grade11TimetableEntries);
      expect(normal.start, 360);
      expect(normal.end, 1320);

      final expanded = timetableTimelineBounds([
        _entry('early', 330, 360),
        _entry('late', 1410, 1440),
      ]);
      expect(expanded.start, 330);
      expect(expanded.end, 1440);
    },
  );
}

TimetableEntry _entry(String id, int startMinutes, int endMinutes) {
  return TimetableEntry(
    id: id,
    title: id,
    dayOfWeek: 1,
    startMinutes: startMinutes,
    endMinutes: endMinutes,
  );
}

class _MutationFailingRepository implements TimetableRepository {
  @override
  Future<void> addTimetableEntry(TimetableEntry entry) {
    return Future.error(StateError('add failed'));
  }

  @override
  Future<void> deleteTimetableEntry(String id) async {}

  @override
  Future<List<TimetableEntry>> getTimetableEntries() async => const [];

  @override
  Future<void> updateTimetableEntry(TimetableEntry entry) async {}
}
