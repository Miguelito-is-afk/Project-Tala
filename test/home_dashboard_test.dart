import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/app/home_dashboard.dart';
import 'package:academic_planner/models/task.dart';
import 'package:academic_planner/models/timetable_entry.dart';

TimetableEntry _entry({
  required String id,
  required int day,
  required int start,
  required int end,
  String? subject = 'Mathematics 5 Level 1',
  TimetableEntryType type = TimetableEntryType.classSession,
  String? teacher,
  String? room,
  String notes = '',
}) {
  return TimetableEntry(
    id: id,
    title: id,
    dayOfWeek: day,
    startMinutes: start,
    endMinutes: end,
    subject: subject,
    entryType: type,
    teacher: teacher,
    room: room,
    notes: notes,
  );
}

void main() {
  test('finds all currently running subject classes', () {
    final entries = [
      _entry(id: 'first', day: 1, start: 540, end: 660),
      _entry(
        id: 'break',
        day: 1,
        start: 540,
        end: 660,
        type: TimetableEntryType.breakTime,
      ),
      _entry(id: 'no-subject', day: 1, start: 540, end: 660, subject: null),
      _entry(
        id: 'second',
        day: 1,
        start: 600,
        end: 720,
        subject: 'Science Core',
      ),
    ];

    expect(
      runningSubjectClasses(entries, now: DateTime(2026, 9, 21, 10)),
      containsAll([entries[0], entries[3]]),
    );
  });

  test('finds every current timetable event, including non-class events', () {
    final now = DateTime(2026, 9, 21, 10, 15);
    final entries = [
      _entry(id: 'class', day: 1, start: 600, end: 660),
      _entry(
        id: 'recess',
        day: 1,
        start: 600,
        end: 660,
        subject: null,
        type: TimetableEntryType.breakTime,
      ),
      _entry(
        id: 'lunch',
        day: 1,
        start: 600,
        end: 660,
        subject: null,
        type: TimetableEntryType.other,
      ),
      _entry(
        id: 'consultation',
        day: 1,
        start: 600,
        end: 660,
        subject: null,
        type: TimetableEntryType.consultation,
      ),
      _entry(
        id: 'activity',
        day: 1,
        start: 600,
        end: 660,
        subject: null,
        type: TimetableEntryType.activity,
      ),
      _entry(id: 'later', day: 1, start: 660, end: 720),
    ];

    expect(currentTimetableEvents(entries, now: now).map((entry) => entry.id), [
      'class',
      'recess',
      'lunch',
      'consultation',
      'activity',
    ]);
  });

  test('returns no current event outside the scheduled range', () {
    final entry = _entry(id: 'class', day: 1, start: 600, end: 660);

    expect(
      currentTimetableEvents([entry], now: DateTime(2026, 9, 21, 11)),
      isEmpty,
    );
  });

  test('calculates progress and remaining time deterministically', () {
    final entry = _entry(id: 'class', day: 1, start: 600, end: 660);

    expect(
      timetableEventProgress(entry, now: DateTime(2026, 9, 21, 10, 15)),
      0.25,
    );
    expect(
      timetableMinutesRemaining(entry, now: DateTime(2026, 9, 21, 10, 59)),
      '1 minute left',
    );
    expect(
      timetableMinutesRemaining(entry, now: DateTime(2026, 9, 21, 10, 55)),
      '5 minutes left',
    );
  });

  test('preserves optional event metadata and overlapping events', () {
    final first = _entry(
      id: 'first',
      day: 1,
      start: 600,
      end: 660,
      teacher: 'Teacher A',
      room: 'Room 302',
      notes: 'Bring materials',
    );
    final second = _entry(id: 'second', day: 1, start: 630, end: 690);

    final current = currentTimetableEvents([
      first,
      second,
    ], now: DateTime(2026, 9, 21, 10, 40));

    expect(current, [first, second]);
    expect(first.teacher, 'Teacher A');
    expect(first.room, 'Room 302');
    expect(first.notes, 'Bring materials');
  });

  test('finds the next class today and rolls to the next school day', () {
    final entries = [
      _entry(id: 'today', day: 1, start: 800, end: 850),
      _entry(id: 'tomorrow', day: 2, start: 480, end: 530),
      _entry(
        id: 'consultation',
        day: 1,
        start: 900,
        end: 950,
        type: TimetableEntryType.consultation,
      ),
    ];

    expect(
      nextSubjectClasses(entries, now: DateTime(2026, 9, 21, 12)).first.id,
      'today',
    );
    expect(
      nextSubjectClasses([
        entries[1],
      ], now: DateTime(2026, 9, 21, 12)).single.id,
      'tomorrow',
    );
    expect(
      nextSubjectClasses(entries, now: DateTime(2026, 9, 21, 12)),
      isNot(contains(entries[2])),
    );
  });

  test('filters today tasks and excludes tasks without due dates', () {
    final now = DateTime(2026, 9, 21, 12);
    final tasks = [
      Task(id: 'today', title: 'Today', dueDate: DateTime(2026, 9, 21)),
      Task(id: 'tomorrow', title: 'Tomorrow', dueDate: DateTime(2026, 9, 22)),
      const Task(id: 'none', title: 'No date'),
    ];

    expect(tasksDueToday(tasks, now: now).map((task) => task.id), ['today']);
  });

  test('calculates overdue, next-seven-day, and subject workload metrics', () {
    final now = DateTime(2026, 9, 21, 12);
    final tasks = [
      Task(
        id: 'overdue',
        title: 'Overdue',
        subject: 'Science Core',
        dueDate: DateTime(2026, 9, 20),
      ),
      Task(
        id: 'soon',
        title: 'Soon',
        subject: 'Science Core',
        dueDate: DateTime(2026, 9, 22),
      ),
      Task(
        id: 'completed',
        title: 'Completed',
        subject: 'English 5',
        dueDate: DateTime(2026, 9, 23),
        isCompleted: true,
      ),
      const Task(id: 'no-date', title: 'No date', subject: 'English 5'),
    ];

    expect(overdueTaskCount(tasks, now: now), 1);
    expect(openTasksDueWithinNextSevenDays(tasks, now: now), 1);
    expect(subjectWorkload(tasks, now: now), {'Science Core': 1});
  });
}
