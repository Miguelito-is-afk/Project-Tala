import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../repositories/task_repository.dart';
import '../app/subjects.dart';
import '../services/completed_task_cleanup.dart';

enum TaskFilter { all, today, upcoming, overdue, completed }

enum TaskSortOption { dueDate, priority, recentlyAdded, oldestFirst }

class TaskViewModel extends ChangeNotifier {
  TaskViewModel({
    required this._taskRepository,
    this.onSubjectRenamed,
    this.clock = DateTime.now,
  });

  final TaskRepository _taskRepository;
  final Future<void> Function()? onSubjectRenamed;
  final DateTime Function() clock;
  CompletedTaskCleanupPolicy _completedTaskCleanupPolicy =
      CompletedTaskCleanupPolicy.never;

  List<Task> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;
  TaskFilter _selectedFilter = TaskFilter.all;
  TaskPriority? _selectedPriority;
  TaskSortOption _selectedSort = TaskSortOption.dueDate;
  String _searchQuery = '';
  String? _selectedSubject;
  List<String> _availableSubjects = [reminderSubject, ...appSubjects];
  List<String> _archivedSubjects = [];

  TaskPriority? get selectedPriority => _selectedPriority;

  TaskSortOption get selectedSort => _selectedSort;

  String? get selectedSubject => _selectedSubject;

  String get searchQuery => _searchQuery;

  List<Task> get tasks => List.unmodifiable(_tasks);

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  TaskFilter get selectedFilter => _selectedFilter;

  int get totalTaskCount => _tasks.length;

  int get completedTaskCount => _tasks.where((task) => task.isCompleted).length;

  int get incompleteTaskCount =>
      _tasks.where((task) => !task.isCompleted).length;

  List<String> get archivedSubjects => List.unmodifiable(_archivedSubjects);

  List<Task> get todayTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tasks = _tasks.where((task) {
      if (task.isCompleted || task.dueDate == null) {
        return false;
      }

      final dueDate = task.dueDate!.toLocal();
      return DateTime(dueDate.year, dueDate.month, dueDate.day) == today;
    }).toList();

    tasks.sort((first, second) {
      final dueDateComparison = _compareDueDates(first, second);
      return dueDateComparison == 0
          ? _comparePriorities(first, second)
          : dueDateComparison;
    });

    return List.unmodifiable(tasks);
  }

  int get todayTaskCount => todayTasks.length;

  int get upcomingTaskCount {
    final now = DateTime.now();
    final tomorrow = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(const Duration(days: 1));

    return _tasks.where((task) {
      if (task.isCompleted || task.dueDate == null) {
        return false;
      }

      final dueDate = task.dueDate!.toLocal();
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      return !dueDay.isBefore(tomorrow);
    }).length;
  }

  int get completedThisWeekCount {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final nextWeek = weekStart.add(const Duration(days: 7));

    return _tasks.where((task) {
      if (!task.isCompleted) {
        return false;
      }

      final completedAt = task.completedAt?.toLocal();
      if (completedAt == null) {
        return false;
      }

      return !completedAt.isBefore(weekStart) && completedAt.isBefore(nextWeek);
    }).length;
  }

  List<Task> tasksDueOn(DateTime date) {
    final selectedDay = DateTime(date.year, date.month, date.day);
    final tasks = _tasks.where((task) {
      if (task.dueDate == null) {
        return false;
      }

      final dueDate = task.dueDate!.toLocal();
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      return dueDay == selectedDay;
    }).toList();

    tasks.sort((first, second) {
      final dueDateComparison = _compareDueDates(first, second);
      return dueDateComparison == 0
          ? _comparePriorities(first, second)
          : dueDateComparison;
    });

    return List.unmodifiable(tasks);
  }

  List<String> get availableSubjects {
    final subjects = [..._availableSubjects];

    if (_selectedSubject != null &&
        _selectedSubject != reminderSubject &&
        !subjects.contains(_selectedSubject)) {
      subjects.add(_selectedSubject!);
    }

    final generalIndex = subjects.indexOf(reminderSubject);
    if (generalIndex > 0) {
      subjects.removeAt(generalIndex);
      subjects.insert(0, reminderSubject);
    }

    return List.unmodifiable(subjects);
  }

  List<Task> tasksForSubject(String subject) {
    return List.unmodifiable(_tasks.where((task) => task.subject == subject));
  }

  Task? nextDueTaskForSubject(String subject) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final tasks = _tasks.where((task) {
      if (task.subject != subject || task.isCompleted || task.dueDate == null) {
        return false;
      }

      final dueDate = task.dueDate!.toLocal();
      final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
      return !dueDay.isBefore(todayStart);
    }).toList();

    tasks.sort((first, second) {
      final dueDateComparison = _compareDueDates(first, second);
      return dueDateComparison == 0
          ? _comparePriorities(first, second)
          : dueDateComparison;
    });

    return tasks.isEmpty ? null : tasks.first;
  }

  List<Task> get filteredTasks {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    late Iterable<Task> result;

    switch (_selectedFilter) {
      case TaskFilter.all:
        result = _tasks;
        break;

      case TaskFilter.today:
        result = _tasks.where((task) {
          if (task.isCompleted || task.dueDate == null) {
            return false;
          }

          final dueDate = task.dueDate!.toLocal();
          final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

          return dueDay == today;
        });
        break;

      case TaskFilter.upcoming:
        result = _tasks.where((task) {
          if (task.isCompleted || task.dueDate == null) {
            return false;
          }

          final dueDate = task.dueDate!.toLocal();
          final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

          return !dueDay.isBefore(tomorrow);
        });
        break;

      case TaskFilter.overdue:
        result = _tasks.where((task) {
          if (task.isCompleted || task.dueDate == null) {
            return false;
          }

          final dueDate = task.dueDate!.toLocal();
          final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

          return dueDay.isBefore(today);
        });
        break;

      case TaskFilter.completed:
        result = _tasks.where((task) => task.isCompleted);
        break;
    }

    if (_selectedSubject != null) {
      result = result.where((task) {
        return task.subject == _selectedSubject;
      });
    }

    if (_selectedPriority != null) {
      result = result.where((task) {
        return task.priority == _selectedPriority;
      });
    }

    final query = _searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      result = result.where((task) {
        return task.title.toLowerCase().contains(query) ||
            task.description.toLowerCase().contains(query) ||
            task.subject.toLowerCase().contains(query);
      });
    }

    final sortedTasks = result.toList();
    sortedTasks.sort(_compareTasks);

    return List.unmodifiable(sortedTasks);
  }

  void setSubjectFilter(String? subject) {
    if (_selectedSubject == subject) {
      return;
    }

    _selectedSubject = subject;
    notifyListeners();
  }

  void clearSubjectFilter() {
    setSubjectFilter(null);
  }

  void setPriorityFilter(TaskPriority? priority) {
    if (_selectedPriority == priority) {
      return;
    }

    _selectedPriority = priority;
    notifyListeners();
  }

  void setSortOption(TaskSortOption sortOption) {
    if (_selectedSort == sortOption) {
      return;
    }

    _selectedSort = sortOption;
    notifyListeners();
  }

  void setFilter(TaskFilter filter) {
    if (_selectedFilter == filter) {
      return;
    }

    _selectedFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    final normalizedQuery = query.trim();

    if (_searchQuery == normalizedQuery) {
      return;
    }

    _searchQuery = normalizedQuery;
    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) {
      return;
    }

    _searchQuery = '';
    notifyListeners();
  }

  Future<void> load() async {
    _setLoading(true);

    try {
      _errorMessage = null;
      await _removeEligibleCompletedTasks(includeImmediate: true);
      final results = await Future.wait([
        _taskRepository.getTasks(),
        _taskRepository.getActiveSubjects(),
        _taskRepository.getArchivedSubjects(),
      ]);
      _tasks = results[0] as List<Task>;
      _availableSubjects = results[1] as List<String>;
      _archivedSubjects = results[2] as List<String>;
    } catch (error) {
      _errorMessage = 'Failed to load tasks.';
    } finally {
      _setLoading(false);
    }
  }

  void setCompletedTaskCleanupPolicy(CompletedTaskCleanupPolicy policy) {
    _completedTaskCleanupPolicy = policy;
  }

  Future<void> cleanupCompletedTasks() async {
    try {
      _errorMessage = null;
      final removed = await _removeEligibleCompletedTasks(
        includeImmediate: true,
      );
      if (removed) notifyListeners();
    } catch (error) {
      _errorMessage = 'Failed to clean up completed tasks.';
      notifyListeners();
    }
  }

  Future<bool> _removeEligibleCompletedTasks({
    bool includeImmediate = false,
    Set<String>? onlyTaskIds,
  }) async {
    final repositoryTasks = await _taskRepository.getTasks();
    final eligibleIds = completedTaskIdsEligibleForCleanup(
      repositoryTasks,
      policy: _completedTaskCleanupPolicy,
      now: clock(),
      includeImmediate: includeImmediate,
      onlyTaskIds: onlyTaskIds,
    );
    if (eligibleIds.isEmpty) return false;

    final deletedIds = await _taskRepository.deleteCompletedTasks(eligibleIds);
    if (deletedIds.isEmpty) return false;
    _tasks = [
      for (final task in _tasks)
        if (!deletedIds.contains(task.id)) task,
    ];
    return true;
  }

  Future<bool> addSubject(String name) async {
    try {
      _errorMessage = null;
      final added = await _taskRepository.addSubject(name);
      if (!added) {
        return false;
      }

      await _reloadSubjects();
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Failed to add subject.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> renameSubject(String oldName, String newName) async {
    try {
      _errorMessage = null;
      final renamed = await _taskRepository.renameSubject(oldName, newName);
      if (!renamed) {
        return false;
      }

      final displayName = newName.trim();
      _tasks = [
        for (final task in _tasks)
          task.subject == oldName ? task.copyWith(subject: displayName) : task,
      ];
      if (_selectedSubject == oldName) {
        _selectedSubject = displayName;
      }
      await _reloadSubjects();
      await onSubjectRenamed?.call();
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Failed to rename subject.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> archiveSubject(String name) async {
    try {
      _errorMessage = null;
      final archived = await _taskRepository.archiveSubject(name);
      if (!archived) {
        return false;
      }

      if (_selectedSubject == name) {
        _selectedSubject = null;
      }
      await _reloadSubjects();
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Failed to archive subject.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreSubject(String name) async {
    try {
      _errorMessage = null;
      final restored = await _taskRepository.restoreSubject(name);
      if (!restored) {
        return false;
      }

      await _reloadSubjects();
      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Failed to restore subject.';
      notifyListeners();
      return false;
    }
  }

  Future<SubjectDeletionResult> deleteArchivedSubject(String name) async {
    try {
      _errorMessage = null;
      final result = await _taskRepository.deleteArchivedSubject(name);
      if (result.deleted) {
        await _reloadSubjects();
      } else if (result.taskReferenceCount > 0 ||
          result.timetableReferenceCount > 0) {
        _errorMessage =
            'This subject is still used by ${result.taskReferenceCount} '
            'tasks and ${result.timetableReferenceCount} timetable entries.';
      } else {
        _errorMessage = 'Only existing archived subjects can be deleted.';
      }
      notifyListeners();
      return result;
    } catch (error) {
      _errorMessage = 'Failed to delete archived subject.';
      notifyListeners();
      return const SubjectDeletionResult(deleted: false);
    }
  }

  Future<void> _reloadSubjects() async {
    _availableSubjects = await _taskRepository.getActiveSubjects();
    _archivedSubjects = await _taskRepository.getArchivedSubjects();
  }

  Future<bool> addTask(Task task) async {
    try {
      _errorMessage = null;
      final normalizedTask = task.isCompleted
          ? task
          : task.copyWith(clearCompletedAt: true);
      await _taskRepository.addTask(normalizedTask);

      _tasks = [..._tasks, normalizedTask];

      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Failed to add task.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTask(Task task) async {
    final existingTask = _findTask(task.id);
    final justCompleted =
        existingTask != null && !existingTask.isCompleted && task.isCompleted;
    final normalizedTask = justCompleted
        ? task.copyWith(completedAt: clock().toUtc())
        : !task.isCompleted
        ? task.copyWith(clearCompletedAt: true)
        : task;
    var taskPersisted = false;

    try {
      _errorMessage = null;
      await _taskRepository.updateTask(normalizedTask);
      taskPersisted = true;
      _replaceTask(normalizedTask);

      if (justCompleted &&
          _completedTaskCleanupPolicy == CompletedTaskCleanupPolicy.immediate) {
        final deletedIds = await _taskRepository.deleteCompletedTasks({
          normalizedTask.id,
        });
        if (deletedIds.contains(normalizedTask.id)) {
          _tasks = [
            for (final current in _tasks)
              if (current.id != normalizedTask.id) current,
          ];
        }
      }

      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = taskPersisted
          ? 'Task was completed, but immediate cleanup failed.'
          : 'Failed to update task.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> toggleTask(String id) async {
    final task = _findTask(id);

    if (task == null) {
      _errorMessage = 'Task not found.';
      notifyListeners();
      return false;
    }

    final updatedTask = task.copyWith(
      isCompleted: !task.isCompleted,
      updatedAt: clock().toUtc(),
      clearCompletedAt: task.isCompleted,
    );

    return updateTask(updatedTask);
  }

  Future<bool> deleteTask(String id) async {
    try {
      _errorMessage = null;
      await _taskRepository.deleteTask(id);

      _tasks = [
        for (final task in _tasks)
          if (task.id != id) task,
      ];

      notifyListeners();
      return true;
    } catch (error) {
      _errorMessage = 'Failed to delete task.';
      notifyListeners();
      return false;
    }
  }

  Task? _findTask(String id) {
    for (final task in _tasks) {
      if (task.id == id) {
        return task;
      }
    }

    return null;
  }

  void _replaceTask(Task task) {
    _tasks = [
      for (final existingTask in _tasks)
        if (existingTask.id == task.id) task else existingTask,
    ];
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  int _compareTasks(Task first, Task second) {
    switch (_selectedSort) {
      case TaskSortOption.dueDate:
        final dueDateComparison = _compareDueDates(first, second);

        if (dueDateComparison != 0) {
          return dueDateComparison;
        }

        return _comparePriorities(first, second);

      case TaskSortOption.priority:
        return _comparePriorities(first, second);

      case TaskSortOption.recentlyAdded:
        return _compareNullableDates(second.createdAt, first.createdAt);

      case TaskSortOption.oldestFirst:
        return _compareNullableDates(first.createdAt, second.createdAt);
    }
  }

  int _compareDueDates(Task first, Task second) {
    if (first.dueDate == null && second.dueDate == null) {
      return 0;
    }

    if (first.dueDate == null) {
      return 1;
    }

    if (second.dueDate == null) {
      return -1;
    }

    final firstLocal = first.dueDate!.toLocal();
    final secondLocal = second.dueDate!.toLocal();
    final firstDay = DateTime(
      firstLocal.year,
      firstLocal.month,
      firstLocal.day,
    );
    final secondDay = DateTime(
      secondLocal.year,
      secondLocal.month,
      secondLocal.day,
    );

    return firstDay.compareTo(secondDay);
  }

  int _comparePriorities(Task first, Task second) {
    return second.priority.index.compareTo(first.priority.index);
  }

  int _compareNullableDates(DateTime? first, DateTime? second) {
    if (first == null && second == null) {
      return 0;
    }

    if (first == null) {
      return 1;
    }

    if (second == null) {
      return -1;
    }

    return first.compareTo(second);
  }
}
