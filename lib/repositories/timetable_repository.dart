import 'package:sqflite/sqflite.dart';

import '../app/timetable.dart';
import '../models/timetable_entry.dart';
import 'academic_planner_database.dart';

abstract interface class TimetableRepository {
  Future<List<TimetableEntry>> getTimetableEntries();
  Future<void> addTimetableEntry(TimetableEntry entry);
  Future<void> updateTimetableEntry(TimetableEntry entry);
  Future<void> deleteTimetableEntry(String id);
}

class InMemoryTimetableRepository implements TimetableRepository {
  InMemoryTimetableRepository({List<TimetableEntry>? initialEntries})
    : _entries = List.of(initialEntries ?? grade11TimetableEntries);

  final List<TimetableEntry> _entries;

  @override
  Future<List<TimetableEntry>> getTimetableEntries() async {
    final entries = List<TimetableEntry>.of(_entries)..sort(_compareEntries);
    return List.unmodifiable(entries);
  }

  @override
  Future<void> addTimetableEntry(TimetableEntry entry) async {
    if (_entries.any((existing) => existing.id == entry.id)) {
      throw StateError(
        'A timetable entry with ID "${entry.id}" already exists.',
      );
    }
    _entries.add(entry);
  }

  @override
  Future<void> updateTimetableEntry(TimetableEntry entry) async {
    final index = _entries.indexWhere((existing) => existing.id == entry.id);
    if (index == -1) {
      throw StateError('Timetable entry with ID "${entry.id}" was not found.');
    }
    _entries[index] = entry;
  }

  @override
  Future<void> deleteTimetableEntry(String id) async {
    final index = _entries.indexWhere((entry) => entry.id == id);
    if (index == -1) {
      throw StateError('Timetable entry with ID "$id" was not found.');
    }
    _entries.removeAt(index);
  }
}

class SqliteTimetableRepository implements TimetableRepository {
  SqliteTimetableRepository({this.databasePath, this.databaseFactoryOverride});

  final String? databasePath;
  final DatabaseFactory? databaseFactoryOverride;

  Future<Database>? _databaseFuture;

  Future<Database> get _database {
    return _databaseFuture ??= openAcademicPlannerDatabase(
      databasePath: databasePath,
      databaseFactoryOverride: databaseFactoryOverride,
    );
  }

  Future<void> close() async {
    final databaseFuture = _databaseFuture;
    _databaseFuture = null;
    if (databaseFuture != null) {
      await (await databaseFuture).close();
    }
  }

  @override
  Future<List<TimetableEntry>> getTimetableEntries() async {
    final db = await _database;
    final rows = await db.query(
      'timetable_entries',
      orderBy: 'day_of_week ASC, start_minutes ASC',
    );
    return rows.map(_fromMap).toList(growable: false);
  }

  @override
  Future<void> addTimetableEntry(TimetableEntry entry) async {
    final db = await _database;
    await db.insert('timetable_entries', _toMap(entry));
  }

  @override
  Future<void> updateTimetableEntry(TimetableEntry entry) async {
    final db = await _database;
    final updatedRows = await db.update(
      'timetable_entries',
      _toMap(entry),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
    if (updatedRows == 0) {
      throw StateError('Timetable entry with ID "${entry.id}" was not found.');
    }
  }

  @override
  Future<void> deleteTimetableEntry(String id) async {
    final db = await _database;
    final deletedRows = await db.delete(
      'timetable_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (deletedRows == 0) {
      throw StateError('Timetable entry with ID "$id" was not found.');
    }
  }

  Map<String, Object?> _toMap(TimetableEntry entry) {
    return {
      'id': entry.id,
      'title': entry.title,
      'day_of_week': entry.dayOfWeek,
      'start_minutes': entry.startMinutes,
      'end_minutes': entry.endMinutes,
      'subject': entry.subject,
      'teacher': entry.teacher,
      'room': entry.room,
      'entry_type': entry.entryType.name,
      'notes': entry.notes,
    };
  }

  TimetableEntry _fromMap(Map<String, Object?> map) {
    return TimetableEntry(
      id: map['id'] as String,
      title: map['title'] as String,
      dayOfWeek: map['day_of_week'] as int,
      startMinutes: map['start_minutes'] as int,
      endMinutes: map['end_minutes'] as int,
      subject: map['subject'] as String?,
      teacher: map['teacher'] as String?,
      room: map['room'] as String?,
      entryType: TimetableEntryType.values.byName(map['entry_type'] as String),
      notes: map['notes'] as String,
    );
  }
}

int _compareEntries(TimetableEntry first, TimetableEntry second) {
  final dayComparison = first.dayOfWeek.compareTo(second.dayOfWeek);
  return dayComparison == 0
      ? first.startMinutes.compareTo(second.startMinutes)
      : dayComparison;
}
