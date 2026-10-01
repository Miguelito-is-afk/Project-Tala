enum TaskPriority { low, medium, high }

class Task {
  const Task({
    required this.id,
    required this.title,
    this.description = '',
    this.subject = 'General',
    this.dueDate,
    this.priority = TaskPriority.medium,
    this.isCompleted = false,
    DateTime? completedAt,
    this.createdAt,
    this.updatedAt,
  }) : completedAt = isCompleted ? completedAt : null;

  /// Creates a normal application task with timestamps automatically assigned.
  factory Task.create({
    required String id,
    required String title,
    String description = '',
    String subject = 'General',
    DateTime? dueDate,
    TaskPriority priority = TaskPriority.medium,
    bool isCompleted = false,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now().toUtc();
    final effectiveCreatedAt = (createdAt ?? now).toUtc();
    final effectiveCompletedAt = isCompleted
        ? (completedAt ?? now).toUtc()
        : null;

    return Task(
      id: id,
      title: title,
      description: description,
      subject: subject,
      dueDate: dueDate?.toUtc(),
      priority: priority,
      isCompleted: isCompleted,
      completedAt: effectiveCompletedAt,
      createdAt: effectiveCreatedAt,
      updatedAt: (updatedAt ?? effectiveCreatedAt).toUtc(),
    );
  }

  final String id;
  final String title;
  final String description;
  final String subject;
  final DateTime? dueDate;
  final TaskPriority priority;
  final bool isCompleted;
  final DateTime? completedAt;

  /// When the task was first created.
  final DateTime? createdAt;

  /// When the task was last modified.
  final DateTime? updatedAt;

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? subject,
    DateTime? dueDate,
    bool clearDueDate = false,
    TaskPriority? priority,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final effectiveIsCompleted = isCompleted ?? this.isCompleted;
    final completionChanged =
        isCompleted != null && isCompleted != this.isCompleted;
    final effectiveCompletedAt = !effectiveIsCompleted || clearCompletedAt
        ? null
        : completedAt ??
              (completionChanged ? DateTime.now().toUtc() : this.completedAt);

    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subject: subject ?? this.subject,
      dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      isCompleted: effectiveIsCompleted,
      completedAt: effectiveCompletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
