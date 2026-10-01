import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:academic_planner/main.dart';
import 'package:academic_planner/models/timetable_entry.dart';
import 'package:academic_planner/repositories/task_repository.dart';
import 'package:academic_planner/repositories/timetable_repository.dart';
import 'package:academic_planner/services/timetable_notification_service.dart';
import 'package:academic_planner/services/timetable_reminder_settings.dart';

void main() {
  testWidgets('restores enabled settings and reschedules on startup', (
    tester,
  ) async {
    final notifications = _FakeNotificationService();
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          taskRepository: InMemoryTaskRepository(),
          timetableRepository: InMemoryTimetableRepository(
            initialEntries: const [_entry],
          ),
          notificationService: notifications,
          settingsStore: _MemorySettingsStore(
            const TimetableReminderSettings(enabled: true, offsetMinutes: 10),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(notifications.rescheduleCalls, 1);
    expect(notifications.lastOffsetMinutes, 10);
    expect(notifications.requestPermissionCalls, 0);
  });

  testWidgets('keeps disabled settings disabled without scheduling', (
    tester,
  ) async {
    final notifications = _FakeNotificationService();
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          taskRepository: InMemoryTaskRepository(),
          timetableRepository: InMemoryTimetableRepository(
            initialEntries: const [_entry],
          ),
          notificationService: notifications,
          settingsStore: _MemorySettingsStore(
            const TimetableReminderSettings(enabled: false, offsetMinutes: 15),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(notifications.rescheduleCalls, 0);
    expect(notifications.requestPermissionCalls, 0);
  });

  testWidgets('rescheduling failure does not prevent startup', (tester) async {
    final notifications = _FakeNotificationService()..shouldFail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: AppShell(
          taskRepository: InMemoryTaskRepository(),
          timetableRepository: InMemoryTimetableRepository(
            initialEntries: const [_entry],
          ),
          notificationService: notifications,
          settingsStore: _MemorySettingsStore(
            const TimetableReminderSettings(enabled: true, offsetMinutes: 15),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good day 👋'), findsOneWidget);
    expect(notifications.requestPermissionCalls, 0);
  });
}

const _entry = TimetableEntry(
  id: 'startup-class',
  title: 'Startup class',
  dayOfWeek: 1,
  startMinutes: 600,
  endMinutes: 660,
);

class _MemorySettingsStore implements TimetableReminderSettingsStore {
  _MemorySettingsStore(this.settings);

  final TimetableReminderSettings settings;

  @override
  Future<TimetableReminderSettings> load() async => settings;

  @override
  Future<void> save(TimetableReminderSettings settings) async {}
}

class _FakeNotificationService implements TimetableNotificationService {
  bool shouldFail = false;
  int rescheduleCalls = 0;
  int requestPermissionCalls = 0;
  int? lastOffsetMinutes;

  @override
  Future<void> initialize() async {}

  @override
  Future<NotificationPermissionStatus> requestPermissions() async {
    requestPermissionCalls++;
    return NotificationPermissionStatus.granted;
  }

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
    lastOffsetMinutes = offsetMinutes;
    if (shouldFail) throw StateError('startup sync failed');
  }

  @override
  Future<void> scheduleTestNotification() async {}
}
