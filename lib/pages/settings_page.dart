import 'package:flutter/material.dart';

import '../services/completed_task_cleanup.dart';
import '../services/timetable_reminder_settings.dart';
import '../view_models/task_view_model.dart';
import '../view_models/timetable_view_model.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.viewModel,
    this.taskViewModel,
    this.settingsStore,
    super.key,
  });

  final TimetableViewModel viewModel;
  final TaskViewModel? taskViewModel;
  final TimetableReminderSettingsStore? settingsStore;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TimetableReminderSettingsStore _settingsStore;
  bool _enabled = false;
  int _offsetMinutes = 15;
  CompletedTaskCleanupPolicy _completedTaskCleanupPolicy =
      CompletedTaskCleanupPolicy.never;
  bool _isLoading = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _settingsStore =
        widget.settingsStore ??
        SharedPreferencesTimetableReminderSettingsStore();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _settingsStore.load();
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _offsetMinutes = settings.offsetMinutes;
      _completedTaskCleanupPolicy = settings.completedTaskCleanupPolicy;
      _isLoading = false;
    });
    widget.taskViewModel?.setCompletedTaskCleanupPolicy(
      settings.completedTaskCleanupPolicy,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Settings',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Class reminders'),
                          subtitle: const Text(
                            'Receive reminders for class sessions only.',
                          ),
                          value: _enabled,
                          onChanged: _setEnabled,
                        ),
                        DropdownButtonFormField<int>(
                          initialValue: _offsetMinutes,
                          decoration: const InputDecoration(
                            labelText: 'Remind me before class',
                            border: OutlineInputBorder(),
                          ),
                          items: const [5, 10, 15, 30]
                              .map(
                                (minutes) => DropdownMenuItem(
                                  value: minutes,
                                  child: Text('$minutes minutes'),
                                ),
                              )
                              .toList(),
                          onChanged: _enabled
                              ? (value) {
                                  if (value != null) _setOffset(value);
                                }
                              : null,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: widget.viewModel.scheduleTestNotification,
                          icon: const Icon(Icons.notifications_outlined),
                          label: const Text('Test notification'),
                        ),
                        if (_statusMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Completed task cleanup',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<CompletedTaskCleanupPolicy>(
                          initialValue: _completedTaskCleanupPolicy,
                          decoration: const InputDecoration(
                            labelText: 'Completed task cleanup',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: CompletedTaskCleanupPolicy.never,
                              child: Text('Never'),
                            ),
                            DropdownMenuItem(
                              value: CompletedTaskCleanupPolicy.endOfDay,
                              child: Text('At the end of the day'),
                            ),
                            DropdownMenuItem(
                              value: CompletedTaskCleanupPolicy.endOfWeek,
                              child: Text('At the end of the week'),
                            ),
                            DropdownMenuItem(
                              value: CompletedTaskCleanupPolicy.immediate,
                              child: Text('Immediately'),
                            ),
                          ],
                          onChanged: _setCompletedTaskCleanupPolicy,
                        ),
                        if (_completedTaskCleanupPolicy ==
                            CompletedTaskCleanupPolicy.immediate) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Completed tasks are permanently removed '
                            'immediately.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setEnabled(bool enabled) async {
    if (enabled) {
      final granted = await widget.viewModel.requestNotificationPermissions();
      if (!granted) {
        setState(
          () => _statusMessage =
              'Notification permission, including exact alarms, is required.',
        );
        return;
      }
    }
    setState(() {
      _enabled = enabled;
      _statusMessage = null;
    });
    await _saveSettings();
  }

  Future<void> _setOffset(int offsetMinutes) async {
    setState(() => _offsetMinutes = offsetMinutes);
    await _saveSettings();
  }

  Future<void> _setCompletedTaskCleanupPolicy(
    CompletedTaskCleanupPolicy? policy,
  ) async {
    if (policy == null) return;
    setState(() => _completedTaskCleanupPolicy = policy);
    widget.taskViewModel?.setCompletedTaskCleanupPolicy(policy);
    await _saveCleanupPolicy();
    if (policy == CompletedTaskCleanupPolicy.immediate) {
      await widget.taskViewModel?.cleanupCompletedTasks();
      if (mounted && widget.taskViewModel?.errorMessage != null) {
        setState(() => _statusMessage = widget.taskViewModel!.errorMessage);
      }
    }
  }

  Future<void> _saveSettings() async {
    await _settingsStore.save(
      TimetableReminderSettings(
        enabled: _enabled,
        offsetMinutes: _offsetMinutes,
        completedTaskCleanupPolicy: _completedTaskCleanupPolicy,
      ),
    );
    await widget.viewModel.setReminderSettings(
      enabled: _enabled,
      offsetMinutes: _offsetMinutes,
    );
    if (!mounted) return;
    final error = widget.viewModel.mutationErrorMessage;
    if (error != null) setState(() => _statusMessage = error);
  }

  Future<void> _saveCleanupPolicy() {
    return _settingsStore.save(
      TimetableReminderSettings(
        enabled: _enabled,
        offsetMinutes: _offsetMinutes,
        completedTaskCleanupPolicy: _completedTaskCleanupPolicy,
      ),
    );
  }
}
