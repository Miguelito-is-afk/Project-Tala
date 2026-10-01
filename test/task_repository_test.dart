import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/app/subjects.dart';
import 'package:academic_planner/models/task.dart';
import 'package:academic_planner/repositories/task_repository.dart';

void main() {
  group('InMemoryTaskRepository', () {
    late InMemoryTaskRepository repository;

    setUp(() {
      repository = InMemoryTaskRepository();
    });

    test('starts with no tasks', () async {
      final tasks = await repository.getTasks();

      expect(tasks, isEmpty);
    });

    test('can add a task', () async {
      const task = Task(id: '1', title: 'Finish Biology', subject: 'Biology');

      await repository.addTask(task);

      final tasks = await repository.getTasks();

      expect(tasks, hasLength(1));
      expect(tasks.first.id, '1');
      expect(tasks.first.title, 'Finish Biology');
    });

    test('prevents duplicate task IDs', () async {
      const firstTask = Task(id: '1', title: 'First task');

      const secondTask = Task(id: '1', title: 'Second task');

      await repository.addTask(firstTask);

      expect(() => repository.addTask(secondTask), throwsA(isA<StateError>()));
    });

    test('can update a task', () async {
      const originalTask = Task(id: '1', title: 'Study Biology');

      const updatedTask = Task(id: '1', title: 'Study Biology Chapter 4');

      await repository.addTask(originalTask);
      await repository.updateTask(updatedTask);

      final tasks = await repository.getTasks();

      expect(tasks, hasLength(1));
      expect(tasks.first.title, 'Study Biology Chapter 4');
    });

    test('can delete a task', () async {
      const task = Task(id: '1', title: 'Finish homework');

      await repository.addTask(task);
      await repository.deleteTask('1');

      final tasks = await repository.getTasks();

      expect(tasks, isEmpty);
    });

    test('cannot update a task that does not exist', () async {
      const task = Task(id: '999', title: 'Does not exist');

      expect(() => repository.updateTask(task), throwsA(isA<StateError>()));
    });

    test('cannot delete a task that does not exist', () async {
      expect(() => repository.deleteTask('999'), throwsA(isA<StateError>()));
    });

    test('seeds built-in subjects on every initialization', () async {
      final firstSubjects = await repository.getActiveSubjects();
      final secondRepository = InMemoryTaskRepository();

      expect(firstSubjects, containsAll([reminderSubject, ...appSubjects]));
      expect(await secondRepository.getActiveSubjects(), firstSubjects);
    });

    test('orders current built-in subjects before custom subjects', () async {
      await repository.addSubject('Zeta Custom');
      await repository.addSubject('Alpha Custom');

      expect(await repository.getActiveSubjects(), [
        reminderSubject,
        ...appSubjects,
        'Alpha Custom',
        'Zeta Custom',
      ]);
    });

    test('creates custom subjects and rejects invalid duplicates', () async {
      expect(await repository.addSubject(' Economics '), isTrue);
      expect(await repository.addSubject('economics'), isFalse);
      expect(await repository.addSubject('   '), isFalse);
      expect(await repository.addSubject('general'), isFalse);
      expect(await repository.getActiveSubjects(), contains('Economics'));
    });

    test('archives and restores subjects without changing tasks', () async {
      const task = Task(
        id: 'biology-task',
        title: 'Mathematics task',
        subject: 'Mathematics 5 Level 1',
      );
      await repository.addTask(task);

      expect(await repository.archiveSubject('Mathematics 5 Level 1'), isTrue);
      expect(
        await repository.getActiveSubjects(),
        isNot(contains('Mathematics 5 Level 1')),
      );
      expect(
        await repository.getArchivedSubjects(),
        contains('Mathematics 5 Level 1'),
      );
      expect(
        (await repository.getTasks()).single.subject,
        'Mathematics 5 Level 1',
      );

      expect(await repository.addSubject('mathematics 5 level 1'), isFalse);
      expect(await repository.restoreSubject('Mathematics 5 Level 1'), isTrue);
      expect(
        await repository.getActiveSubjects(),
        contains('Mathematics 5 Level 1'),
      );
    });

    test('does not archive General', () async {
      expect(await repository.archiveSubject('general'), isFalse);
      expect(await repository.getActiveSubjects(), contains(reminderSubject));
    });

    test('permanently deletes only unused archived subjects', () async {
      await repository.addSubject('Unused Subject');
      await repository.archiveSubject('Unused Subject');

      expect(
        (await repository.deleteArchivedSubject('Unused Subject')).deleted,
        isTrue,
      );
      expect(
        await repository.getArchivedSubjects(),
        isNot(contains('Unused Subject')),
      );
      expect(
        (await repository.deleteArchivedSubject('Mathematics 5 Level 1'))
            .deleted,
        isFalse,
      );
      expect(
        (await repository.deleteArchivedSubject(reminderSubject)).deleted,
        isFalse,
      );
      expect(
        (await repository.deleteArchivedSubject('Missing Subject')).deleted,
        isFalse,
      );
    });

    test('blocks deleting archived subjects referenced by tasks', () async {
      await repository.addSubject('Referenced Subject');
      await repository.archiveSubject('Referenced Subject');
      await repository.addTask(
        const Task(
          id: 'referenced',
          title: 'Preserve',
          subject: 'Referenced Subject',
        ),
      );

      final result = await repository.deleteArchivedSubject(
        'Referenced Subject',
      );
      expect(result.deleted, isFalse);
      expect(result.taskReferenceCount, 1);
      expect(
        await repository.getArchivedSubjects(),
        contains('Referenced Subject'),
      );
      expect((await repository.getTasks()).single.id, 'referenced');
    });

    test('renames an active subject and updates matching tasks', () async {
      await repository.addTask(
        const Task(
          id: 'biology-task',
          title: 'Lab',
          subject: 'Mathematics 5 Level 1',
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
      expect((await repository.getTasks()).single.subject, 'Natural Science');
    });

    test('rejects invalid subject renames', () async {
      expect(
        await repository.renameSubject('Mathematics 5 Level 1', '  '),
        isFalse,
      );
      expect(
        await repository.renameSubject('Mathematics 5 Level 1', 'general'),
        isFalse,
      );
      expect(
        await repository.renameSubject(
          'Mathematics 5 Level 1',
          'social science 5',
        ),
        isFalse,
      );
      expect(await repository.renameSubject('General', 'Reminder'), isFalse);
    });
  });
}
