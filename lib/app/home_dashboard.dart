import '../models/task.dart';
import '../models/timetable_entry.dart';

bool _isSubjectClass(TimetableEntry entry) {
  return entry.entryType == TimetableEntryType.classSession &&
      entry.subject != null &&
      entry.subject!.trim().isNotEmpty;
}

List<TimetableEntry> currentTimetableEvents(
  Iterable<TimetableEntry> entries, {
  required DateTime now,
}) {
  final minute = now.hour * 60 + now.minute;
  return entries
      .where(
        (entry) =>
            entry.dayOfWeek == now.weekday &&
            entry.startMinutes <= minute &&
            minute < entry.endMinutes,
      )
      .toList()
    ..sort(
      (first, second) => first.startMinutes.compareTo(second.startMinutes),
    );
}

double timetableEventProgress(TimetableEntry entry, {required DateTime now}) {
  final minute = now.hour * 60 + now.minute + now.second / 60;
  return ((minute - entry.startMinutes) /
          (entry.endMinutes - entry.startMinutes))
      .clamp(0.0, 1.0);
}

String timetableMinutesRemaining(
  TimetableEntry entry, {
  required DateTime now,
}) {
  final remaining =
      entry.endMinutes - (now.hour * 60 + now.minute + now.second / 60);
  if (remaining < 1) return 'Less than 1 minute left';
  final minutes = remaining.ceil();
  return '$minutes minute${minutes == 1 ? '' : 's'} left';
}

List<TimetableEntry> runningSubjectClasses(
  Iterable<TimetableEntry> entries, {
  required DateTime now,
}) {
  final minute = now.hour * 60 + now.minute;
  return entries
      .where(
        (entry) =>
            _isSubjectClass(entry) &&
            entry.dayOfWeek == now.weekday &&
            entry.startMinutes <= minute &&
            minute < entry.endMinutes,
      )
      .toList()
    ..sort(
      (first, second) => first.startMinutes.compareTo(second.startMinutes),
    );
}

List<TimetableEntry> nextSubjectClasses(
  Iterable<TimetableEntry> entries, {
  required DateTime now,
  int limit = 3,
}) {
  final minute = now.hour * 60 + now.minute;
  final classes = entries.where(_isSubjectClass).where((entry) {
    final dayOffset = (entry.dayOfWeek - now.weekday + 7) % 7;
    if (dayOffset == 0) {
      return entry.startMinutes > minute;
    }
    return entry.dayOfWeek >= 1 && entry.dayOfWeek <= 5;
  }).toList();

  classes.sort((first, second) {
    final firstOffset = (first.dayOfWeek - now.weekday + 7) % 7;
    final secondOffset = (second.dayOfWeek - now.weekday + 7) % 7;
    final dayComparison = firstOffset.compareTo(secondOffset);
    return dayComparison == 0
        ? first.startMinutes.compareTo(second.startMinutes)
        : dayComparison;
  });
  return classes.take(limit).toList(growable: false);
}

List<Task> tasksDueToday(Iterable<Task> tasks, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  return tasks.where((task) {
    final dueDate = task.dueDate?.toLocal();
    return dueDate != null &&
        DateTime(dueDate.year, dueDate.month, dueDate.day) == today;
  }).toList();
}

int overdueTaskCount(Iterable<Task> tasks, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  return tasks.where((task) {
    final dueDate = task.dueDate?.toLocal();
    if (task.isCompleted || dueDate == null) return false;
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return dueDay.isBefore(today);
  }).length;
}

int openTasksDueWithinNextSevenDays(
  Iterable<Task> tasks, {
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final end = today.add(const Duration(days: 7));
  return tasks.where((task) {
    final dueDate = task.dueDate?.toLocal();
    if (task.isCompleted || dueDate == null) return false;
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return !dueDay.isBefore(today) && dueDay.isBefore(end);
  }).length;
}

Map<String, int> subjectWorkload(
  Iterable<Task> tasks, {
  required DateTime now,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final end = today.add(const Duration(days: 7));
  final workload = <String, int>{};
  for (final task in tasks) {
    final dueDate = task.dueDate?.toLocal();
    if (task.isCompleted || dueDate == null) continue;
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    if (dueDay.isBefore(today) || !dueDay.isBefore(end)) continue;
    workload.update(task.subject, (count) => count + 1, ifAbsent: () => 1);
  }
  return Map.unmodifiable(
    Map.fromEntries(
      workload.entries.toList()
        ..sort((first, second) => second.value.compareTo(first.value)),
    ),
  );
}
