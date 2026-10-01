import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/models/timetable_entry.dart';
import 'package:academic_planner/services/timetable_notification_service.dart';

void main() {
  test('notification IDs are deterministic and nonzero', () {
    expect(notificationIdForEntry('math'), notificationIdForEntry('math'));
    expect(notificationIdForEntry('math'), greaterThan(0));
    expect(
      notificationIdForEntry('math'),
      isNot(notificationIdForEntry('science')),
    );
  });

  test('only class sessions are eligible for scheduling', () {
    const entries = [
      TimetableEntry(
        id: 'class',
        title: 'Math',
        dayOfWeek: 1,
        startMinutes: 600,
        endMinutes: 660,
      ),
      TimetableEntry(
        id: 'break',
        title: 'Break',
        dayOfWeek: 1,
        startMinutes: 660,
        endMinutes: 680,
        entryType: TimetableEntryType.breakTime,
      ),
      TimetableEntry(
        id: 'consult',
        title: 'Consultation',
        dayOfWeek: 1,
        startMinutes: 680,
        endMinutes: 720,
        entryType: TimetableEntryType.consultation,
      ),
    ];
    final eligible = entries
        .where((entry) => entry.entryType == TimetableEntryType.classSession)
        .toList();
    expect(eligible.map((entry) => entry.id), ['class']);
  });

  test('calculates weekly reminder day and time for all supported offsets', () {
    const entry = TimetableEntry(
      id: 'math',
      title: 'Math',
      dayOfWeek: 2,
      startMinutes: 600,
      endMinutes: 660,
    );
    for (final offset in [5, 10, 15, 30]) {
      final reminder = calculateTimetableReminderTime(entry, offset);
      expect(reminder.weekday, 2);
      expect(reminder.minutes, 600 - offset);
    }
  });

  test('reminder calculation crosses midnight to the prior weekday', () {
    const entry = TimetableEntry(
      id: 'late',
      title: 'Late class',
      dayOfWeek: 1,
      startMinutes: 10,
      endMinutes: 50,
    );
    final reminder = calculateTimetableReminderTime(entry, 15);
    expect(reminder.weekday, 7);
    expect(reminder.minutes, 1435);
  });

  test('formats notification titles with singular and plural minutes', () {
    const entry = TimetableEntry(
      id: 'math',
      title: 'Math class',
      subject: 'Mathematics 5 Level 1',
      dayOfWeek: 1,
      startMinutes: 450,
      endMinutes: 500,
    );

    expect(
      formatTimetableNotificationTitle(entry, 1),
      'Mathematics 5 Level 1 is about to start in 1 minute',
    );
    expect(
      formatTimetableNotificationTitle(entry, 5),
      'Mathematics 5 Level 1 is about to start in 5 minutes',
    );
    expect(
      formatTimetableNotificationTitle(entry, 15),
      'Mathematics 5 Level 1 is about to start in 15 minutes',
    );
  });

  test('formats notification body as the configured time range', () {
    const entry = TimetableEntry(
      id: 'english',
      title: 'English class',
      dayOfWeek: 1,
      startMinutes: 450,
      endMinutes: 500,
    );

    expect(formatTimetableNotificationBody(entry), '7:30 AM – 8:20 AM');
  });
}
