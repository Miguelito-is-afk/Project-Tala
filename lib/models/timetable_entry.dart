enum TimetableEntryType {
  classSession,
  breakTime,
  consultation,
  activity,
  other,
}

class TimetableEntry {
  const TimetableEntry({
    required this.id,
    required this.title,
    required this.dayOfWeek,
    required this.startMinutes,
    required this.endMinutes,
    this.subject,
    this.teacher,
    this.room,
    this.entryType = TimetableEntryType.classSession,
    this.notes = '',
  }) : assert(dayOfWeek >= 1 && dayOfWeek <= 7),
       assert(startMinutes >= 0),
       assert(endMinutes > startMinutes),
       assert(endMinutes <= 1440),
       assert(id != ''),
       assert(title != '');

  final String id;
  final String title;
  final int dayOfWeek;
  final int startMinutes;
  final int endMinutes;
  final String? subject;
  final String? teacher;
  final String? room;
  final TimetableEntryType entryType;
  final String notes;
}
