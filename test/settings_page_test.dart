import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/pages/settings_page.dart';
import 'package:academic_planner/models/timetable_entry.dart';
import 'package:academic_planner/repositories/timetable_repository.dart';
import 'package:academic_planner/services/timetable_notification_service.dart';
import 'package:academic_planner/services/timetable_reminder_settings.dart';
import 'package:academic_planner/services/completed_task_cleanup.dart';
import 'package:academic_planner/view_models/timetable_view_model.dart';

void main() {
  testWidgets('enabling reminders persists settings and supports test action', (
    tester,
  ) async {
    final store = _MemorySettingsStore();
    final notifications = _FakeNotificationService();
    final viewModel = TimetableViewModel(
      repository: InMemoryTimetableRepository(initialEntries: const []),
      notificationService: notifications,
    );
    await viewModel.load();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(viewModel: viewModel, settingsStore: store),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(viewModel.remindersEnabled, isTrue);
    expect((await store.load()).enabled, isTrue);

    await tester.tap(find.text('Remind me before class'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 minutes').last);
    await tester.pumpAndSettle();
    expect(viewModel.reminderOffsetMinutes, 30);

    await tester.tap(find.text('Test notification'));
    await tester.pumpAndSettle();
    expect(notifications.testCalls, 1);
  });

  testWidgets(
    'completed-task cleanup policy persists and warns for immediate',
    (tester) async {
      final store = _MemorySettingsStore();
      final notifications = _FakeNotificationService();
      final viewModel = TimetableViewModel(
        repository: InMemoryTimetableRepository(initialEntries: const []),
        notificationService: notifications,
      );
      await viewModel.load();

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(viewModel: viewModel, settingsStore: store),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        (await store.load()).completedTaskCleanupPolicy,
        CompletedTaskCleanupPolicy.never,
      );
      await tester.tap(
        find.byType(DropdownButtonFormField<CompletedTaskCleanupPolicy>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Immediately').last);
      await tester.pumpAndSettle();

      expect(
        (await store.load()).completedTaskCleanupPolicy,
        CompletedTaskCleanupPolicy.immediate,
      );
      expect(notifications.rescheduleCalls, 0);
      expect(notifications.cancelCalls, 0);
      expect(
        find.text('Completed tasks are permanently removed immediately.'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SettingsPage(viewModel: viewModel, settingsStore: store),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Immediately'), findsOneWidget);
    },
  );
}

class _MemorySettingsStore implements TimetableReminderSettingsStore {
  TimetableReminderSettings _settings = const TimetableReminderSettings(
    enabled: false,
    offsetMinutes: 15,
    completedTaskCleanupPolicy: CompletedTaskCleanupPolicy.never,
  );

  @override
  Future<TimetableReminderSettings> load() async => _settings;

  @override
  Future<void> save(TimetableReminderSettings settings) async {
    _settings = settings;
  }
}

class _FakeNotificationService implements TimetableNotificationService {
  int testCalls = 0;
  int rescheduleCalls = 0;
  int cancelCalls = 0;

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
  Future<void> cancelAll() async => cancelCalls++;

  @override
  Future<void> rescheduleAll(
    List<TimetableEntry> entries, {
    required int offsetMinutes,
  }) async => rescheduleCalls++;

  @override
  Future<void> scheduleTestNotification() async => testCalls++;
}
