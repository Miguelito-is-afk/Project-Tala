import '../models/task.dart';

enum CompletedTaskCleanupPolicy { never, endOfDay, endOfWeek, immediate }

Set<String> completedTaskIdsEligibleForCleanup(
  Iterable<Task> tasks, {
  required CompletedTaskCleanupPolicy policy,
  required DateTime now,
  bool includeImmediate = false,
  Set<String>? onlyTaskIds,
}) {
  final localNow = now.toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final currentWeek = today.subtract(Duration(days: today.weekday - 1));
  final eligibleIds = <String>{};

  for (final task in tasks) {
    if (!task.isCompleted ||
        task.completedAt == null ||
        (onlyTaskIds != null && !onlyTaskIds.contains(task.id))) {
      continue;
    }

    final completedAt = task.completedAt!.toLocal();
    final completionDay = DateTime(
      completedAt.year,
      completedAt.month,
      completedAt.day,
    );

    final isEligible = switch (policy) {
      CompletedTaskCleanupPolicy.never => false,
      CompletedTaskCleanupPolicy.immediate => includeImmediate,
      CompletedTaskCleanupPolicy.endOfDay => today.isAfter(completionDay),
      CompletedTaskCleanupPolicy.endOfWeek => currentWeek.isAfter(
        completionDay.subtract(Duration(days: completionDay.weekday - 1)),
      ),
    };
    if (isEligible) eligibleIds.add(task.id);
  }

  return eligibleIds;
}
