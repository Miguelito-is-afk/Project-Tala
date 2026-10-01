import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/models/task.dart';
import 'package:academic_planner/services/completed_task_cleanup.dart';
import 'package:academic_planner/repositories/task_repository.dart';
import 'package:academic_planner/view_models/task_view_model.dart';

void main() {
  test('Task.copyWith can set and explicitly clear completedAt', () {
    final completed = Task(
      id: 'copy',
      title: 'Copy',
      isCompleted: true,
      completedAt: DateTime.utc(2026, 9, 30),
    );

    expect(
      completed.copyWith(completedAt: DateTime.utc(2026, 10, 1)).completedAt,
      DateTime.utc(2026, 10, 1),
    );
    expect(completed.copyWith(clearCompletedAt: true).completedAt, isNull);
    expect(completed.copyWith(isCompleted: false).completedAt, isNull);
    expect(
      Task(
        id: 'incomplete',
        title: 'Incomplete',
        completedAt: DateTime.utc(2026, 9, 30),
      ).copyWith().completedAt,
      isNull,
    );
  });

  group('completed task cleanup policy', () {
    test('never and immediate policies are transition-only', () {
      final completed = _completedTask('done', DateTime(2026, 9, 21, 10));
      expect(
        completedTaskIdsEligibleForCleanup(
          [completed],
          policy: CompletedTaskCleanupPolicy.never,
          now: DateTime(2026, 9, 22),
          includeImmediate: true,
        ),
        isEmpty,
      );
      expect(
        completedTaskIdsEligibleForCleanup(
          [completed],
          policy: CompletedTaskCleanupPolicy.immediate,
          now: DateTime(2026, 9, 22),
        ),
        isEmpty,
      );
      expect(
        completedTaskIdsEligibleForCleanup(
          [completed],
          policy: CompletedTaskCleanupPolicy.immediate,
          now: DateTime(2026, 9, 22),
          includeImmediate: true,
        ),
        {'done'},
      );
    });

    test(
      'end of day retains same-day completions and removes earlier days',
      () {
        final now = DateTime(2026, 9, 22, 0, 1);
        final tasks = [
          _completedTask('same-day', DateTime(2026, 9, 22, 0)),
          _completedTask('previous-day', DateTime(2026, 9, 21, 23, 59)),
          _completedTask('unknown-time', null),
          Task(
            id: 'incomplete',
            title: 'Incomplete',
            completedAt: DateTime(2026, 9, 20),
          ),
        ];

        expect(
          completedTaskIdsEligibleForCleanup(
            tasks,
            policy: CompletedTaskCleanupPolicy.endOfDay,
            now: now,
          ),
          {'previous-day'},
        );
      },
    );

    test('end of week uses Monday and retains tasks through Sunday', () {
      final friday = DateTime(2026, 10, 2, 23);
      final sunday = DateTime(2026, 10, 4, 23);
      expect(
        completedTaskIdsEligibleForCleanup(
          [
            _completedTask('monday', DateTime(2026, 9, 28)),
            _completedTask('sunday', sunday),
            _completedTask('unknown-time', null),
          ],
          policy: CompletedTaskCleanupPolicy.endOfWeek,
          now: friday,
        ),
        isEmpty,
      );
      expect(
        completedTaskIdsEligibleForCleanup(
          [_completedTask('sunday', sunday)],
          policy: CompletedTaskCleanupPolicy.endOfWeek,
          now: DateTime(2026, 10, 5, 0, 1),
        ),
        {'sunday'},
      );
    });
  });

  group('TaskViewModel completion timestamps and cleanup', () {
    late InMemoryTaskRepository repository;

    setUp(() {
      repository = InMemoryTaskRepository();
    });

    test(
      'completion timestamps transition and remain stable on unrelated edits',
      () async {
        final completedAt = DateTime.utc(2026, 9, 30, 4, 20);
        final viewModel = TaskViewModel(
          taskRepository: repository,
          clock: () => completedAt,
        );
        await viewModel.addTask(
          Task.create(
            id: 'transition',
            title: 'Transition',
            createdAt: DateTime.utc(2026, 9, 1),
          ),
        );

        expect(await viewModel.toggleTask('transition'), isTrue);
        final completed = viewModel.tasks.single;
        expect(completed.isCompleted, isTrue);
        expect(completed.completedAt, completedAt);
        expect(completed.updatedAt, completedAt);

        final edited = completed.copyWith(title: 'Edited title');
        expect(await viewModel.updateTask(edited), isTrue);
        expect(viewModel.tasks.single.completedAt, completedAt);

        expect(await viewModel.toggleTask('transition'), isTrue);
        expect(viewModel.tasks.single.isCompleted, isFalse);
        expect(viewModel.tasks.single.completedAt, isNull);
        expect(viewModel.tasks.single.updatedAt, completedAt);
      },
    );

    test('end-of-day cleanup runs on load and resume-style cleanup', () async {
      final now = DateTime(2026, 9, 22, 0, 1);
      final viewModel = TaskViewModel(
        taskRepository: repository,
        clock: () => now,
      );
      viewModel.setCompletedTaskCleanupPolicy(
        CompletedTaskCleanupPolicy.endOfDay,
      );
      await repository.addTask(
        _completedTask('same-day', DateTime(2026, 9, 22)),
      );
      await repository.addTask(
        _completedTask('previous-day', DateTime(2026, 9, 21, 23)),
      );
      await repository.addTask(_completedTask('unknown-time', null));
      await repository.addTask(
        const Task(id: 'incomplete', title: 'Incomplete'),
      );

      await viewModel.load();
      expect(viewModel.tasks.map((task) => task.id), [
        'same-day',
        'unknown-time',
        'incomplete',
      ]);

      await repository.updateTask(
        _completedTask('same-day', DateTime(2026, 9, 21)),
      );
      await viewModel.cleanupCompletedTasks();
      expect(viewModel.tasks.map((task) => task.id), [
        'unknown-time',
        'incomplete',
      ]);
      expect((await repository.getTasks()).map((task) => task.id), [
        'unknown-time',
        'incomplete',
      ]);
    });

    test('immediate policy removes a task when it is completed', () async {
      final now = DateTime.utc(2026, 10, 1, 5);
      final viewModel = TaskViewModel(
        taskRepository: repository,
        clock: () => now,
      );
      viewModel.setCompletedTaskCleanupPolicy(
        CompletedTaskCleanupPolicy.immediate,
      );
      await viewModel.addTask(const Task(id: 'immediate', title: 'Remove me'));

      expect(await viewModel.toggleTask('immediate'), isTrue);
      expect(viewModel.tasks, isEmpty);
      expect(await repository.getTasks(), isEmpty);
    });

    test('completed-this-week requires a real completedAt value', () async {
      final now = DateTime.now();
      final viewModel = TaskViewModel(taskRepository: repository);
      await viewModel.addTask(
        Task(
          id: 'known',
          title: 'Known time',
          isCompleted: true,
          completedAt: now,
          updatedAt: now,
        ),
      );
      await viewModel.addTask(
        Task(
          id: 'unknown',
          title: 'Legacy completion',
          isCompleted: true,
          updatedAt: now,
        ),
      );

      expect(viewModel.completedThisWeekCount, 1);
    });
  });
}

Task _completedTask(String id, DateTime? completedAt) {
  return Task(id: id, title: id, isCompleted: true, completedAt: completedAt);
}
