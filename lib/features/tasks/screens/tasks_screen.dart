import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import '../providers/tasks_provider.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key, this.projectId});

  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider(projectId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasks'),
        centerTitle: false,
      ),
      body: tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (tasks) => tasks.isEmpty
            ? _EmptyState(onAdd: () => _showAddTaskSheet(context, ref))
            : _TaskList(tasks: tasks, projectId: projectId),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskSheet(context, ref),
        tooltip: 'Add task',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddTaskSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddTaskSheet(projectId: projectId, ref: ref),
    );
  }
}

// ---------------------------------------------------------------------------
// Task list with drag-to-reorder
// ---------------------------------------------------------------------------

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks, required this.projectId});

  final List<Task> tasks;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: tasks.length,
      onReorder: (oldIndex, newIndex) {
        if (newIndex > oldIndex) newIndex--;
        final reordered = List<Task>.from(tasks);
        final item = reordered.removeAt(oldIndex);
        reordered.insert(newIndex, item);
        ref.read(tasksProvider(projectId).notifier).reorder(reordered);
      },
      itemBuilder: (context, i) {
        final task = tasks[i];
        return _TaskTile(key: ValueKey(task.id), task: task, projectId: projectId);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Individual task tile
// ---------------------------------------------------------------------------

class _TaskTile extends ConsumerStatefulWidget {
  const _TaskTile({
    super.key,
    required this.task,
    required this.projectId,
  });

  final Task task;
  final String? projectId;

  @override
  ConsumerState<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends ConsumerState<_TaskTile> {
  bool _editing = false;
  late TextEditingController _titleCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.task.title);
  }

  @override
  void didUpdateWidget(_TaskTile old) {
    super.didUpdateWidget(old);
    if (!_editing && old.task.title != widget.task.title) {
      _titleCtrl.text = widget.task.title;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _saveTitle() {
    final newTitle = _titleCtrl.text.trim();
    if (newTitle.isNotEmpty && newTitle != widget.task.title) {
      ref.read(tasksProvider(widget.projectId).notifier).updateTask(
            widget.task.id,
            title: newTitle,
          );
    }
    setState(() => _editing = false);
  }

  void _cancelEdit() {
    _titleCtrl.text = widget.task.title;
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final task = widget.task;
    final notifier = ref.read(tasksProvider(widget.projectId).notifier);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox
                Checkbox(
                  value: task.completed,
                  onChanged: (_) => notifier.toggle(task.id),
                ),
                // Title (editable)
                Expanded(
                  child: _editing
                      ? TextField(
                          controller: _titleCtrl,
                          autofocus: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _saveTitle(),
                        )
                      : GestureDetector(
                          onTap: () => setState(() => _editing = true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              task.title,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                decoration: task.completed
                                    ? TextDecoration.lineThrough
                                    : null,
                                color: task.completed
                                    ? theme.colorScheme.onSurface.withValues(
                                        alpha: 0.4)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                ),
                // Action menu
                if (_editing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, size: 18),
                        onPressed: _saveTitle,
                        tooltip: 'Save',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _cancelEdit,
                        tooltip: 'Cancel',
                      ),
                    ],
                  )
                else
                  _TaskMenu(task: task, projectId: widget.projectId),
              ],
            ),
            // Priority + deadline chips
            if (task.priority != TaskPriority.none || task.deadline != null)
              Padding(
                padding: const EdgeInsets.only(left: 48, bottom: 6, right: 8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    if (task.priority != TaskPriority.none)
                      _PriorityChip(priority: task.priority),
                    if (task.deadline != null)
                      _DeadlineChip(deadline: task.deadline!),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Context menu (three-dot) for a task tile
// ---------------------------------------------------------------------------

class _TaskMenu extends ConsumerWidget {
  const _TaskMenu({required this.task, required this.projectId});

  final Task task;
  final String? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_TaskAction>(
      icon: const Icon(Icons.more_vert, size: 18),
      onSelected: (action) {
        switch (action) {
          case _TaskAction.setPriority:
            _showPriorityPicker(context, ref);
          case _TaskAction.setDeadline:
            _showDeadlinePicker(context, ref);
          case _TaskAction.delete:
            ref.read(tasksProvider(projectId).notifier).delete(task.id);
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _TaskAction.setPriority,
          child: Text('Set priority'),
        ),
        PopupMenuItem(
          value: _TaskAction.setDeadline,
          child: Text('Set deadline'),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: _TaskAction.delete,
          child: Text('Delete'),
        ),
      ],
    );
  }

  void _showPriorityPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _PrioritySheet(task: task, projectId: projectId, ref: ref),
    );
  }

  void _showDeadlinePicker(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: task.deadline ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      ref.read(tasksProvider(projectId).notifier).updateTask(
            task.id,
            deadline: picked,
          );
    }
  }
}

enum _TaskAction { setPriority, setDeadline, delete }

// ---------------------------------------------------------------------------
// Priority picker sheet
// ---------------------------------------------------------------------------

class _PrioritySheet extends StatelessWidget {
  const _PrioritySheet({
    required this.task,
    required this.projectId,
    required this.ref,
  });

  final Task task;
  final String? projectId;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Set Priority',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ...TaskPriority.values.map(
            (p) => ListTile(
              leading: _priorityIcon(p),
              title: Text(p.label),
              selected: task.priority == p,
              onTap: () {
                ref
                    .read(tasksProvider(projectId).notifier)
                    .updateTask(task.id, priority: p);
                Navigator.of(context).pop();
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _priorityIcon(TaskPriority p) {
    final (icon, color) = switch (p) {
      TaskPriority.none => (Icons.remove, Colors.grey),
      TaskPriority.low => (Icons.arrow_downward, Colors.blue),
      TaskPriority.medium => (Icons.remove, Colors.orange),
      TaskPriority.high => (Icons.arrow_upward, Colors.red),
      TaskPriority.urgent => (Icons.priority_high, Colors.red),
    };
    return Icon(icon, color: color, size: 20);
  }
}

// ---------------------------------------------------------------------------
// Priority chip
// ---------------------------------------------------------------------------

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final TaskPriority priority;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (priority) {
      TaskPriority.none => ('None', Colors.grey),
      TaskPriority.low => ('Low', Colors.blue),
      TaskPriority.medium => ('Medium', Colors.orange),
      TaskPriority.high => ('High', Colors.red),
      TaskPriority.urgent => ('Urgent', Colors.red),
    };
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

// ---------------------------------------------------------------------------
// Deadline chip
// ---------------------------------------------------------------------------

class _DeadlineChip extends StatelessWidget {
  const _DeadlineChip({required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final isOverdue = deadline.isBefore(DateTime.now());
    final label = DateFormat('MMM d').format(deadline);
    final color = isOverdue ? Colors.red : Theme.of(context).colorScheme.secondary;

    return Chip(
      avatar: Icon(Icons.calendar_today, size: 12, color: color),
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      backgroundColor: color.withValues(alpha: 0.08),
    );
  }
}

// ---------------------------------------------------------------------------
// Add task bottom sheet
// ---------------------------------------------------------------------------

class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({required this.projectId, required this.ref});

  final String? projectId;
  final WidgetRef ref;

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _titleCtrl = TextEditingController();
  TaskPriority _priority = TaskPriority.none;
  DateTime? _deadline;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    await widget.ref.read(tasksProvider(widget.projectId).notifier).create(
          title: title,
          priority: _priority,
          deadline: _deadline,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New Task', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Task title…',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Priority dropdown
              DropdownButton<TaskPriority>(
                value: _priority,
                underline: const SizedBox(),
                items: TaskPriority.values
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.label),
                        ))
                    .toList(),
                onChanged: (p) => setState(() => _priority = p!),
              ),
              const SizedBox(width: 8),
              // Deadline picker
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text(
                  _deadline == null
                      ? 'Deadline'
                      : DateFormat('MMM d').format(_deadline!),
                ),
                onPressed: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _deadline ?? now,
                    firstDate: now,
                    lastDate: now.add(const Duration(days: 365 * 5)),
                  );
                  if (picked != null) setState(() => _deadline = picked);
                },
              ),
              if (_deadline != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _deadline = null),
                  tooltip: 'Clear deadline',
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Add'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.checklist_rounded, size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 16),
          Text('No tasks yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tasks extracted from recordings\nwill appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add task'),
          ),
        ],
      ),
    );
  }
}
