import 'package:flutter/material.dart';

import 'task_editor_dialog.dart';
import '../app/motion.dart';
import '../app/subjects.dart';
import '../models/task.dart';
import '../view_models/task_view_model.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({required this.viewModel, super.key});

  Future<void> _editTask(BuildContext context, Task task) async {
    final updatedTask = await showTaskEditorDialog(
      context,
      task: task,
      subjects: viewModel.availableSubjects,
    );

    if (updatedTask == null || !context.mounted) {
      return;
    }

    final success = await viewModel.updateTask(updatedTask);

    if (!success || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Task updated.')));
  }

  Future<void> _addTask(BuildContext context) async {
    final task = await showTaskEditorDialog(
      context,
      subjects: viewModel.availableSubjects,
    );

    if (task == null || !context.mounted) {
      return;
    }

    final success = await viewModel.addTask(task);

    if (!success || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Task created.')));
  }

  final TaskViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: viewModel,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final horizontalPadding = constraints.maxWidth >= 1000
                  ? 48.0
                  : 24.0;

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Padding(
                    padding: EdgeInsets.all(horizontalPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context),
                        const SizedBox(height: 24),
                        Expanded(child: _buildTaskContent(context)),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasks',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${viewModel.incompleteTaskCount} remaining · '
                    '${viewModel.completedTaskCount} completed',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: () => _addTask(context),
              icon: const Icon(Icons.add),
              label: const Text('Add task'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _TaskSearchField(viewModel: viewModel),
        const SizedBox(height: 16),
        _buildFilterBar(context),
        const SizedBox(height: 12),
        _buildDropdownFilters(context),
      ],
    );
  }

  Widget _buildDropdownFilters(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final controls = [
          _buildSubjectFilter(context),
          _buildPriorityFilter(context),
          _buildSortSelector(context),
        ];

        if (constraints.maxWidth >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < controls.length; index++) ...[
                if (index > 0) const SizedBox(width: 12),
                Expanded(child: controls[index]),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var index = 0; index < controls.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              controls[index],
            ],
          ],
        );
      },
    );
  }

  Widget _buildSubjectFilter(BuildContext context) {
    const allSubjectsValue = '__all_subjects__';

    return DropdownButtonFormField<String>(
      initialValue: viewModel.selectedSubject ?? allSubjectsValue,
      decoration: const InputDecoration(
        labelText: 'Subject',
        prefixIcon: Icon(Icons.menu_book_outlined),
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem<String>(
          value: allSubjectsValue,
          child: Text('All subjects'),
        ),
        DropdownMenuItem<String>(
          value: reminderSubject,
          child: const Text('Reminder'),
        ),
        ...viewModel.availableSubjects
            .where((subject) => subject != reminderSubject)
            .map(
              (subject) => DropdownMenuItem<String>(
                value: subject,
                child: Text(subject),
              ),
            ),
      ],
      onChanged: (value) {
        viewModel.setSubjectFilter(value == allSubjectsValue ? null : value);
      },
    );
  }

  Widget _buildPriorityFilter(BuildContext context) {
    return DropdownButtonFormField<TaskPriority?>(
      initialValue: viewModel.selectedPriority,
      decoration: const InputDecoration(
        labelText: 'Priority',
        prefixIcon: Icon(Icons.flag_outlined),
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem<TaskPriority?>(
          value: null,
          child: Text('All priorities'),
        ),
        DropdownMenuItem<TaskPriority?>(
          value: TaskPriority.low,
          child: Text('Low'),
        ),
        DropdownMenuItem<TaskPriority?>(
          value: TaskPriority.medium,
          child: Text('Medium'),
        ),
        DropdownMenuItem<TaskPriority?>(
          value: TaskPriority.high,
          child: Text('High'),
        ),
      ],
      onChanged: viewModel.setPriorityFilter,
    );
  }

  Widget _buildSortSelector(BuildContext context) {
    return DropdownButtonFormField<TaskSortOption>(
      initialValue: viewModel.selectedSort,
      decoration: const InputDecoration(
        labelText: 'Sort by',
        prefixIcon: Icon(Icons.sort),
        border: OutlineInputBorder(),
      ),
      items: TaskSortOption.values.map((sortOption) {
        return DropdownMenuItem(
          value: sortOption,
          child: Text(_sortLabel(sortOption)),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          viewModel.setSortOption(value);
        }
      },
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    const filters = TaskFilter.values;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < filters.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            ChoiceChip(
              label: Text(_filterLabel(filters[index])),
              selected: viewModel.selectedFilter == filters[index],
              onSelected: (_) {
                viewModel.setFilter(filters[index]);
              },
            ),
          ],
        ],
      ),
    );
  }

  String _sortLabel(TaskSortOption sortOption) {
    switch (sortOption) {
      case TaskSortOption.dueDate:
        return 'Due date - soonest first';
      case TaskSortOption.priority:
        return 'Priority - high to low';
      case TaskSortOption.recentlyAdded:
        return 'Recently added';
      case TaskSortOption.oldestFirst:
        return 'Oldest first';
    }
  }

  String _filterLabel(TaskFilter filter) {
    switch (filter) {
      case TaskFilter.all:
        return 'All';
      case TaskFilter.today:
        return 'Today';
      case TaskFilter.upcoming:
        return 'Upcoming';
      case TaskFilter.overdue:
        return 'Overdue';
      case TaskFilter.completed:
        return 'Completed';
    }
  }

  String _priorityFilterLabel(TaskPriority? priority) {
    switch (priority) {
      case null:
        return 'All priorities';
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  Widget _buildTaskContent(BuildContext context) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(viewModel.errorMessage!),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: viewModel.clearError,
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    }

    final tasks = viewModel.filteredTasks;

    if (tasks.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final task = tasks[index];

        return TaskCard(
          task: task,
          onToggle: () => viewModel.toggleTask(task.id),
          onDelete: () => _deleteTask(context, task),
          onEdit: () => _editTask(context, task),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final hasStatusFilter = viewModel.selectedFilter != TaskFilter.all;

    final hasSubjectFilter = viewModel.selectedSubject != null;

    final hasPriorityFilter = viewModel.selectedPriority != null;

    final hasAnyFilter =
        hasStatusFilter || hasSubjectFilter || hasPriorityFilter;

    final filterCount = [
      hasStatusFilter,
      hasSubjectFilter,
      hasPriorityFilter,
    ].where((filter) => filter).length;

    final hasCombinedFilters = filterCount > 1;

    final hasSearch = viewModel.searchQuery.isNotEmpty;

    final subjectLabel = viewModel.selectedSubject == reminderSubject
        ? 'reminder'
        : viewModel.selectedSubject;

    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasAnyFilter ? Icons.filter_alt_off : Icons.checklist,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                (hasSearch && hasAnyFilter) || hasCombinedFilters
                    ? 'No matching tasks'
                    : hasSearch
                    ? 'No tasks match your search.'
                    : hasSubjectFilter
                    ? 'No $subjectLabel tasks'
                    : hasPriorityFilter
                    ? 'No ${_priorityFilterLabel(viewModel.selectedPriority).toLowerCase()} priority tasks'
                    : hasStatusFilter
                    ? 'No ${_filterLabel(viewModel.selectedFilter).toLowerCase()} tasks'
                    : 'No tasks yet',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                (hasSearch && hasAnyFilter) || hasCombinedFilters
                    ? 'Try changing your search or filters.'
                    : hasSearch
                    ? 'Try a different search term.'
                    : hasSubjectFilter
                    ? 'There are no tasks for this subject.'
                    : hasPriorityFilter
                    ? 'There are no tasks with this priority.'
                    : hasStatusFilter
                    ? 'There are no tasks matching this filter.'
                    : 'Add your first assignment, deadline, or study task.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteTask(BuildContext context, Task task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete task?'),
          content: Text('Are you sure you want to delete "${task.title}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true || !context.mounted) {
      return;
    }

    final success = await viewModel.deleteTask(task.id);

    if (!success || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Task deleted.')));
  }
}

class TaskCard extends StatelessWidget {
  const TaskCard({
    required this.task,
    required this.onToggle,
    this.onDelete,
    this.onEdit,
    this.onTap,
    super.key,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final priorityColor = _priorityColor(context);

    final colors = Theme.of(context).colorScheme;
    final completedDecoration = task.isCompleted
        ? colors.primaryContainer.withValues(alpha: 0.28)
        : Colors.transparent;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: accessibleMotionDuration(context),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: completedDecoration,
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(value: task.isCompleted, onChanged: (_) => onToggle()),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: accessibleMotionDuration(context),
                      curve: Curves.easeOutCubic,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                      child: Text(task.title),
                    ),
                    if (task.description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        task.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: task.subject == reminderSubject
                              ? Icons.notifications_none_outlined
                              : Icons.menu_book_outlined,
                          label: task.subject == reminderSubject
                              ? 'Reminder'
                              : task.subject,
                        ),
                        if (task.dueDate != null)
                          _InfoChip(
                            icon: Icons.calendar_today_outlined,
                            label: _formatDate(task.dueDate!),
                          ),
                        _InfoChip(
                          icon: Icons.flag_outlined,
                          label: _priorityLabel(task.priority),
                          color: priorityColor,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onEdit != null || onDelete != null)
                PopupMenuButton<String>(
                  tooltip: 'Task options',
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit?.call();
                        break;
                      case 'delete':
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (onEdit != null)
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Edit'),
                        ),
                      ),
                    if (onDelete != null)
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline),
                          title: Text('Delete'),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _priorityColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (task.priority) {
      case TaskPriority.low:
        return colorScheme.primary;
      case TaskPriority.medium:
        return colorScheme.secondary;
      case TaskPriority.high:
        return colorScheme.error;
    }
  }

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.low:
        return 'Low';
      case TaskPriority.medium:
        return 'Medium';
      case TaskPriority.high:
        return 'High';
    }
  }

  String _formatDate(DateTime date) {
    final localDate = date.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);

    final taskDay = DateTime(localDate.year, localDate.month, localDate.day);

    if (taskDay == today) {
      return 'Today';
    }

    if (taskDay == today.add(const Duration(days: 1))) {
      return 'Tomorrow';
    }

    return '${months[localDate.month - 1]} '
        '${localDate.day}, '
        '${localDate.year}';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: chipColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: chipColor, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TaskSearchField extends StatefulWidget {
  const _TaskSearchField({required this.viewModel});

  final TaskViewModel viewModel;

  @override
  State<_TaskSearchField> createState() => _TaskSearchFieldState();
}

class _TaskSearchFieldState extends State<_TaskSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.viewModel.searchQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _controller.clear();
    widget.viewModel.clearSearch();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: (value) {
        setState(() {});
        widget.viewModel.setSearchQuery(value);
      },
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search tasks...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: _clearSearch,
                tooltip: 'Clear search',
                icon: const Icon(Icons.clear),
              ),
        border: const OutlineInputBorder(),
      ),
    );
  }
}

Future<Task?> showTaskEditorDialog(
  BuildContext context, {
  Task? task,
  List<String> subjects = const [reminderSubject, ...appSubjects],
}) {
  return showDialog<Task>(
    context: context,
    builder: (context) {
      return TaskEditorDialog(task: task, subjects: subjects);
    },
  );
}
