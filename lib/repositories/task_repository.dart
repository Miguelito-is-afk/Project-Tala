import 'package:sqflite/sqflite.dart';

import '../app/subjects.dart';
import '../models/task.dart';
import 'academic_planner_database.dart';

String normalizeSubjectName(String name) => name.trim().toLowerCase();

abstract interface class TaskRepository {
  Future<List<Task>> getTasks();
  Future<void> addTask(Task task);
  Future<void> updateTask(Task task);
  Future<void> deleteTask(String id);
  Future<Set<String>> deleteCompletedTasks(Set<String> ids);
  Future<List<String>> getActiveSubjects();
  Future<List<String>> getArchivedSubjects();
  Future<bool> addSubject(String name);
  Future<bool> renameSubject(String oldName, String newName);
  Future<bool> archiveSubject(String name);
  Future<bool> restoreSubject(String name);
  Future<SubjectDeletionResult> deleteArchivedSubject(String name);
}

class SubjectDeletionResult {
  const SubjectDeletionResult({
    required this.deleted,
    this.taskReferenceCount = 0,
    this.timetableReferenceCount = 0,
  });

  final bool deleted;
  final int taskReferenceCount;
  final int timetableReferenceCount;
}

class InMemoryTaskRepository implements TaskRepository {
  final List<Task> _tasks = [];
  final Map<String, String> _activeSubjects = {};
  final Map<String, String> _archivedSubjects = {};

  InMemoryTaskRepository() {
    _seedBuiltInSubjects();
  }

  @override
  Future<List<Task>> getTasks() async {
    return List.unmodifiable(_tasks);
  }

  @override
  Future<void> addTask(Task task) async {
    final alreadyExists = _tasks.any(
      (existingTask) => existingTask.id == task.id,
    );

    if (alreadyExists) {
      throw StateError('A task with ID "${task.id}" already exists.');
    }

    _tasks.add(task);
  }

  @override
  Future<void> updateTask(Task task) async {
    final index = _tasks.indexWhere(
      (existingTask) => existingTask.id == task.id,
    );

    if (index == -1) {
      throw StateError('Task with ID "${task.id}" was not found.');
    }

    _tasks[index] = task;
  }

  @override
  Future<void> deleteTask(String id) async {
    final index = _tasks.indexWhere((task) => task.id == id);

    if (index == -1) {
      throw StateError('Task with ID "$id" was not found.');
    }

    _tasks.removeAt(index);
  }

  @override
  Future<Set<String>> deleteCompletedTasks(Set<String> ids) async {
    final deletedIds = <String>{};
    _tasks.removeWhere((task) {
      if (ids.contains(task.id) && task.isCompleted) {
        deletedIds.add(task.id);
        return true;
      }
      return false;
    });
    return deletedIds;
  }

  @override
  Future<List<String>> getActiveSubjects() async {
    return _sortedSubjects(_activeSubjects.values);
  }

  @override
  Future<List<String>> getArchivedSubjects() async {
    return _sortedSubjects(_archivedSubjects.values);
  }

  @override
  Future<bool> addSubject(String name) async {
    final displayName = name.trim();
    final normalizedName = normalizeSubjectName(displayName);

    if (displayName.isEmpty ||
        normalizedName == normalizeSubjectName(reminderSubject) ||
        _hasSubject(normalizedName)) {
      return false;
    }

    _activeSubjects[normalizedName] = displayName;
    return true;
  }

  @override
  Future<bool> renameSubject(String oldName, String newName) async {
    final oldNormalized = normalizeSubjectName(oldName);
    final displayName = newName.trim();
    final normalizedName = normalizeSubjectName(displayName);
    if (oldNormalized == normalizeSubjectName(reminderSubject) ||
        displayName.isEmpty ||
        normalizedName == normalizeSubjectName(reminderSubject) ||
        !_activeSubjects.containsKey(oldNormalized) ||
        _hasSubject(normalizedName)) {
      return false;
    }

    final oldDisplayName = _activeSubjects.remove(oldNormalized)!;
    _activeSubjects[normalizedName] = displayName;
    for (var index = 0; index < _tasks.length; index++) {
      if (_tasks[index].subject == oldDisplayName) {
        _tasks[index] = _tasks[index].copyWith(subject: displayName);
      }
    }
    return true;
  }

  @override
  Future<bool> archiveSubject(String name) async {
    final normalizedName = normalizeSubjectName(name);

    if (normalizedName == normalizeSubjectName(reminderSubject)) {
      return false;
    }

    final displayName = _activeSubjects.remove(normalizedName);
    if (displayName == null) {
      return false;
    }

    _archivedSubjects[normalizedName] = displayName;
    return true;
  }

  @override
  Future<bool> restoreSubject(String name) async {
    final normalizedName = normalizeSubjectName(name);
    final displayName = _archivedSubjects.remove(normalizedName);

    if (displayName == null) {
      return false;
    }

    _activeSubjects[normalizedName] = displayName;
    return true;
  }

  @override
  Future<SubjectDeletionResult> deleteArchivedSubject(String name) async {
    final normalizedName = normalizeSubjectName(name);
    if (normalizedName == normalizeSubjectName(reminderSubject)) {
      return const SubjectDeletionResult(deleted: false);
    }

    final displayName = _archivedSubjects[normalizedName];
    if (displayName == null) {
      return const SubjectDeletionResult(deleted: false);
    }

    final taskReferences = _tasks
        .where(
          (task) =>
              normalizeSubjectName(task.subject) ==
              normalizeSubjectName(displayName),
        )
        .length;
    if (taskReferences > 0) {
      return SubjectDeletionResult(
        deleted: false,
        taskReferenceCount: taskReferences,
      );
    }

    _archivedSubjects.remove(normalizedName);
    return const SubjectDeletionResult(deleted: true);
  }

  void _seedBuiltInSubjects() {
    for (final subject in [reminderSubject, ...appSubjects]) {
      _activeSubjects[normalizeSubjectName(subject)] = subject;
    }
  }

  bool _hasSubject(String normalizedName) {
    return _activeSubjects.containsKey(normalizedName) ||
        _archivedSubjects.containsKey(normalizedName);
  }

  List<String> _sortedSubjects(Iterable<String> subjects) {
    final values = subjects.toSet();
    final sorted = <String>[
      if (values.remove(reminderSubject)) reminderSubject,
      for (final subject in appSubjects)
        if (values.remove(subject)) subject,
      ...values.toList()..sort(),
    ];
    return List.unmodifiable(sorted);
  }
}

class SqliteTaskRepository implements TaskRepository {
  SqliteTaskRepository({this.databasePath, this.databaseFactoryOverride});

  static const String _tableName = 'tasks';
  static const String _subjectsTableName = 'subjects';

  final String? databasePath;
  final DatabaseFactory? databaseFactoryOverride;
  Future<Database>? _databaseFuture;

  Future<Database> get _database {
    return _databaseFuture ??= _openDatabase();
  }

  Future<Database> _openDatabase() async {
    return openAcademicPlannerDatabase(
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
  Future<List<Task>> getTasks() async {
    final db = await _database;

    final rows = await db.query(
      _tableName,
      orderBy: '''
        CASE WHEN due_date IS NULL THEN 1 ELSE 0 END,
        due_date ASC,
        created_at DESC
      ''',
    );

    return rows.map(_taskFromMap).toList(growable: false);
  }

  @override
  Future<void> addTask(Task task) async {
    final db = await _database;

    await db.insert(_tableName, _taskToMap(task));
  }

  @override
  Future<void> updateTask(Task task) async {
    final db = await _database;

    final updatedRows = await db.update(
      _tableName,
      _taskToMap(task),
      where: 'id = ?',
      whereArgs: [task.id],
    );

    if (updatedRows == 0) {
      throw StateError('Task with ID "${task.id}" was not found.');
    }
  }

  @override
  Future<void> deleteTask(String id) async {
    final db = await _database;

    final deletedRows = await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (deletedRows == 0) {
      throw StateError('Task with ID "$id" was not found.');
    }
  }

  @override
  Future<Set<String>> deleteCompletedTasks(Set<String> ids) async {
    if (ids.isEmpty) return const {};
    final db = await _database;
    final deletedIds = <String>{};
    await db.transaction((transaction) async {
      for (final id in ids) {
        final deletedRows = await transaction.delete(
          _tableName,
          where: 'id = ? AND is_completed = 1',
          whereArgs: [id],
        );
        if (deletedRows > 0) deletedIds.add(id);
      }
    });
    return deletedIds;
  }

  @override
  Future<List<String>> getActiveSubjects() async {
    final db = await _database;
    final rows = await db.query(
      _subjectsTableName,
      columns: ['name'],
      where: 'is_archived = 0',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return _sortSubjects(rows.map((row) => row['name'] as String));
  }

  @override
  Future<List<String>> getArchivedSubjects() async {
    final db = await _database;
    final rows = await db.query(
      _subjectsTableName,
      columns: ['name'],
      where: 'is_archived = 1',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return _sortSubjects(rows.map((row) => row['name'] as String));
  }

  @override
  Future<bool> addSubject(String name) async {
    final displayName = name.trim();
    final normalizedName = normalizeSubjectName(displayName);

    if (displayName.isEmpty ||
        normalizedName == normalizeSubjectName(reminderSubject)) {
      return false;
    }

    final db = await _database;
    final rowId = await db.insert(_subjectsTableName, {
      'name': displayName,
      'normalized_name': normalizedName,
      'is_builtin': 0,
      'is_archived': 0,
      'created_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    return rowId != -1;
  }

  @override
  Future<bool> renameSubject(String oldName, String newName) async {
    final oldNormalized = normalizeSubjectName(oldName);
    final displayName = newName.trim();
    final normalizedName = normalizeSubjectName(displayName);
    if (oldNormalized == normalizeSubjectName(reminderSubject) ||
        displayName.isEmpty ||
        normalizedName == normalizeSubjectName(reminderSubject)) {
      return false;
    }

    final db = await _database;
    return db.transaction((transaction) async {
      final subject = await transaction.query(
        _subjectsTableName,
        columns: ['name'],
        where: 'normalized_name = ? AND is_archived = 0',
        whereArgs: [oldNormalized],
        limit: 1,
      );
      if (subject.isEmpty) return false;

      final conflict = await transaction.query(
        _subjectsTableName,
        columns: ['name'],
        where: 'normalized_name = ?',
        whereArgs: [normalizedName],
        limit: 1,
      );
      if (conflict.isNotEmpty) return false;

      final oldDisplayName = subject.first['name'] as String;
      await transaction.update(
        _subjectsTableName,
        {'name': displayName, 'normalized_name': normalizedName},
        where: 'normalized_name = ?',
        whereArgs: [oldNormalized],
      );
      await transaction.update(
        _tableName,
        {'subject': displayName},
        where: 'subject = ?',
        whereArgs: [oldDisplayName],
      );
      await transaction.update(
        'timetable_entries',
        {'subject': displayName},
        where: 'subject = ?',
        whereArgs: [oldDisplayName],
      );
      return true;
    });
  }

  @override
  Future<bool> archiveSubject(String name) async {
    final normalizedName = normalizeSubjectName(name);

    if (normalizedName == normalizeSubjectName(reminderSubject)) {
      return false;
    }

    final db = await _database;
    final updatedRows = await db.update(
      _subjectsTableName,
      {'is_archived': 1},
      where: 'normalized_name = ? AND is_archived = 0',
      whereArgs: [normalizedName],
    );
    return updatedRows > 0;
  }

  @override
  Future<bool> restoreSubject(String name) async {
    final db = await _database;
    final updatedRows = await db.update(
      _subjectsTableName,
      {'is_archived': 0},
      where: 'normalized_name = ? AND is_archived = 1',
      whereArgs: [normalizeSubjectName(name)],
    );
    return updatedRows > 0;
  }

  @override
  Future<SubjectDeletionResult> deleteArchivedSubject(String name) async {
    final requestedName = normalizeSubjectName(name);
    if (requestedName == normalizeSubjectName(reminderSubject)) {
      return const SubjectDeletionResult(deleted: false);
    }

    final db = await _database;
    return db.transaction((transaction) async {
      final subjects = await transaction.query(
        _subjectsTableName,
        columns: ['name', 'normalized_name'],
        where: 'normalized_name = ? AND is_archived = 1',
        whereArgs: [requestedName],
        limit: 1,
      );
      if (subjects.isEmpty) {
        return const SubjectDeletionResult(deleted: false);
      }

      final storedName = subjects.single['name'] as String;
      final normalizedStoredName = normalizeSubjectName(storedName);
      final taskRows = await transaction.query(
        _tableName,
        columns: ['subject'],
      );
      final timetableRows = await transaction.query(
        'timetable_entries',
        columns: ['subject'],
        where: 'subject IS NOT NULL',
      );
      final taskCount = taskRows
          .where(
            (row) =>
                normalizeSubjectName(row['subject'] as String) ==
                normalizedStoredName,
          )
          .length;
      final timetableCount = timetableRows
          .where(
            (row) =>
                normalizeSubjectName(row['subject'] as String) ==
                normalizedStoredName,
          )
          .length;
      if (taskCount > 0 || timetableCount > 0) {
        return SubjectDeletionResult(
          deleted: false,
          taskReferenceCount: taskCount,
          timetableReferenceCount: timetableCount,
        );
      }

      final deletedRows = await transaction.delete(
        _subjectsTableName,
        where: 'name = ? AND is_archived = 1',
        whereArgs: [storedName],
      );
      return SubjectDeletionResult(deleted: deletedRows == 1);
    });
  }

  List<String> _sortSubjects(Iterable<String> subjects) {
    final values = subjects.toSet();
    final sorted = <String>[
      if (values.remove(reminderSubject)) reminderSubject,
      for (final subject in appSubjects)
        if (values.remove(subject)) subject,
      ...values.toList()..sort(),
    ];
    return List.unmodifiable(sorted);
  }

  Map<String, Object?> _taskToMap(Task task) {
    return {
      'id': task.id,
      'title': task.title,
      'description': task.description,
      'subject': task.subject,
      'due_date': task.dueDate?.toUtc().millisecondsSinceEpoch,
      'priority': task.priority.name,
      'is_completed': task.isCompleted ? 1 : 0,
      'completed_at': task.completedAt?.toUtc().millisecondsSinceEpoch,
      'created_at': task.createdAt?.toUtc().millisecondsSinceEpoch,
      'updated_at': task.updatedAt?.toUtc().millisecondsSinceEpoch,
    };
  }

  Task _taskFromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String,
      subject: map['subject'] as String,
      dueDate: _dateTimeFromMilliseconds(map['due_date']),
      priority: TaskPriority.values.byName(map['priority'] as String),
      isCompleted: (map['is_completed'] as int) == 1,
      completedAt: _dateTimeFromMilliseconds(map['completed_at']),
      createdAt: _dateTimeFromMilliseconds(map['created_at']),
      updatedAt: _dateTimeFromMilliseconds(map['updated_at']),
    );
  }

  DateTime? _dateTimeFromMilliseconds(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.fromMillisecondsSinceEpoch(value as int, isUtc: true);
  }
}
