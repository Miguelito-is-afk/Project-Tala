import 'package:shared_preferences/shared_preferences.dart';

import 'completed_task_cleanup.dart';

class TimetableReminderSettings {
  const TimetableReminderSettings({
    required this.enabled,
    required this.offsetMinutes,
    this.completedTaskCleanupPolicy = CompletedTaskCleanupPolicy.never,
  });

  final bool enabled;
  final int offsetMinutes;
  final CompletedTaskCleanupPolicy completedTaskCleanupPolicy;
}

abstract interface class TimetableReminderSettingsStore {
  Future<TimetableReminderSettings> load();
  Future<void> save(TimetableReminderSettings settings);
}

class SharedPreferencesTimetableReminderSettingsStore
    implements TimetableReminderSettingsStore {
  static const _enabledKey = 'timetable_reminders_enabled';
  static const _offsetKey = 'timetable_reminder_offset_minutes';
  static const _completedTaskCleanupKey = 'completed_task_cleanup_policy';

  @override
  Future<TimetableReminderSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedCleanupPolicy = preferences.getString(_completedTaskCleanupKey);
    return TimetableReminderSettings(
      enabled: preferences.getBool(_enabledKey) ?? false,
      offsetMinutes: preferences.getInt(_offsetKey) ?? 15,
      completedTaskCleanupPolicy: CompletedTaskCleanupPolicy.values.firstWhere(
        (policy) => policy.name == savedCleanupPolicy,
        orElse: () => CompletedTaskCleanupPolicy.never,
      ),
    );
  }

  @override
  Future<void> save(TimetableReminderSettings settings) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, settings.enabled);
    await preferences.setInt(_offsetKey, settings.offsetMinutes);
    await preferences.setString(
      _completedTaskCleanupKey,
      settings.completedTaskCleanupPolicy.name,
    );
  }
}
