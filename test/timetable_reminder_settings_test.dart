import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:academic_planner/services/completed_task_cleanup.dart';
import 'package:academic_planner/services/timetable_reminder_settings.dart';

void main() {
  test('settings default to disabled with a 15-minute offset', () async {
    final store = _MemorySettingsStore();
    final settings = await store.load();

    expect(settings.enabled, isFalse);
    expect(settings.offsetMinutes, 15);
  });

  test('settings persist enabled state and offset', () async {
    final store = _MemorySettingsStore();
    await store.save(
      const TimetableReminderSettings(enabled: true, offsetMinutes: 30),
    );

    final settings = await store.load();
    expect(settings.enabled, isTrue);
    expect(settings.offsetMinutes, 30);
  });

  test('shared preferences persist completed-task cleanup policy', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesTimetableReminderSettingsStore();
    expect(
      (await store.load()).completedTaskCleanupPolicy,
      CompletedTaskCleanupPolicy.never,
    );

    await store.save(
      const TimetableReminderSettings(
        enabled: false,
        offsetMinutes: 15,
        completedTaskCleanupPolicy: CompletedTaskCleanupPolicy.endOfWeek,
      ),
    );
    expect(
      (await store.load()).completedTaskCleanupPolicy,
      CompletedTaskCleanupPolicy.endOfWeek,
    );
  });
}

class _MemorySettingsStore implements TimetableReminderSettingsStore {
  TimetableReminderSettings _settings = const TimetableReminderSettings(
    enabled: false,
    offsetMinutes: 15,
  );

  @override
  Future<TimetableReminderSettings> load() async => _settings;

  @override
  Future<void> save(TimetableReminderSettings settings) async {
    _settings = settings;
  }
}
