import 'package:flutter/foundation.dart';

import '../models/timetable_entry.dart';
import '../repositories/timetable_repository.dart';
import '../services/timetable_notification_service.dart';

class TimetableViewModel extends ChangeNotifier {
  TimetableViewModel({
    required this.repository,
    this.notificationService,
    this.remindersEnabled = false,
    this.reminderOffsetMinutes = 15,
  }) : _selectedWeekday = _weekdayForToday();

  final TimetableRepository repository;
  final TimetableNotificationService? notificationService;

  List<TimetableEntry> _entries = [];
  bool _isLoading = false;
  String? _loadErrorMessage;
  String? _mutationErrorMessage;
  int _selectedWeekday;
  bool remindersEnabled;
  int reminderOffsetMinutes;

  List<TimetableEntry> get entries => List.unmodifiable(_entries);

  bool get isLoading => _isLoading;

  String? get loadErrorMessage => _loadErrorMessage;

  String? get mutationErrorMessage => _mutationErrorMessage;

  int get selectedWeekday => _selectedWeekday;

  List<TimetableEntry> entriesForWeekday(int weekday) {
    return List.unmodifiable(
      _entries.where((entry) => entry.dayOfWeek == weekday),
    );
  }

  Future<void> load() async {
    _isLoading = true;
    _loadErrorMessage = null;
    notifyListeners();

    try {
      _entries = await repository.getTimetableEntries();
    } catch (error) {
      _loadErrorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addTimetableEntry(TimetableEntry entry) async {
    return _mutate(() async {
      await repository.addTimetableEntry(entry);
      _entries = [..._entries, entry]..sort(_compareEntries);
      await _syncNotifications();
    });
  }

  Future<bool> updateTimetableEntry(TimetableEntry entry) async {
    return _mutate(() async {
      await repository.updateTimetableEntry(entry);
      final index = _entries.indexWhere((existing) => existing.id == entry.id);
      if (index == -1) {
        _entries = [..._entries, entry];
      } else {
        _entries[index] = entry;
      }
      _entries.sort(_compareEntries);
      await _syncNotifications();
    });
  }

  Future<bool> deleteTimetableEntry(String id) async {
    return _mutate(() async {
      await repository.deleteTimetableEntry(id);
      _entries = _entries.where((entry) => entry.id != id).toList();
      await _syncNotifications();
    });
  }

  Future<void> setReminderSettings({
    required bool enabled,
    required int offsetMinutes,
  }) async {
    remindersEnabled = enabled;
    reminderOffsetMinutes = offsetMinutes;
    _mutationErrorMessage = null;
    notifyListeners();
    if (notificationService == null) return;
    try {
      if (enabled) {
        await notificationService!.rescheduleAll(
          _entries,
          offsetMinutes: offsetMinutes,
        );
      } else {
        await notificationService!.cancelAll();
      }
    } catch (error) {
      _mutationErrorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<bool> requestNotificationPermissions() async {
    if (notificationService == null) return false;
    try {
      final status = await notificationService!.requestPermissions();
      return status == NotificationPermissionStatus.granted;
    } catch (error) {
      _mutationErrorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> scheduleTestNotification() async {
    if (notificationService == null) return false;
    try {
      await notificationService!.scheduleTestNotification();
      return true;
    } catch (error) {
      _mutationErrorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> _syncNotifications() async {
    if (!remindersEnabled || notificationService == null) return;
    try {
      await notificationService!.rescheduleAll(
        _entries,
        offsetMinutes: reminderOffsetMinutes,
      );
    } catch (error) {
      _mutationErrorMessage = error.toString();
    }
  }

  Future<bool> _mutate(Future<void> Function() mutation) async {
    _mutationErrorMessage = null;
    try {
      await mutation();
      notifyListeners();
      return true;
    } catch (error) {
      _mutationErrorMessage = error.toString();
      notifyListeners();
      return false;
    }
  }

  void selectWeekday(int weekday) {
    if (weekday < 1 || weekday > 5 || weekday == _selectedWeekday) {
      return;
    }

    _selectedWeekday = weekday;
    notifyListeners();
  }

  void selectToday({DateTime? date}) {
    selectWeekday(_weekdayForToday(date));
  }

  static int _weekdayForToday([DateTime? date]) {
    final weekday = (date ?? DateTime.now()).weekday;
    return weekday > 5 ? 5 : weekday;
  }
}

int _compareEntries(TimetableEntry first, TimetableEntry second) {
  final dayComparison = first.dayOfWeek.compareTo(second.dayOfWeek);
  return dayComparison == 0
      ? first.startMinutes.compareTo(second.startMinutes)
      : dayComparison;
}
