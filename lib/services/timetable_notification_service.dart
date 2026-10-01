import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/timetable_entry.dart';

enum NotificationPermissionStatus { granted, denied, unavailable }

abstract interface class TimetableNotificationService {
  Future<void> initialize();
  Future<NotificationPermissionStatus> requestPermissions();
  Future<void> scheduleAll(
    List<TimetableEntry> entries, {
    required int offsetMinutes,
  });
  Future<void> cancelForEntry(String entryId);
  Future<void> cancelAll();
  Future<void> rescheduleAll(
    List<TimetableEntry> entries, {
    required int offsetMinutes,
  });
  Future<void> scheduleTestNotification();
}

class LocalTimetableNotificationService
    implements TimetableNotificationService {
  LocalTimetableNotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));
    final initialized = await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
        macOS: DarwinInitializationSettings(),
        linux: LinuxInitializationSettings(
          defaultActionName: 'Open notification',
        ),
        windows: WindowsInitializationSettings(
          appName: 'Academic Planner',
          appUserModelId: 'com.example.academic_planner',
          guid: 'c1f03c60-7d4b-4a72-9ed4-85a7560a4a90',
        ),
      ),
    );
    if (initialized != true) {
      throw StateError('Unable to initialize timetable notifications.');
    }
    _initialized = true;
  }

  @override
  Future<NotificationPermissionStatus> requestPermissions() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return NotificationPermissionStatus.unavailable;
    }
    final notificationsGranted =
        await android.requestNotificationsPermission() ?? false;
    if (!notificationsGranted) return NotificationPermissionStatus.denied;
    final exactGranted = await android.requestExactAlarmsPermission() ?? false;
    return exactGranted
        ? NotificationPermissionStatus.granted
        : NotificationPermissionStatus.denied;
  }

  @override
  Future<void> scheduleAll(
    List<TimetableEntry> entries, {
    required int offsetMinutes,
  }) async {
    await initialize();
    await cancelAll();
    for (final entry in entries) {
      if (entry.entryType != TimetableEntryType.classSession) continue;
      await _scheduleEntry(entry, offsetMinutes);
    }
  }

  @override
  Future<void> cancelForEntry(String entryId) async {
    await initialize();
    await _plugin.cancel(id: notificationIdForEntry(entryId));
  }

  @override
  Future<void> cancelAll() async {
    await initialize();
    await _plugin.cancelAll();
  }

  @override
  Future<void> rescheduleAll(
    List<TimetableEntry> entries, {
    required int offsetMinutes,
  }) {
    return scheduleAll(entries, offsetMinutes: offsetMinutes);
  }

  @override
  Future<void> scheduleTestNotification() async {
    await initialize();
    await _plugin.show(
      id: 0x7ffffffe,
      title: 'Academic Planner',
      body: 'Test notification received.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'timetable_class_reminders',
          'Class reminders',
          channelDescription: 'Reminders for upcoming timetable classes.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> _scheduleEntry(TimetableEntry entry, int offsetMinutes) async {
    final reminderTime = calculateTimetableReminderTime(entry, offsetMinutes);
    final reminderDay = reminderTime.weekday;
    final normalizedMinutes = reminderTime.minutes;
    final now = tz.TZDateTime.now(tz.local);
    var daysAhead = (reminderDay - now.weekday) % 7;
    final candidate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysAhead,
      normalizedMinutes ~/ 60,
      normalizedMinutes % 60,
    );
    if (!candidate.isAfter(now)) daysAhead += 7;
    final scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysAhead,
      normalizedMinutes ~/ 60,
      normalizedMinutes % 60,
    );

    await _plugin.zonedSchedule(
      id: notificationIdForEntry(entry.id),
      title: formatTimetableNotificationTitle(entry, offsetMinutes),
      body: formatTimetableNotificationBody(entry),
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'timetable_class_reminders',
          'Class reminders',
          channelDescription: 'Reminders for upcoming timetable classes.',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }
}

String formatTimetableNotificationTitle(
  TimetableEntry entry,
  int offsetMinutes,
) {
  final subject = entry.subject?.trim();
  final label = subject == null || subject.isEmpty ? entry.title : subject;
  return '$label is about to start in $offsetMinutes '
      '${offsetMinutes == 1 ? 'minute' : 'minutes'}';
}

String formatTimetableNotificationBody(TimetableEntry entry) {
  return '${_formatTimetableMinutes(entry.startMinutes)} – '
      '${_formatTimetableMinutes(entry.endMinutes)}';
}

String _formatTimetableMinutes(int minutes) {
  final hour = minutes ~/ 60;
  final displayHour = hour == 0
      ? 12
      : hour > 12
      ? hour - 12
      : hour;
  return '$displayHour:${(minutes % 60).toString().padLeft(2, '0')} '
      '${hour >= 12 ? 'PM' : 'AM'}';
}

int notificationIdForEntry(String entryId) {
  var hash = 0;
  for (final codeUnit in entryId.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return hash == 0 ? 1 : hash;
}

class TimetableReminderTime {
  const TimetableReminderTime({required this.weekday, required this.minutes});

  final int weekday;
  final int minutes;
}

TimetableReminderTime calculateTimetableReminderTime(
  TimetableEntry entry,
  int offsetMinutes,
) {
  final rawMinutes = entry.startMinutes - offsetMinutes;
  return TimetableReminderTime(
    weekday: rawMinutes < 0
        ? (entry.dayOfWeek == 1 ? 7 : entry.dayOfWeek - 1)
        : entry.dayOfWeek,
    minutes: rawMinutes < 0 ? rawMinutes + 24 * 60 : rawMinutes,
  );
}
