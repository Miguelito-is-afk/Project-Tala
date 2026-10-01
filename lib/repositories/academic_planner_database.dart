import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import '../app/subjects.dart';
import '../app/timetable.dart';

const academicPlannerDatabaseVersion = 6;
const academicPlannerDatabaseName = 'academic_planner.db';

Future<Database> openAcademicPlannerDatabase({
  String? databasePath,
  DatabaseFactory? databaseFactoryOverride,
}) async {
  final resolvedPath =
      databasePath ??
      path.join(await getDatabasesPath(), academicPlannerDatabaseName);
  final factory = databaseFactoryOverride ?? databaseFactory;

  return factory.openDatabase(
    resolvedPath,
    options: OpenDatabaseOptions(
      version: academicPlannerDatabaseVersion,
      onCreate: (db, version) async {
        await createTasksTable(db);
        await createSubjectsTable(db);
        await seedBuiltInSubjects(db);
        await createTimetableEntriesTable(db);
        await seedTimetableEntries(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await createSubjectsTable(db);
          await seedBuiltInSubjects(db);
        }
        if (oldVersion < 3) {
          await createTimetableEntriesTable(db);
          await seedTimetableEntries(db);
        }
        if (oldVersion < 4) {
          await seedTimetableEntries(db);
        }
        if (oldVersion < 5) {
          await migrateSubjectsToCurrentSchoolYear(db);
        }
        if (oldVersion < 6) {
          await db.execute('ALTER TABLE tasks ADD COLUMN completed_at INTEGER');
        }
      },
    ),
  );
}

Future<void> migrateSubjectsToCurrentSchoolYear(Database db) async {
  final createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;

  for (final subject in appSubjects) {
    await db.insert('subjects', {
      'name': subject,
      'normalized_name': subject.trim().toLowerCase(),
      'is_builtin': 1,
      'is_archived': 0,
      'created_at': createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  for (final subject in legacyBuiltInSubjects) {
    await db.update(
      'subjects',
      {'is_archived': 1},
      where: 'name = ? AND is_builtin = 1',
      whereArgs: [subject],
    );
  }
}

Future<void> createTasksTable(Database db) async {
  await db.execute('''
    CREATE TABLE tasks (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      description TEXT NOT NULL,
      subject TEXT NOT NULL,
      due_date INTEGER,
      priority TEXT NOT NULL,
      is_completed INTEGER NOT NULL,
      created_at INTEGER,
      updated_at INTEGER,
      completed_at INTEGER
    )
  ''');

  await db.execute('''
    CREATE INDEX idx_tasks_due_date
    ON tasks(due_date)
  ''');
  await db.execute('''
    CREATE INDEX idx_tasks_subject
    ON tasks(subject)
  ''');
  await db.execute('''
    CREATE INDEX idx_tasks_completed
    ON tasks(is_completed)
  ''');
}

Future<void> createSubjectsTable(Database db) async {
  await db.execute('''
    CREATE TABLE subjects (
      name TEXT NOT NULL PRIMARY KEY COLLATE NOCASE,
      normalized_name TEXT NOT NULL UNIQUE,
      is_builtin INTEGER NOT NULL,
      is_archived INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    )
  ''');

  await db.execute('''
    CREATE INDEX idx_subjects_archived_name
    ON subjects(is_archived, name)
  ''');
}

Future<void> seedBuiltInSubjects(Database db) async {
  final createdAt = DateTime.now().toUtc().millisecondsSinceEpoch;

  for (final subject in [reminderSubject, ...appSubjects]) {
    await db.insert('subjects', {
      'name': subject,
      'normalized_name': subject.trim().toLowerCase(),
      'is_builtin': 1,
      'is_archived': 0,
      'created_at': createdAt,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}

Future<void> createTimetableEntriesTable(Database db) async {
  await db.execute('''
    CREATE TABLE timetable_entries (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      day_of_week INTEGER NOT NULL,
      start_minutes INTEGER NOT NULL,
      end_minutes INTEGER NOT NULL,
      subject TEXT,
      teacher TEXT,
      room TEXT,
      entry_type TEXT NOT NULL,
      notes TEXT NOT NULL DEFAULT ''
    )
  ''');

  await db.execute('''
    CREATE INDEX idx_timetable_day_time
    ON timetable_entries(day_of_week, start_minutes)
  ''');
}

Future<void> seedTimetableEntries(Database db) async {
  for (final entry in grade11TimetableEntries) {
    await db.insert('timetable_entries', {
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
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
