import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/app/timetable.dart';
import 'package:academic_planner/models/timetable_entry.dart';
import 'package:academic_planner/repositories/academic_planner_database.dart';
import 'package:academic_planner/repositories/timetable_repository.dart';

void main() {
  group('TimetableEntry', () {
    test('accepts valid weekday and minute ranges', () {
      const entry = TimetableEntry(
        id: 'valid',
        title: 'Class',
        dayOfWeek: 1,
        startMinutes: 450,
        endMinutes: 500,
      );

      expect(entry.dayOfWeek, 1);
      expect(entry.endMinutes, 500);
    });

    test('rejects invalid days and times', () {
      expect(
        () => TimetableEntry(
          id: 'bad-day',
          title: 'Class',
          dayOfWeek: 0,
          startMinutes: 450,
          endMinutes: 500,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => TimetableEntry(
          id: 'bad-start',
          title: 'Class',
          dayOfWeek: 1,
          startMinutes: -1,
          endMinutes: 500,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => TimetableEntry(
          id: 'bad-order',
          title: 'Class',
          dayOfWeek: 1,
          startMinutes: 500,
          endMinutes: 500,
        ),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => TimetableEntry(
          id: 'bad-end',
          title: 'Class',
          dayOfWeek: 1,
          startMinutes: 500,
          endMinutes: 1441,
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('InMemoryTimetableRepository', () {
    late InMemoryTimetableRepository repository;

    setUp(() {
      repository = InMemoryTimetableRepository(initialEntries: const []);
    });

    test(
      'starts with the supplied entries and sorts by day and time',
      () async {
        await repository.addTimetableEntry(_entry('late', 2, 600));
        await repository.addTimetableEntry(_entry('early', 1, 500));
        await repository.addTimetableEntry(_entry('same-day-earlier', 2, 450));

        final entries = await repository.getTimetableEntries();

        expect(entries.map((entry) => entry.id), [
          'early',
          'same-day-earlier',
          'late',
        ]);
      },
    );

    test('supports add, update, and delete', () async {
      await repository.addTimetableEntry(_entry('entry', 1, 450));
      await repository.updateTimetableEntry(
        _entry('entry', 1, 460, title: 'Updated'),
      );

      expect((await repository.getTimetableEntries()).single.title, 'Updated');

      await repository.deleteTimetableEntry('entry');
      expect(await repository.getTimetableEntries(), isEmpty);
    });

    test('rejects duplicate IDs and missing updates or deletes', () async {
      await repository.addTimetableEntry(_entry('duplicate', 1, 450));

      expect(
        () => repository.addTimetableEntry(_entry('duplicate', 2, 500)),
        throwsA(isA<StateError>()),
      );
      expect(
        () => repository.updateTimetableEntry(_entry('missing', 1, 450)),
        throwsA(isA<StateError>()),
      );
      expect(
        () => repository.deleteTimetableEntry('missing'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('seeded timetable', () {
    test('contains the expected core entries', () {
      final entriesById = {
        for (final entry in grade11TimetableEntries) entry.id: entry,
      };

      expect(entriesById['mon-flag-ceremony']!.startMinutes, 450);
      expect(entriesById['mon-science-core']!.endMinutes, 750);
      expect(entriesById['tue-mathematics-5-level-1']!.dayOfWeek, 2);
      expect(
        entriesById['wed-activity-alp']!.entryType,
        TimetableEntryType.activity,
      );
      expect(entriesById['wed-leap-research-consultation']!.startMinutes, 550);
      expect(entriesById['wed-wellness-break']!.endMinutes, 600);
      expect(entriesById['thu-research-laboratory-library']!.startMinutes, 780);
      expect(entriesById['fri-electives']!.startMinutes, 830);
      expect(entriesById['fri-flag-retreat']!.startMinutes, 920);
      expect(entriesById['fri-flag-retreat']!.endMinutes, 980);
      expect(entriesById['fri-consultation-home-bound']!.startMinutes, 980);
    });

    test('uses database version 6', () {
      expect(academicPlannerDatabaseVersion, 6);
    });
  });
}

TimetableEntry _entry(
  String id,
  int dayOfWeek,
  int startMinutes, {
  String title = 'Class',
}) {
  return TimetableEntry(
    id: id,
    title: title,
    dayOfWeek: dayOfWeek,
    startMinutes: startMinutes,
    endMinutes: startMinutes + 50,
  );
}
