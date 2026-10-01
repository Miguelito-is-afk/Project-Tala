import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/models/task.dart';
import 'package:academic_planner/repositories/task_repository.dart';
import 'package:academic_planner/view_models/task_view_model.dart';

void main() {
  group('TaskViewModel', () {
    late InMemoryTaskRepository repository;
    late TaskViewModel viewModel;

    setUp(() {
      repository = InMemoryTaskRepository();

      viewModel = TaskViewModel(taskRepository: repository);
    });

    test('starts with an empty task list', () {
      expect(viewModel.tasks, isEmpty);
      expect(viewModel.totalTaskCount, 0);
      expect(viewModel.completedTaskCount, 0);
      expect(viewModel.incompleteTaskCount, 0);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('loads tasks from repository', () async {
      const task = Task(id: '1', title: 'Study Biology', subject: 'Biology');

      await repository.addTask(task);

      await viewModel.load();

      expect(viewModel.tasks, hasLength(1));
      expect(viewModel.tasks.first.title, 'Study Biology');
    });

    test('adds a task', () async {
      const task = Task(id: '1', title: 'Finish Physics', subject: 'Physics');

      final result = await viewModel.addTask(task);

      expect(result, isTrue);
      expect(viewModel.tasks, hasLength(1));
      expect(viewModel.tasks.first.title, 'Finish Physics');
    });

    test('updates a task', () async {
      const originalTask = Task(id: '1', title: 'Study Math');

      const updatedTask = Task(id: '1', title: 'Study Math - Conic Sections');

      await viewModel.addTask(originalTask);

      final result = await viewModel.updateTask(updatedTask);

      expect(result, isTrue);
      expect(viewModel.tasks.first.title, 'Study Math - Conic Sections');
    });

    test('toggles task completion', () async {
      const task = Task(id: '1', title: 'Review Biology');

      await viewModel.addTask(task);

      expect(viewModel.tasks.first.isCompleted, isFalse);

      final result = await viewModel.toggleTask('1');

      expect(result, isTrue);
      expect(viewModel.tasks.first.isCompleted, isTrue);

      await viewModel.toggleTask('1');

      expect(viewModel.tasks.first.isCompleted, isFalse);
    });

    test('deletes a task', () async {
      const task = Task(id: '1', title: 'Delete me');

      await viewModel.addTask(task);

      expect(viewModel.tasks, hasLength(1));

      final result = await viewModel.deleteTask('1');

      expect(result, isTrue);
      expect(viewModel.tasks, isEmpty);
    });

    test('tracks completed and incomplete task counts', () async {
      const completedTask = Task(
        id: '1',
        title: 'Completed task',
        isCompleted: true,
      );

      const incompleteTask = Task(id: '2', title: 'Incomplete task');

      await viewModel.addTask(completedTask);
      await viewModel.addTask(incompleteTask);

      expect(viewModel.totalTaskCount, 2);
      expect(viewModel.completedTaskCount, 1);
      expect(viewModel.incompleteTaskCount, 1);
    });

    test('provides dashboard task counts and today tasks', () async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      await viewModel.addTask(
        Task(id: 'today', title: 'Today task', dueDate: today),
      );
      await viewModel.addTask(
        Task(
          id: 'completed-today',
          title: 'Completed today',
          dueDate: today,
          isCompleted: true,
          completedAt: now,
          updatedAt: now.toUtc(),
        ),
      );
      await viewModel.addTask(
        Task(
          id: 'upcoming',
          title: 'Upcoming task',
          dueDate: today.add(const Duration(days: 1)),
        ),
      );

      expect(viewModel.todayTaskCount, 1);
      expect(viewModel.todayTasks.single.id, 'today');
      expect(viewModel.upcomingTaskCount, 1);
      expect(viewModel.completedThisWeekCount, 1);
    });

    test('groups calendar tasks by local due date', () async {
      final now = DateTime.now();
      final selectedDay = DateTime(now.year, now.month, now.day);

      await viewModel.addTask(
        Task(
          id: 'first',
          title: 'First task',
          dueDate: selectedDay.add(const Duration(hours: 9)),
        ),
      );
      await viewModel.addTask(
        Task(
          id: 'second',
          title: 'Second task',
          dueDate: selectedDay.add(const Duration(hours: 15)),
        ),
      );
      await viewModel.addTask(const Task(id: 'no-date', title: 'No due date'));

      expect(viewModel.tasksDueOn(selectedDay).map((task) => task.id), [
        'first',
        'second',
      ]);
      expect(
        viewModel.tasksDueOn(selectedDay.add(const Duration(days: 1))),
        isEmpty,
      );
    });

    test('provides subject task statistics and next due task', () async {
      final today = DateTime.now();

      await viewModel.addTask(
        Task(
          id: 'open',
          title: 'Open Mathematics',
          subject: 'Mathematics 5 Level 1',
          dueDate: today.add(const Duration(days: 2)),
        ),
      );
      await viewModel.addTask(
        const Task(
          id: 'done',
          title: 'Done Mathematics',
          subject: 'Mathematics 5 Level 1',
          isCompleted: true,
        ),
      );
      await viewModel.addTask(
        const Task(id: 'physics', title: 'Physics', subject: 'Physics'),
      );

      expect(viewModel.availableSubjects, contains('Mathematics 5 Level 1'));
      expect(viewModel.tasksForSubject('Mathematics 5 Level 1'), hasLength(2));
      expect(
        viewModel.nextDueTaskForSubject('Mathematics 5 Level 1')?.id,
        'open',
      );
      expect(viewModel.tasksForSubject('Chemistry'), isEmpty);
      expect(viewModel.nextDueTaskForSubject('Chemistry'), isNull);
    });

    test(
      'loads persistent subjects and preserves legacy task subjects',
      () async {
        await repository.addTask(
          const Task(id: 'legacy', title: 'Legacy', subject: 'Grade 11'),
        );
        await repository.addSubject('Economics');

        await viewModel.load();

        expect(viewModel.availableSubjects, contains('Economics'));
        expect(viewModel.availableSubjects, isNot(contains('Grade 11')));

        viewModel.setSubjectFilter('Grade 11');
        expect(viewModel.availableSubjects, contains('Grade 11'));
        expect(viewModel.filteredTasks.single.id, 'legacy');
      },
    );

    test(
      'adds, archives, and restores subjects through the ViewModel',
      () async {
        expect(await viewModel.addSubject('Economics'), isTrue);
        expect(viewModel.availableSubjects, contains('Economics'));

        expect(await viewModel.archiveSubject('Economics'), isTrue);
        expect(viewModel.availableSubjects, isNot(contains('Economics')));
        expect(viewModel.archivedSubjects, contains('Economics'));

        expect(await viewModel.restoreSubject('Economics'), isTrue);
        expect(viewModel.availableSubjects, contains('Economics'));
      },
    );

    test(
      'deletes an unused archived subject and reports blocked references',
      () async {
        await viewModel.addSubject('Unused Subject');
        expect(await viewModel.archiveSubject('Unused Subject'), isTrue);
        final deleted = await viewModel.deleteArchivedSubject('Unused Subject');
        expect(deleted.deleted, isTrue);
        expect(viewModel.archivedSubjects, isNot(contains('Unused Subject')));

        await viewModel.addSubject('Referenced Subject');
        await viewModel.archiveSubject('Referenced Subject');
        await repository.addTask(
          const Task(
            id: 'subject-reference',
            title: 'Preserve',
            subject: 'Referenced Subject',
          ),
        );
        final blocked = await viewModel.deleteArchivedSubject(
          'Referenced Subject',
        );
        expect(blocked.deleted, isFalse);
        expect(blocked.taskReferenceCount, 1);
        expect(viewModel.archivedSubjects, contains('Referenced Subject'));
        expect(viewModel.errorMessage, contains('1 tasks'));
        expect(viewModel.tasks, isEmpty);
        expect((await repository.getTasks()).single.id, 'subject-reference');
      },
    );

    test('renames a subject and refreshes dependent state', () async {
      await viewModel.addTask(
        const Task(
          id: 'biology-task',
          title: 'Lab',
          subject: 'Mathematics 5 Level 1',
        ),
      );
      await viewModel.load();
      var reloaded = false;
      viewModel = TaskViewModel(
        taskRepository: repository,
        onSubjectRenamed: () async => reloaded = true,
      );
      await viewModel.load();

      expect(
        await viewModel.renameSubject(
          'Mathematics 5 Level 1',
          'Natural Science',
        ),
        isTrue,
      );
      expect(viewModel.availableSubjects, contains('Natural Science'));
      expect(viewModel.tasks.single.subject, 'Natural Science');
      expect(reloaded, isTrue);
    });

    test('filters tasks by priority with existing filters', () async {
      await viewModel.addTask(
        const Task(
          id: '1',
          title: 'High Biology',
          subject: 'Biology',
          priority: TaskPriority.high,
        ),
      );
      await viewModel.addTask(
        const Task(
          id: '2',
          title: 'Low Biology',
          subject: 'Biology',
          priority: TaskPriority.low,
        ),
      );
      await viewModel.addTask(
        const Task(
          id: '3',
          title: 'High Physics',
          subject: 'Physics',
          priority: TaskPriority.high,
        ),
      );

      viewModel.setPriorityFilter(TaskPriority.high);
      viewModel.setSubjectFilter('Biology');
      viewModel.setSearchQuery('biology');

      expect(viewModel.filteredTasks, hasLength(1));
      expect(viewModel.filteredTasks.single.id, '1');
    });

    test(
      'sorts due dates with overdue, today, future, and no due date',
      () async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        await viewModel.addTask(
          Task(
            id: 'future',
            title: 'Future',
            dueDate: today.add(const Duration(days: 2)),
          ),
        );
        await viewModel.addTask(Task(id: 'none', title: 'No due date'));
        await viewModel.addTask(
          Task(id: 'today', title: 'Today', dueDate: today),
        );
        await viewModel.addTask(
          Task(
            id: 'overdue',
            title: 'Overdue',
            dueDate: today.subtract(const Duration(days: 1)),
          ),
        );

        expect(viewModel.filteredTasks.map((task) => task.id), [
          'overdue',
          'today',
          'future',
          'none',
        ]);
      },
    );

    test('uses priority as a due-date tie-breaker', () async {
      final dueDate = DateTime.now();

      await viewModel.addTask(
        Task(
          id: 'low',
          title: 'Low',
          dueDate: dueDate,
          priority: TaskPriority.low,
        ),
      );
      await viewModel.addTask(
        Task(
          id: 'high',
          title: 'High',
          dueDate: dueDate,
          priority: TaskPriority.high,
        ),
      );
      await viewModel.addTask(
        Task(
          id: 'medium',
          title: 'Medium',
          dueDate: dueDate,
          priority: TaskPriority.medium,
        ),
      );

      expect(viewModel.filteredTasks.map((task) => task.id), [
        'high',
        'medium',
        'low',
      ]);
    });

    test('sorts by priority, recently added, and oldest first', () async {
      final oldest = DateTime.utc(2026, 1, 1);
      final newest = DateTime.utc(2026, 1, 3);

      await viewModel.addTask(
        Task(
          id: 'old-high',
          title: 'Old high',
          priority: TaskPriority.high,
          createdAt: oldest,
        ),
      );
      await viewModel.addTask(
        Task(
          id: 'new-low',
          title: 'New low',
          priority: TaskPriority.low,
          createdAt: newest,
        ),
      );

      viewModel.setSortOption(TaskSortOption.priority);
      expect(viewModel.filteredTasks.map((task) => task.id), [
        'old-high',
        'new-low',
      ]);

      viewModel.setSortOption(TaskSortOption.recentlyAdded);
      expect(viewModel.filteredTasks.map((task) => task.id), [
        'new-low',
        'old-high',
      ]);

      viewModel.setSortOption(TaskSortOption.oldestFirst);
      expect(viewModel.filteredTasks.map((task) => task.id), [
        'old-high',
        'new-low',
      ]);
    });

    test('sorts after applying existing filters', () async {
      final today = DateTime.now();
      final subject = 'Biology';

      await viewModel.addTask(
        Task(
          id: 'matching-later',
          title: 'Biology review',
          subject: subject,
          priority: TaskPriority.high,
          isCompleted: true,
          dueDate: today.add(const Duration(days: 2)),
        ),
      );
      await viewModel.addTask(
        Task(
          id: 'matching-sooner',
          title: 'Biology notes',
          subject: subject,
          priority: TaskPriority.high,
          isCompleted: true,
          dueDate: today,
        ),
      );
      await viewModel.addTask(
        Task(
          id: 'wrong-subject',
          title: 'Biology notes',
          subject: 'Physics',
          isCompleted: true,
          dueDate: today.subtract(const Duration(days: 1)),
        ),
      );

      viewModel.setFilter(TaskFilter.completed);
      viewModel.setSubjectFilter(subject);
      viewModel.setPriorityFilter(TaskPriority.high);
      viewModel.setSearchQuery('biology');

      expect(viewModel.filteredTasks.map((task) => task.id), [
        'matching-sooner',
        'matching-later',
      ]);
    });
  });
}
