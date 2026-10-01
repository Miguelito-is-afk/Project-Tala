import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/models/timetable_entry.dart';
import 'package:academic_planner/repositories/timetable_repository.dart';
import 'package:academic_planner/services/timetable_notification_service.dart';
import 'package:academic_planner/view_models/timetable_view_model.dart';

void main() {
  group('TimetableViewModel', () {
    test('starts with an empty, non-loading state', () {
      final viewModel = TimetableViewModel(
        repository: InMemoryTimetableRepository(initialEntries: const []),
      );

      expect(viewModel.entries, isEmpty);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.loadErrorMessage, isNull);
      expect(viewModel.mutationErrorMessage, isNull);
      expect(viewModel.selectedWeekday, inInclusiveRange(1, 5));
    });

    test('loads entries and groups them by weekday', () async {
      final viewModel = TimetableViewModel(
        repository: InMemoryTimetableRepository(
          initialEntries: [_entry('monday', 1), _entry('friday', 5)],
        ),
      );

      await viewModel.load();

      expect(viewModel.entries, hasLength(2));
      expect(viewModel.entriesForWeekday(1).single.id, 'monday');
      expect(viewModel.entriesForWeekday(5).single.id, 'friday');
      expect(viewModel.entriesForWeekday(2), isEmpty);
    });

    test('reports load errors', () async {
      final viewModel = TimetableViewModel(repository: _FailingRepository());

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.entries, isEmpty);
      expect(viewModel.loadErrorMessage, contains('load failed'));
      expect(viewModel.mutationErrorMessage, isNull);
    });

    test(
      'adds, updates, and deletes entries while preserving sort order',
      () async {
        final viewModel = TimetableViewModel(
          repository: InMemoryTimetableRepository(initialEntries: const []),
        );
        await viewModel.load();
        const added = TimetableEntry(
          id: 'added',
          title: 'Added',
          dayOfWeek: 2,
          startMinutes: 600,
          endMinutes: 660,
        );

        expect(await viewModel.addTimetableEntry(added), isTrue);
        expect(viewModel.entries.single.id, 'added');

        const updated = TimetableEntry(
          id: 'added',
          title: 'Updated',
          dayOfWeek: 1,
          startMinutes: 480,
          endMinutes: 540,
        );
        expect(await viewModel.updateTimetableEntry(updated), isTrue);
        expect(viewModel.entries.single.title, 'Updated');
        expect(await viewModel.deleteTimetableEntry('added'), isTrue);
        expect(viewModel.entries, isEmpty);
      },
    );

    test('surfaces mutation errors without changing state', () async {
      final viewModel = TimetableViewModel(repository: _FailingRepository());
      const entry = TimetableEntry(
        id: 'entry',
        title: 'Entry',
        dayOfWeek: 1,
        startMinutes: 480,
        endMinutes: 540,
      );

      expect(await viewModel.addTimetableEntry(entry), isFalse);
      expect(viewModel.entries, isEmpty);
      expect(viewModel.loadErrorMessage, isNull);
      expect(viewModel.mutationErrorMessage, contains('add failed'));
    });

    test(
      'synchronizes successful mutations when reminders are enabled',
      () async {
        final notifications = _FakeNotificationService();
        final viewModel = TimetableViewModel(
          repository: InMemoryTimetableRepository(initialEntries: const []),
          notificationService: notifications,
          remindersEnabled: true,
        );
        await viewModel.load();
        const entry = TimetableEntry(
          id: 'entry',
          title: 'Entry',
          dayOfWeek: 1,
          startMinutes: 480,
          endMinutes: 540,
        );

        expect(await viewModel.addTimetableEntry(entry), isTrue);
        expect(notifications.rescheduleCalls, 1);
        expect(notifications.lastEntries.single.id, 'entry');
      },
    );

    test(
      'notification sync failure does not undo timetable mutation',
      () async {
        final notifications = _FakeNotificationService()..shouldFail = true;
        final viewModel = TimetableViewModel(
          repository: InMemoryTimetableRepository(initialEntries: const []),
          notificationService: notifications,
          remindersEnabled: true,
        );
        await viewModel.load();
        const entry = TimetableEntry(
          id: 'entry',
          title: 'Entry',
          dayOfWeek: 1,
          startMinutes: 480,
          endMinutes: 540,
        );

        expect(await viewModel.addTimetableEntry(entry), isTrue);
        expect(viewModel.entries.single.id, 'entry');
        expect(viewModel.mutationErrorMessage, contains('sync failed'));
      },
    );

    test('supports weekday selection and returning to today', () {
      final viewModel = TimetableViewModel(
        repository: InMemoryTimetableRepository(initialEntries: const []),
      );

      viewModel.selectWeekday(3);
      expect(viewModel.selectedWeekday, 3);

      viewModel.selectWeekday(0);
      expect(viewModel.selectedWeekday, 3);

      viewModel.selectWeekday(6);
      expect(viewModel.selectedWeekday, 3);
      viewModel.selectWeekday(7);
      expect(viewModel.selectedWeekday, 3);

      viewModel.selectToday(date: DateTime(2026, 9, 21));
      expect(viewModel.selectedWeekday, 1);
      viewModel.selectToday(date: DateTime(2026, 9, 26));
      expect(viewModel.selectedWeekday, 5);
      viewModel.selectToday(date: DateTime(2026, 9, 27));
      expect(viewModel.selectedWeekday, 5);
    });
  });
}

TimetableEntry _entry(String id, int dayOfWeek) {
  return TimetableEntry(
    id: id,
    title: id,
    dayOfWeek: dayOfWeek,
    startMinutes: 450,
    endMinutes: 500,
  );
}

class _FailingRepository implements TimetableRepository {
  @override
  Future<void> addTimetableEntry(TimetableEntry entry) {
    return Future.error(StateError('add failed'));
  }

  @override
  Future<void> deleteTimetableEntry(String id) {
    return Future.error(StateError('delete failed'));
  }

  @override
  Future<List<TimetableEntry>> getTimetableEntries() {
    return Future.error(StateError('load failed'));
  }

  @override
  Future<void> updateTimetableEntry(TimetableEntry entry) {
    return Future.error(StateError('update failed'));
  }
}

class _FakeNotificationService implements TimetableNotificationService {
  bool shouldFail = false;
  int rescheduleCalls = 0;
  List<TimetableEntry> lastEntries = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionStatus> requestPermissions() async =>
      NotificationPermissionStatus.granted;

  @override
  Future<void> scheduleAll(
    List<TimetableEntry> entries, {
    required int offsetMinutes,
  }) async {}

  @override
  Future<void> cancelForEntry(String entryId) async {}

  @override
  Future<void> cancelAll() async {}

  @override
  Future<void> rescheduleAll(
    List<TimetableEntry> entries, {
    required int offsetMinutes,
  }) async {
    rescheduleCalls++;
    lastEntries = entries;
    if (shouldFail) throw StateError('sync failed');
  }

  @override
  Future<void> scheduleTestNotification() async {}
}
