import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/branding.dart';
import '../app/motion.dart';
import '../models/task.dart';
import '../view_models/task_view_model.dart';
import 'task_editor_dialog.dart';

class TaskDetailsDialog extends StatelessWidget {
  const TaskDetailsDialog({
    required this.viewModel,
    required this.task,
    super.key,
  });

  final TaskViewModel viewModel;
  final Task task;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (context, _) {
        final current = viewModel.tasks.firstWhere(
          (value) => value.id == task.id,
          orElse: () => task,
        );

        final metadata = <_InfoTileData>[
          _InfoTileData(
            'Due date',
            current.dueDate == null
                ? 'No due date'
                : _formatDate(current.dueDate!),
          ),
          _InfoTileData('Priority', current.priority.name),
          _InfoTileData('Status', current.isCompleted ? 'Completed' : 'Open'),
          if (current.isCompleted && current.completedAt != null)
            _InfoTileData(
              'Completion date',
              _formatDateTime(current.completedAt!),
            ),
        ];

        final viewport = MediaQuery.sizeOf(context);
        final dialogWidth = math.max(0.0, math.min(960.0, viewport.width - 48));
        final dialogMaxHeight = math.max(
          0.0,
          math.min(760.0, viewport.height - 48),
        );

        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: dialogWidth,
              maxHeight: dialogMaxHeight,
            ),
            child: SizedBox(
              width: dialogWidth,
              child: AnimatedSize(
                alignment: Alignment.topCenter,
                duration: accessibleMotionDuration(context),
                curve: Curves.easeInOutCubic,
                child: Container(
                  key: const ValueKey('task-details-surface'),
                  constraints: BoxConstraints(maxHeight: dialogMaxHeight),
                  decoration: BoxDecoration(
                    color: talaSurface,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: talaBorder),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _TaskDetailsHeader(task: current),
                              const Divider(height: 1, color: talaBorder),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final wide = constraints.maxWidth >= 640;
                                  final descriptionWidget =
                                      current.description.isEmpty
                                      ? const _NoDescription()
                                      : _DescriptionPanel(
                                          description: current.description,
                                        );

                                  if (wide) {
                                    final detailColumnWidth = math.min(
                                      260.0,
                                      constraints.maxWidth * 0.36,
                                    );
                                    final panelMaxHeight = math.min(
                                      484.0,
                                      math.max(144.0, dialogMaxHeight - 240),
                                    );
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        16,
                                        20,
                                        8,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            width: detailColumnWidth,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxHeight: math.max(
                                                  144.0,
                                                  panelMaxHeight,
                                                ),
                                              ),
                                              child: SingleChildScrollView(
                                                child: _MetadataCards(
                                                  metadata: metadata,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxHeight: panelMaxHeight,
                                              ),
                                              child: descriptionWidget,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  final panelMaxHeight = math.max(
                                    144.0,
                                    dialogMaxHeight - 360,
                                  );
                                  return Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      12,
                                      20,
                                      8,
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _CompactMetadata(metadata: metadata),
                                        const SizedBox(height: 12),
                                        ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight: panelMaxHeight,
                                          ),
                                          child: descriptionWidget,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: talaBorder),
                      _TaskDetailsActions(
                        isCompleted: current.isCompleted,
                        onToggle: () => _toggle(context, current),
                        onEdit: () => _edit(context, current),
                        onDelete: () => _delete(context, current),
                        onClose: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _toggle(BuildContext context, Task current) async {
    final succeeded = await viewModel.toggleTask(current.id);
    if (!succeeded || !context.mounted) return;
    if (!viewModel.tasks.any((task) => task.id == current.id)) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _edit(BuildContext context, Task current) async {
    final updated = await showDialog<Task>(
      context: context,
      builder: (_) => TaskEditorDialog(
        task: current,
        subjects: viewModel.availableSubjects,
      ),
    );
    if (updated != null) await viewModel.updateTask(updated);
  }

  Future<void> _delete(BuildContext context, Task current) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete task?'),
        content: const Text('This task will be permanently removed.'),
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
      ),
    );
    if (confirmed == true) {
      await viewModel.deleteTask(current.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  static String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.month}/${local.day}/${local.year}';
  }

  static String _formatDateTime(DateTime date) {
    final local = date.toLocal();
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final hour = local.hour == 0
        ? 12
        : (local.hour > 12 ? local.hour - 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year} $hour:$minute $period';
  }
}

class _TaskDetailsHeader extends StatelessWidget {
  const _TaskDetailsHeader({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: talaSky,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              task.subject,
              style: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(color: talaBlue, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            task.title,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(color: talaInk, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TaskDetailsActions extends StatelessWidget {
  const _TaskDetailsActions({
    required this.isCompleted,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onClose,
  });

  final bool isCompleted;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final actions = [
      OutlinedButton(onPressed: onEdit, child: const Text('Edit')),
      TextButton(onPressed: onDelete, child: const Text('Delete')),
      TextButton(onPressed: onClose, child: const Text('Close')),
    ];
    final toggleButton = FilledButton(
      onPressed: onToggle,
      child: Text(isCompleted ? 'Mark incomplete' : 'Mark complete'),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 440) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                toggleButton,
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: actions,
                ),
              ],
            );
          }

          return Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [toggleButton, ...actions],
          );
        },
      ),
    );
  }
}

class _InfoTileData {
  const _InfoTileData(this.label, this.value);

  final String label;
  final String value;
}

class _MetadataCards extends StatelessWidget {
  const _MetadataCards({required this.metadata});

  final List<_InfoTileData> metadata;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < metadata.length; index++) ...[
          Padding(
            padding: EdgeInsets.only(
              bottom: index == metadata.length - 1 ? 0 : 12,
            ),
            child: _Detail(
              label: metadata[index].label,
              value: metadata[index].value,
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactMetadata extends StatelessWidget {
  const _CompactMetadata({required this.metadata});

  final List<_InfoTileData> metadata;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in metadata)
              SizedBox(
                width: itemWidth,
                child: _CompactDetail(label: item.label, value: item.value),
              ),
          ],
        );
      },
    );
  }
}

class _CompactDetail extends StatelessWidget {
  const _CompactDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: talaPaper,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: talaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: talaInk.withValues(alpha: 0.64),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: talaInk, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _NoDescription extends StatelessWidget {
  const _NoDescription();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: talaPaper,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: talaBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes_rounded, color: talaBlue.withValues(alpha: 0.72)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'No description',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: talaInk, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'No additional details.',
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: talaInk.withValues(alpha: 0.72)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionPanel extends StatefulWidget {
  const _DescriptionPanel({required this.description});

  final String description;

  @override
  State<_DescriptionPanel> createState() => _DescriptionPanelState();
}

class _DescriptionPanelState extends State<_DescriptionPanel> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: talaInk.withValues(alpha: 0.9),
          height: 1.55,
          fontSize: 15.5,
        );
        final textPainter = TextPainter(
          text: TextSpan(text: widget.description, style: textStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(0, constraints.maxWidth - 42));
        const panelChromeHeight = 68.0;
        final maxTextHeight = math.max(
          0.0,
          math.min(380.0, constraints.maxHeight - panelChromeHeight),
        );
        final descriptionHeight = math.min(textPainter.height, maxTextHeight);

        return Container(
          decoration: BoxDecoration(
            color: talaPaper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: talaBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: talaInk, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: descriptionHeight,
                  child: Scrollbar(
                    controller: _scrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(right: 8),
                      child: SelectableText(
                        widget.description,
                        style: textStyle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: talaPaper,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: talaBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: talaInk.withValues(alpha: 0.64),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: talaInk, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
