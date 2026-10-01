# Copilot instructions for `academic_planner`

## Project overview

This is a Flutter application targeting mobile, desktop, and web. The currently implemented feature is task planning; Calendar, Subjects, and Settings are navigation placeholders. The app uses Material 3 and switches between bottom navigation on narrow screens and a navigation rail on wider screens.

## Build, test, and lint commands

Run commands from the repository root:

```powershell
# Fetch/update Dart dependencies
flutter pub get

# Static analysis and lint checks
flutter analyze

# Format Dart source
dart format lib test

# Run the complete test suite
flutter test

# Run one test file
flutter test test/task_view_model_test.dart

# Run one named test or group by substring
flutter test test/task_view_model_test.dart --plain-name "toggles task completion"

# Run the app on an available device
flutter run

# Build an Android debug APK
flutter build apk --debug
```

The configured analyzer includes `package:flutter_lints/flutter.yaml` from [analysis_options.yaml](../analysis_options.yaml). Keep generated platform and build output out of source changes; the analyzer already excludes those directories.

## Architecture

- [main.dart](../lib/main.dart) is the composition root. It creates the repository, loads the view model, owns the app shell/navigation, and selects responsive layouts.
- [Task](../lib/models/task.dart) is an immutable domain model. `Task.create` is the normal constructor for new application tasks because it assigns UTC creation/update timestamps; `copyWith` is used for edits and completion changes.
- [TaskRepository](../lib/repositories/task_repository.dart) is the persistence boundary. `SqliteTaskRepository` stores tasks in SQLite on Android, iOS, and macOS. Web, Windows, Linux, and Fuchsia use `InMemoryTaskRepository` through `createTaskRepository()`. Preserve this interface when adding persistence or tests.
- [TaskViewModel](../lib/view_models/task_view_model.dart) is a `ChangeNotifier` application state layer. It loads and mutates repository data, exposes counts, applies status/search/subject filters, and reports user-facing error state.
- [TasksPage](../lib/pages/tasks_page.dart) observes the view model with `AnimatedBuilder` and contains task-list presentation and user actions. [TaskEditorDialog](../lib/pages/task_editor_dialog.dart) owns form state and returns a new or edited `Task`; persistence remains in the view model.
- [subjects.dart](../lib/app/subjects.dart) is the shared source for built-in subjects and the special `General`/custom-subject values. Use these constants rather than duplicating subject strings.

## Repository-specific conventions

- Keep domain and persistence code separate: widgets should not call SQLite directly, and repository implementations should not contain UI concerns.
- Use immutable task updates. Do not mutate a `Task` in place; create a replacement with `copyWith`, including a fresh `updatedAt` timestamp for edits and completion toggles.
- Normalize persisted timestamps as UTC milliseconds since epoch. Convert due dates to local calendar dates only when presenting or evaluating Today/Upcoming/Overdue filters.
- Repository methods are asynchronous and signal missing/duplicate IDs with `StateError`. View-model operations convert failures into an error message and boolean success result, then notify listeners.
- New task IDs are currently generated in the editor from `DateTime.now().microsecondsSinceEpoch`. Preserve ID uniqueness across add/update/delete behavior.
- The view model’s filter semantics intentionally exclude completed tasks from Today, Upcoming, and Overdue; the Completed filter includes only completed tasks. Search matches title, description, and subject after trimming and lowercasing.
- Built-in subjects are defined centrally and sorted when exposed by the view model. `General` is the reminder/no-subject value and custom subjects must not be saved as `General`.
- Add repository/view-model behavior to the existing unit-test style using `InMemoryTaskRepository`. Widget behavior belongs in `test/widget_test.dart` or a focused widget test; avoid requiring a device-backed SQLite database for ordinary tests.
- Keep responsive layout breakpoints consistent with the app shell: below 600 px is mobile, 600–999 px uses a compact rail, and 1000 px or wider uses an extended rail.
- Keep user-visible task operations routed through `TaskViewModel`, so loading, filtering, notifications, and error handling stay consistent.

