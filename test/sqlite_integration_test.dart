import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:academic_planner/app/subjects.dart';
import 'package:academic_planner/app/timetable.dart';
import 'package:academic_planner/models/timetable_entry.dart';
import 'package:academic_planner/models/task.dart';
import 'package:academic_planner/repositories/academic_planner_database.dart';
import 'package:academic_planner/repositories/task_repository.dart';
import 'package:academic_planner/repositories/timetable_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    temporaryDirectory = Directory.systemTemp.createTempSync(
      'academic_planner_sqlite_test_',
    );
  });

  tearDown(() {
    temporaryDirectory.deleteSync(recursive: true);
  });

  test('fresh version 6 database creates schema, indexes, and seeds', () async {
    final database = await _openFreshDatabase();

    expect(database.getVersion(), completion(6));
    expect(
      (await database.rawQuery('PRAGMA table_info(tasks)'))
          .map((row) => row['name']),
      contains('completed_at'),
    );
    final activeSubjects = await database.query(
      'subjects',
      columns: ['name'],
      where: 'is_archived = 0',
      orderBy: 'created_at ASC',
    );
    expect(
      activeSubjects.map((row) => row['name']),
      containsAll([reminderSubject, ...appSubjects]),
    );
    expect(
      await _tableNames(database),
      containsAll(['tasks', 'subjects', 'timetable_entries']),
    );

    final indexes = await _indexNames(database);
    expect(
      indexes,
      containsAll([
        'idx_tasks_due_date',
        'idx_tasks_subject',
        'idx_tasks_completed',
        'idx_subjects_archived_name',
        'idx_timetable_day_time',
      ]),
    );

    final subjects = await database.query('subjects', columns: ['name']);
    expect(
      subjects.map((row) => row['name']),
      containsAll([reminderSubject, ...appSubjects]),
    );

    final entries = await database.query('timetable_entries');
    expect(entries, hasLength(grade11TimetableEntries.length));
    await database.close();
  });

  test(
    'v4 migrations preserve the subject registry and existing task data',
    () async {
      final databasePath = _databasePath;
      final v4Database = await databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 4,
          onCreate: (db, version) async {
            await _createVersionFiveTasksTable(db);
            await createSubjectsTable(db);
            await createTimetableEntriesTable(db);
            for (final subject in [
              reminderSubject,
              'Mathematics',
              'Physics',
              'Chemistry',
              'Biology',
              'English',
              'Social Science',
              'Computer Science',
              'PEHM',
              'Custom Subject',
              'Archived Subject',
            ]) {
              await db.insert('subjects', {
                'name': subject,
                'normalized_name': subject.toLowerCase(),
                'is_builtin': legacyBuiltInSubjects.contains(subject) ? 1 : 0,
                'is_archived': subject == 'Archived Subject' ? 1 : 0,
                'created_at': 100,
              });
            }
            await db.update(
              'subjects',
              {'name': 'Renamed Physics', 'normalized_name': 'renamed physics'},
              where: 'name = ?',
              whereArgs: ['Physics'],
            );
            await db.insert('tasks', {
              'id': 'legacy-task',
              'title': 'Legacy',
              'description': '',
              'subject': 'Physics',
              'due_date': null,
              'priority': 'medium',
              'is_completed': 0,
              'created_at': 100,
              'updated_at': 100,
            });
          },
        ),
      );
      await v4Database.close();

      Future<List<Map<String, Object?>>> subjects() async {
        final database = await databaseFactory.openDatabase(databasePath);
        final rows = await database.query('subjects');
        await database.close();
        return rows;
      }

      final migrated = await openAcademicPlannerDatabase(
        databasePath: databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      expect(await migrated.getVersion(), 6);
      final migratedSubjects = await migrated.query('subjects');
      expect(
        migratedSubjects
            .where((row) => legacyBuiltInSubjects.contains(row['name']))
            .every((row) => row['is_archived'] == 1),
        isTrue,
      );
      expect(
        migratedSubjects
            .where((row) => appSubjects.contains(row['name']))
            .every((row) => row['is_archived'] == 0),
        isTrue,
      );
      expect(
        migratedSubjects.singleWhere(
          (row) => row['name'] == reminderSubject,
        )['is_archived'],
        0,
      );
      expect(
        migratedSubjects.singleWhere(
          (row) => row['name'] == 'Custom Subject',
        )['is_archived'],
        0,
      );
      expect(
        migratedSubjects.singleWhere(
          (row) => row['name'] == 'Renamed Physics',
        )['is_archived'],
        0,
      );
      expect(
        migratedSubjects.singleWhere(
          (row) => row['name'] == 'Archived Subject',
        )['is_archived'],
        1,
      );
      expect((await migrated.query('tasks')).single['subject'], 'Physics');
      await migrated.close();

      final repository = SqliteTaskRepository(
        databasePath: databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      expect(await repository.getActiveSubjects(), [
        reminderSubject,
        ...appSubjects,
        'Custom Subject',
        'Renamed Physics',
      ]);
      await repository.close();

      final beforeSecondOpen = await subjects();
      final reopened = await openAcademicPlannerDatabase(
        databasePath: databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      expect(await reopened.getVersion(), 6);
      expect(await reopened.query('subjects'), beforeSecondOpen);
      expect(
        (await reopened.rawQuery(
          'SELECT normalized_name, COUNT(*) AS count FROM subjects GROUP BY normalized_name',
        )).every((row) => row['count'] == 1),
        isTrue,
      );
      await reopened.close();
    },
  );

  test(
    'v5 to v6 adds only completion timestamps and preserves user rows',
    () async {
      final databasePath = _databasePath;
      final v5Database = await databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, version) async {
            await _createVersionFiveTasksTable(db);
            await createSubjectsTable(db);
            await seedBuiltInSubjects(db);
            await createTimetableEntriesTable(db);
            await seedTimetableEntries(db);
            await db.insert('subjects', {
              'name': 'Active Custom',
              'normalized_name': 'active custom',
              'is_builtin': 0,
              'is_archived': 0,
              'created_at': 123,
            });
            await db.insert('subjects', {
              'name': 'Archived Custom',
              'normalized_name': 'archived custom',
              'is_builtin': 0,
              'is_archived': 1,
              'created_at': 124,
            });
            await db.insert('timetable_entries', {
              'id': 'v5-entry',
              'title': 'Custom lesson',
              'day_of_week': 2,
              'start_minutes': 500,
              'end_minutes': 550,
              'subject': 'Active Custom',
              'teacher': 'Teacher',
              'room': 'Room 2',
              'entry_type': 'classSession',
              'notes': 'Preserve this',
            });
            await db.insert('tasks', {
              'id': 'v5-open',
              'title': 'Open task',
              'description': 'Open description',
              'subject': 'Active Custom',
              'due_date': 1780000000000,
              'priority': 'high',
              'is_completed': 0,
              'created_at': 1770000000000,
              'updated_at': 1771000000000,
            });
            await db.insert('tasks', {
              'id': 'v5-completed',
              'title': 'Completed task',
              'description': 'Completed description',
              'subject': 'Archived Custom',
              'due_date': 1781000000000,
              'priority': 'low',
              'is_completed': 1,
              'created_at': 1772000000000,
              'updated_at': 1773000000000,
            });
            await db.insert('tasks', {
              'id': 'v5-no-due-date',
              'title': 'No due date',
              'description': '',
              'subject': 'Active Custom',
              'due_date': null,
              'priority': 'medium',
              'is_completed': 0,
              'created_at': 1774000000000,
              'updated_at': 1775000000000,
            });
          },
        ),
      );
      final oldTasks = await v5Database.query('tasks', orderBy: 'id');
      final oldSubjects = await v5Database.query('subjects', orderBy: 'name');
      final oldEntries = await v5Database.query(
        'timetable_entries',
        orderBy: 'id',
      );
      expect(await v5Database.getVersion(), 5);
      expect(
        (await v5Database.rawQuery('PRAGMA table_info(tasks)'))
            .map((row) => row['name']),
        isNot(contains('completed_at')),
      );
      await v5Database.close();

      final migrated = await openAcademicPlannerDatabase(
        databasePath: databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      expect(await migrated.getVersion(), 6);
      expect(
        (await migrated.rawQuery('PRAGMA table_info(tasks)'))
            .map((row) => row['name']),
        contains('completed_at'),
      );
      final migratedTasks = await migrated.query('tasks', orderBy: 'id');
      expect(
        migratedTasks.map((row) => row['completed_at']),
        everyElement(isNull),
      );
      expect(
        migratedTasks
            .map(
              (row) => Map<String, Object?>.from(row)..remove('completed_at'),
            )
            .toList(),
        oldTasks,
      );
      expect(await migrated.query('subjects', orderBy: 'name'), oldSubjects);
      expect(
        await migrated.query('timetable_entries', orderBy: 'id'),
        oldEntries,
      );
      final indexes = await _indexNames(migrated);
      expect(
        indexes,
        containsAll([
          'idx_tasks_due_date',
          'idx_tasks_subject',
          'idx_tasks_completed',
          'idx_subjects_archived_name',
          'idx_timetable_day_time',
        ]),
      );
      await migrated.close();

      final reopened = await openAcademicPlannerDatabase(
        databasePath: databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      expect(await reopened.getVersion(), 6);
      expect(await reopened.query('tasks', orderBy: 'id'), migratedTasks);
      expect(await reopened.query('subjects', orderBy: 'name'), oldSubjects);
      expect(
        await reopened.query('timetable_entries', orderBy: 'id'),
        oldEntries,
      );
      await reopened.close();
    },
  );

  test(
    'SQLite task repository round trips completedAt in UTC milliseconds',
    () async {
      final repository = SqliteTaskRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      final completedAt = DateTime.utc(2026, 9, 28, 16, 45, 12, 345);
      await repository.addTask(
        Task(
          id: 'completed-round-trip',
          title: 'Completed',
          isCompleted: true,
          completedAt: completedAt,
        ),
      );

      final stored = (await repository.getTasks()).single;
      expect(stored.completedAt, completedAt);
      await repository.close();

      final reopenedRepository = SqliteTaskRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      expect(
        (await reopenedRepository.getTasks()).single.completedAt,
        completedAt,
      );
      await reopenedRepository.close();
    },
  );

  test(
    'SQLite archived-subject deletion is atomic and protects references',
    () async {
      final repository = SqliteTaskRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      final timetableRepository = SqliteTimetableRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      for (final subject in [
        'Unused Archived',
        'Task Referenced',
        'Timetable Referenced',
        'Both Referenced',
        'Économie',
        'Still Active',
      ]) {
        await repository.addSubject(subject);
      }
      for (final subject in [
        'Unused Archived',
        'Task Referenced',
        'Timetable Referenced',
        'Both Referenced',
        'Économie',
      ]) {
        await repository.archiveSubject(subject);
      }
      await repository.addTask(
        const Task(
          id: 'task-reference',
          title: 'Preserve task',
          subject: 'Task Referenced',
        ),
      );
      await repository.addTask(
        const Task(
          id: 'both-task-reference',
          title: 'Preserve both task',
          subject: 'Both Referenced',
        ),
      );
      await repository.addTask(
        const Task(
          id: 'unicode-reference',
          title: 'Preserve Unicode task',
          subject: 'ÉCONOMIE',
        ),
      );
      for (final subject in ['Timetable Referenced', 'Both Referenced']) {
        await timetableRepository.addTimetableEntry(
          TimetableEntry(
            id: 'entry-$subject',
            title: 'Preserve timetable row',
            dayOfWeek: 1,
            startMinutes: 600,
            endMinutes: 650,
            subject: subject,
          ),
        );
      }

      expect(
        (await repository.deleteArchivedSubject('Task Referenced'))
            .taskReferenceCount,
        1,
      );
      final timetableBlocked = await repository.deleteArchivedSubject(
        'Timetable Referenced',
      );
      expect(timetableBlocked.deleted, isFalse);
      expect(timetableBlocked.timetableReferenceCount, 1);
      final bothBlocked = await repository.deleteArchivedSubject(
        'Both Referenced',
      );
      expect(bothBlocked.deleted, isFalse);
      expect(bothBlocked.taskReferenceCount, 1);
      expect(bothBlocked.timetableReferenceCount, 1);
      final unicodeBlocked = await repository.deleteArchivedSubject('Économie');
      expect(unicodeBlocked.deleted, isFalse);
      expect(unicodeBlocked.taskReferenceCount, 1);

      expect(
        (await repository.deleteArchivedSubject('Still Active')).deleted,
        isFalse,
      );
      expect(
        (await repository.deleteArchivedSubject('General')).deleted,
        isFalse,
      );
      expect(
        (await repository.deleteArchivedSubject('Missing Subject')).deleted,
        isFalse,
      );
      expect(
        (await repository.deleteArchivedSubject('Unused Archived')).deleted,
        isTrue,
      );
      expect(
        await repository.getArchivedSubjects(),
        contains('Task Referenced'),
      );
      expect(
        await repository.getArchivedSubjects(),
        contains('Both Referenced'),
      );
      expect(
        (await repository.getTasks()).map((task) => task.id),
        containsAll([
          'task-reference',
          'both-task-reference',
          'unicode-reference',
        ]),
      );
      expect(
        (await timetableRepository.getTimetableEntries()).where(
          (entry) => entry.id.startsWith('entry-'),
        ),
        hasLength(2),
      );
      await repository.close();
      await timetableRepository.close();

      final reopenedRepository = SqliteTaskRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      expect(
        await reopenedRepository.getArchivedSubjects(),
        isNot(contains('Unused Archived')),
      );
      expect(
        await reopenedRepository.getArchivedSubjects(),
        containsAll([
          'Task Referenced',
          'Timetable Referenced',
          'Both Referenced',
          'Économie',
        ]),
      );
      expect(
        (await reopenedRepository.getTasks()).map((task) => task.id),
        containsAll([
          'task-reference',
          'both-task-reference',
          'unicode-reference',
        ]),
      );
      await reopenedRepository.close();
    },
  );

  test(
    'SqliteTaskRepository renames subjects across related data and persists',
    () async {
      final repository = SqliteTaskRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      final timetableRepository = SqliteTimetableRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      await repository.addSubject('Physics');

      await repository.addTask(
        const Task(
          id: 'biology-1',
          title: 'Lab',
          subject: 'Mathematics 5 Level 1',
        ),
      );
      await repository.addTask(
        const Task(
          id: 'biology-2',
          title: 'Reading',
          subject: 'Mathematics 5 Level 1',
        ),
      );
      await repository.addTask(
        const Task(id: 'physics-1', title: 'Motion', subject: 'Physics'),
      );
      await timetableRepository.addTimetableEntry(
        const TimetableEntry(
          id: 'biology-entry-1',
          title: 'Biology',
          subject: 'Mathematics 5 Level 1',
          dayOfWeek: 1,
          startMinutes: 480,
          endMinutes: 530,
        ),
      );
      await timetableRepository.addTimetableEntry(
        const TimetableEntry(
          id: 'biology-entry-2',
          title: 'Biology Lab',
          subject: 'Mathematics 5 Level 1',
          dayOfWeek: 2,
          startMinutes: 540,
          endMinutes: 590,
        ),
      );
      await timetableRepository.addTimetableEntry(
        const TimetableEntry(
          id: 'physics-entry',
          title: 'Physics',
          subject: 'Physics',
          dayOfWeek: 3,
          startMinutes: 600,
          endMinutes: 650,
        ),
      );

      expect(
        await repository.renameSubject(
          'Mathematics 5 Level 1',
          'Natural Science',
        ),
        isTrue,
      );
      expect(await repository.getActiveSubjects(), contains('Natural Science'));
      expect(
        await repository.getActiveSubjects(),
        isNot(contains('Mathematics 5 Level 1')),
      );

      final tasks = await repository.getTasks();
      expect(
        tasks
            .where((task) => task.id.startsWith('biology'))
            .map((task) => task.subject),
        everyElement('Natural Science'),
      );
      expect(
        tasks.singleWhere((task) => task.id == 'physics-1').subject,
        'Physics',
      );

      final entries = await timetableRepository.getTimetableEntries();
      expect(
        entries
            .where((entry) => entry.id.startsWith('biology'))
            .map((entry) => entry.subject),
        everyElement('Natural Science'),
      );
      expect(
        entries.singleWhere((entry) => entry.id == 'physics-entry').subject,
        'Physics',
      );

      await repository.close();
      await timetableRepository.close();

      final reopenedRepository = SqliteTaskRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      final reopenedTimetableRepository = SqliteTimetableRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      expect(
        await reopenedRepository.getActiveSubjects(),
        contains('Natural Science'),
      );
      expect(
        (await reopenedRepository.getTasks())
            .where((task) => task.id.startsWith('biology'))
            .map((task) => task.subject),
        everyElement('Natural Science'),
      );
      expect(
        (await reopenedTimetableRepository.getTimetableEntries())
            .where((entry) => entry.id.startsWith('biology'))
            .map((entry) => entry.subject),
        everyElement('Natural Science'),
      );
      await reopenedRepository.close();
      await reopenedTimetableRepository.close();
    },
  );

  test(
    'SqliteTaskRepository rejects invalid renames without changing data',
    () async {
      final repository = SqliteTaskRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      final timetableRepository = SqliteTimetableRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      await repository.addSubject('Archived Subject');
      await repository.archiveSubject('Archived Subject');
      await repository.addTask(
        const Task(
          id: 'atomic-task',
          title: 'Keep',
          subject: 'Mathematics 5 Level 1',
        ),
      );
      await timetableRepository.addTimetableEntry(
        const TimetableEntry(
          id: 'atomic-entry',
          title: 'Keep',
          subject: 'Mathematics 5 Level 1',
          dayOfWeek: 1,
          startMinutes: 480,
          endMinutes: 530,
        ),
      );

      expect(
        await repository.renameSubject('Mathematics 5 Level 1', '  '),
        isFalse,
      );
      expect(
        await repository.renameSubject('Mathematics 5 Level 1', 'General'),
        isFalse,
      );
      expect(
        await repository.renameSubject(
          'Mathematics 5 Level 1',
          'Social Science 5',
        ),
        isFalse,
      );
      expect(
        await repository.renameSubject(
          'Mathematics 5 Level 1',
          'Archived Subject',
        ),
        isFalse,
      );
      expect(await repository.renameSubject('General', 'Renamed'), isFalse);
      expect(
        await repository.renameSubject('Missing Subject', 'Renamed'),
        isFalse,
      );

      expect(
        await repository.getActiveSubjects(),
        contains('Mathematics 5 Level 1'),
      );
      expect(
        await repository.getArchivedSubjects(),
        contains('Archived Subject'),
      );
      expect(
        (await repository.getTasks()).single.subject,
        'Mathematics 5 Level 1',
      );
      expect(
        (await timetableRepository.getTimetableEntries())
            .singleWhere((entry) => entry.id == 'atomic-entry')
            .subject,
        'Mathematics 5 Level 1',
      );
      await repository.close();
      await timetableRepository.close();
    },
  );

  test(
    'v2 to v3 migration preserves tasks and subjects and seeds timetable',
    () async {
      final databasePath = _databasePath;
      final v2Database = await databaseFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await _createVersionFiveTasksTable(db);
            await createSubjectsTable(db);
            await db.insert('tasks', {
              'id': 'existing-task',
              'title': 'Existing task',
              'description': 'Keep me',
              'subject': 'Legacy Subject',
              'due_date': null,
              'priority': 'high',
              'is_completed': 0,
              'created_at': 100,
              'updated_at': 100,
            });
            await db.insert('subjects', {
              'name': 'Legacy Subject',
              'normalized_name': 'legacy subject',
              'is_builtin': 0,
              'is_archived': 0,
              'created_at': 100,
            });
          },
        ),
      );
      await v2Database.close();

      final database = await openAcademicPlannerDatabase(
        databasePath: databasePath,
        databaseFactoryOverride: databaseFactory,
      );

      expect(await database.getVersion(), 6);
      expect(await database.query('tasks'), [
        {
          'id': 'existing-task',
          'title': 'Existing task',
          'description': 'Keep me',
          'subject': 'Legacy Subject',
          'due_date': null,
          'priority': 'high',
          'is_completed': 0,
          'created_at': 100,
          'updated_at': 100,
          'completed_at': null,
        },
      ]);
      expect(
        await database.query('subjects'),
        contains(containsPair('name', 'Legacy Subject')),
      );

      expect(await database.query('timetable_entries'), isNotEmpty);
      await database.close();
    },
  );

  test('v3 to v4 preserves rows and inserts new timetable seeds', () async {
    final databasePath = _databasePath;
    final v3Database = await databaseFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await _createVersionFiveTasksTable(db);
          await createSubjectsTable(db);
          await createTimetableEntriesTable(db);
          await db.insert('tasks', {
            'id': 'v3-task',
            'title': 'Existing task',
            'description': 'Preserve',
            'subject': 'Biology',
            'due_date': null,
            'priority': 'medium',
            'is_completed': 0,
            'created_at': 200,
            'updated_at': 200,
          });
          await db.insert('subjects', {
            'name': 'Biology',
            'normalized_name': 'biology',
            'is_builtin': 1,
            'is_archived': 0,
            'created_at': 200,
          });
          await db.insert('timetable_entries', {
            'id': 'existing-v3-entry',
            'title': 'Custom timetable row',
            'day_of_week': 1,
            'start_minutes': 450,
            'end_minutes': 500,
            'subject': null,
            'teacher': null,
            'room': null,
            'entry_type': 'other',
            'notes': 'Preserve this row',
          });
        },
      ),
    );
    await v3Database.close();

    final database = await openAcademicPlannerDatabase(
      databasePath: databasePath,
      databaseFactoryOverride: databaseFactory,
    );

    expect(await database.getVersion(), 6);
    expect(
      await database.query('tasks'),
      contains(containsPair('id', 'v3-task')),
    );
    expect(
      await database.query('subjects'),
      contains(containsPair('name', 'Biology')),
    );
    expect(
      await database.query('timetable_entries'),
      contains(
        allOf(
          containsPair('id', 'existing-v3-entry'),
          containsPair('notes', 'Preserve this row'),
        ),
      ),
    );
    expect(
      await database.query(
        'timetable_entries',
        where: 'id IN (?, ?, ?, ?)',
        whereArgs: [
          'wed-leap-research-consultation',
          'wed-wellness-break',
          'fri-flag-retreat',
          'fri-consultation-home-bound',
        ],
      ),
      hasLength(4),
    );
    expect(
      await database.query('timetable_entries'),
      hasLength(grade11TimetableEntries.length + 1),
    );
    await database.close();
  });

  test(
    'SQLite timetable repository supports CRUD and round trips fields',
    () async {
      final database = await _openFreshDatabase();
      await database.close();

      final repository = SqliteTimetableRepository(
        databasePath: _databasePath,
        databaseFactoryOverride: databaseFactory,
      );
      final entry = const TimetableEntry(
        id: 'round-trip',
        title: 'Consultation',
        dayOfWeek: 5,
        startMinutes: 670,
        endMinutes: 720,
        subject: null,
        teacher: null,
        room: null,
        entryType: TimetableEntryType.consultation,
        notes: 'Bring research notes',
      );

      await repository.addTimetableEntry(entry);
      final added = (await repository.getTimetableEntries()).singleWhere(
        (value) => value.id == entry.id,
      );
      expect(added.id, entry.id);
      expect(added.title, entry.title);
      expect(added.dayOfWeek, entry.dayOfWeek);
      expect(added.startMinutes, entry.startMinutes);
      expect(added.endMinutes, entry.endMinutes);
      expect(added.subject, isNull);
      expect(added.teacher, isNull);
      expect(added.room, isNull);
      expect(added.entryType, TimetableEntryType.consultation);
      expect(added.notes, entry.notes);

      final updated = TimetableEntry(
        id: entry.id,
        title: 'Updated class',
        dayOfWeek: 2,
        startMinutes: 450,
        endMinutes: 500,
        subject: 'Mathematics',
        teacher: 'Teacher',
        room: 'Room 1',
        entryType: TimetableEntryType.classSession,
        notes: 'Updated notes',
      );
      await repository.updateTimetableEntry(updated);
      expect(
        (await repository.getTimetableEntries()).singleWhere(
          (value) => value.id == entry.id,
        ),
        isA<TimetableEntry>(),
      );

      expect(
        () => repository.addTimetableEntry(entry),
        throwsA(isA<DatabaseException>()),
      );
      expect(
        () => repository.updateTimetableEntry(
          const TimetableEntry(
            id: 'missing',
            title: 'Missing',
            dayOfWeek: 1,
            startMinutes: 0,
            endMinutes: 1,
          ),
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => repository.deleteTimetableEntry('missing'),
        throwsA(isA<StateError>()),
      );

      await repository.deleteTimetableEntry(entry.id);
      expect(
        (await repository.getTimetableEntries()).where(
          (value) => value.id == entry.id,
        ),
        isEmpty,
      );
      await repository.close();
    },
  );
}

late Directory temporaryDirectory;

String get _databasePath => path.join(temporaryDirectory.path, 'test.db');

Future<void> _createVersionFiveTasksTable(DatabaseExecutor db) async {
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
      updated_at INTEGER
    )
  ''');
  await db.execute('CREATE INDEX idx_tasks_due_date ON tasks(due_date)');
  await db.execute('CREATE INDEX idx_tasks_subject ON tasks(subject)');
  await db.execute('CREATE INDEX idx_tasks_completed ON tasks(is_completed)');
}

Future<Database> _openFreshDatabase() {
  return openAcademicPlannerDatabase(
    databasePath: _databasePath,
    databaseFactoryOverride: databaseFactory,
  );
}

Future<Set<String>> _tableNames(Database database) async {
  final rows = await database.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table'",
  );
  return rows.map((row) => row['name'] as String).toSet();
}

Future<Set<String>> _indexNames(Database database) async {
  final rows = await database.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'index'",
  );
  return rows.map((row) => row['name'] as String).toSet();
}
