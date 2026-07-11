import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../projects/providers/projects_provider.dart';
import '../../tasks/models/task.dart';
import '../../tasks/providers/tasks_provider.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({super.key, required this.noteId});

  final String noteId;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  Note? _note;
  bool _editing = false;
  bool _saving = false;

  late TextEditingController _titleCtrl;
  late TextEditingController _summaryCtrl;
  late List<_EditSection> _editSections;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController();
    _summaryCtrl = TextEditingController();
    _editSections = [];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _summaryCtrl.dispose();
    for (final s in _editSections) {
      s.dispose();
    }
    super.dispose();
  }

  void _beginEdit(Note note) {
    _titleCtrl.text = note.title;
    _summaryCtrl.text = note.summary;
    _editSections = note.sections.map(_EditSection.fromSection).toList();
    setState(() => _editing = true);
  }

  void _cancelEdit() {
    for (final s in _editSections) {
      s.dispose();
    }
    setState(() => _editing = false);
  }

  Future<void> _save(Note note) async {
    setState(() => _saving = true);
    try {
      final sections = _editSections.map((s) => s.toSection()).toList();
      await ref.read(notesProvider(note.projectId).notifier).saveNote(
            note.id,
            title: _titleCtrl.text.trim(),
            summary: _summaryCtrl.text.trim(),
            sections: sections,
          );
      if (mounted) {
        setState(() {
          _editing = false;
          _saving = false;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Note saved')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  Future<void> _confirmDelete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await ref
          .read(notesProvider(note.projectId).notifier)
          .delete(note.id);
      if (mounted) context.pop(); // GoRouter — not Navigator.pop
    }
  }

  Future<void> _exportPdf(Note note) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          // Title
          pw.Text(note.title,
              style: pw.TextStyle(
                  fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(_formattedDate(note.createdAt),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 16),

          // Summary
          if (note.summary.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey200),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColors.blueGrey50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Summary',
                      style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey700)),
                  pw.SizedBox(height: 6),
                  pw.Text(note.summary,
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
          ],

          // Sections
          ...note.sections.map((section) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(height: 16),
                  pw.Text(section.heading,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  ...section.bullets.map((bullet) => pw.Padding(
                        padding: const pw.EdgeInsets.only(left: 12, bottom: 4),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('• ',
                                style: const pw.TextStyle(fontSize: 11)),
                            pw.Expanded(
                              child: pw.Text(bullet,
                                  style: const pw.TextStyle(fontSize: 11)),
                            ),
                          ],
                        ),
                      )),
                ],
              )),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: '${note.title}.pdf',
    );
  }

  Future<void> _showAddTaskSheet(Note note, {String? prefillText}) async {
    final projects = ref.read(projectsProvider).valueOrNull ?? [];
    String? selectedProjectId = note.projectId;
    final ctrl = TextEditingController(text: prefillText ?? '');
    TaskPriority priority = TaskPriority.none;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add to Tasks',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      )),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              // Priority picker
              DropdownButtonFormField<TaskPriority>(
                initialValue: priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: TaskPriority.values
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text(p.label),
                        ))
                    .toList(),
                onChanged: (v) => setModal(() => priority = v ?? priority),
              ),
              const SizedBox(height: 12),
              // Project picker
              if (projects.isNotEmpty)
                DropdownButtonFormField<String?>(
                  initialValue: selectedProjectId,
                  decoration: const InputDecoration(
                    labelText: 'Project',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('No project')),
                    ...projects.map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name),
                        )),
                  ],
                  onChanged: (v) => setModal(() => selectedProjectId = v),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final title = ctrl.text.trim();
                    if (title.isEmpty) return;
                    await ref
                        .read(tasksProvider(selectedProjectId).notifier)
                        .create(
                          title: title,
                          sourceNoteId: note.id,
                          priority: priority,
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Task added ✓')),
                      );
                    }
                  },
                  child: const Text('Add Task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    ctrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesProvider(null));

    return notesAsync.when(
      loading: () =>
          _scaffold(null, const Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          _scaffold(null, Center(child: Text('Error: $e'))),
      data: (list) {
        final note = list.where((n) => n.id == widget.noteId).firstOrNull;
        if (note == null) {
          return _scaffold(
              null, const Center(child: CircularProgressIndicator()));
        }
        _note = note;
        return _scaffold(
          note,
          _editing ? _editView(note) : _readView(note),
        );
      },
    );
  }

  Scaffold _scaffold(Note? note, Widget body) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Note'),
        actions: [
          if (note != null && !_editing) ...[
            IconButton(
              icon: const Icon(Icons.add_task_rounded),
              tooltip: 'Add to Tasks',
              onPressed: () => _showAddTaskSheet(note),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
              onPressed: () => _exportPdf(note),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => _beginEdit(note),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: theme.colorScheme.error),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(note),
            ),
          ],
          if (_editing) ...[
            TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
            _saving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : TextButton(
                    onPressed: _note != null ? () => _save(_note!) : null,
                    child: const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
          ],
        ],
      ),
      body: body,
    );
  }

  // ─── Read View — Notebook paper style ────────────────────────────────────

  Widget _readView(Note note) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Stack(
      children: [
        // Dark page background
        Container(color: theme.scaffoldBackgroundColor),

        // Notebook paper card
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: CustomPaint(
            painter: _NotebookPainter(cs),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDE7), // cream paper color
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(2, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      56, 20, 20, 40), // 56 left = past red margin line
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        note.title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A237E), // ink blue
                          fontFamily: 'serif',
                          height: 1.8,
                        ),
                      ),
                      Text(
                        _formattedDate(note.createdAt),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF9E9E9E),
                          height: 1.8,
                        ),
                      ),

                      // Summary block
                      if (note.summary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD)
                                .withValues(alpha: 0.6),
                            border: Border.all(
                                color: const Color(0xFF90CAF9), width: 1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.auto_awesome_rounded,
                                      size: 13,
                                      color: Color(0xFF1565C0)),
                                  const SizedBox(width: 5),
                                  Text('Summary',
                                      style:
                                          theme.textTheme.labelSmall?.copyWith(
                                        color: const Color(0xFF1565C0),
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(note.summary,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF212121),
                                    height: 1.8,
                                  )),
                            ],
                          ),
                        ),
                      ],

                      // Sections
                      ...note.sections.map((section) => _NotebookSection(
                            section: section,
                            note: note,
                            onAddToTasks: (text) =>
                                _showAddTaskSheet(note, prefillText: text),
                          )),

                      // Add whole note as task
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: () => _showAddTaskSheet(note),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_task_rounded,
                                size: 16,
                                color: const Color(0xFF1565C0)
                                    .withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            Text(
                              'Add a task from this note',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF1565C0)
                                    .withValues(alpha: 0.7),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Edit View ────────────────────────────────────────────────────────────

  Widget _editView(Note note) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        TextField(
          controller: _titleCtrl,
          style:
              theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _summaryCtrl,
          decoration: const InputDecoration(
            labelText: 'Summary',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 24),
        Text('Sections',
            style: theme.textTheme.titleSmall
                ?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
        const SizedBox(height: 8),
        ..._editSections.asMap().entries.map((entry) {
          final i = entry.key;
          final sec = entry.value;
          return _EditSectionCard(
            key: ValueKey(i),
            section: sec,
            onDelete: () => setState(() => _editSections.removeAt(i)),
            onAddBullet: () =>
                setState(() => sec.bullets.add(TextEditingController())),
            onDeleteBullet: (bi) =>
                setState(() => sec.bullets.removeAt(bi)),
          );
        }),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add section'),
          onPressed: () => setState(() {
            _editSections.add(_EditSection(
              heading: TextEditingController(),
              bullets: [],
            ));
          }),
        ),
      ],
    );
  }

  String _formattedDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ─── Notebook paper CustomPainter ─────────────────────────────────────────────

class _NotebookPainter extends CustomPainter {
  const _NotebookPainter(this.cs);

  final ColorScheme cs;

  @override
  void paint(Canvas canvas, Size size) {
    const lineHeight = 28.8; // matches height: 1.8 * 16px bodyMedium
    const leftMargin = 48.0;
    const topOffset = 20.0;

    // Ruled lines
    final linePaint = Paint()
      ..color = const Color(0xFFBBDEFB).withValues(alpha: 0.6)
      ..strokeWidth = 0.8;

    var y = topOffset + lineHeight;
    while (y < size.height) {
      canvas.drawLine(
        Offset(leftMargin, y),
        Offset(size.width, y),
        linePaint,
      );
      y += lineHeight;
    }

    // Red margin line
    final marginPaint = Paint()
      ..color = const Color(0xFFEF9A9A).withValues(alpha: 0.7)
      ..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(leftMargin, 0),
      Offset(leftMargin, size.height),
      marginPaint,
    );
  }

  @override
  bool shouldRepaint(_NotebookPainter old) => false;
}

// ─── Notebook section block ───────────────────────────────────────────────────

class _NotebookSection extends StatelessWidget {
  const _NotebookSection({
    required this.section,
    required this.note,
    required this.onAddToTasks,
  });

  final NoteSection section;
  final Note note;
  final void Function(String) onAddToTasks;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section heading
          Text(
            section.heading,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E),
              height: 1.8,
            ),
          ),
          ...section.bullets.map((bullet) => _BulletRow(
                bullet: bullet,
                onAddToTasks: () => onAddToTasks(bullet),
              )),
        ],
      ),
    );
  }
}

class _BulletRow extends StatefulWidget {
  const _BulletRow({required this.bullet, required this.onAddToTasks});

  final String bullet;
  final VoidCallback onAddToTasks;

  @override
  State<_BulletRow> createState() => _BulletRowState();
}

class _BulletRowState extends State<_BulletRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bullet dot
            Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF1565C0),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // Bullet text
            Expanded(
              child: Text(
                widget.bullet,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF212121),
                  height: 1.8,
                ),
              ),
            ),
            // "+ Task" button on hover / always visible on touch
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 150),
              child: GestureDetector(
                onTap: widget.onAddToTasks,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Tooltip(
                    message: 'Add as task',
                    child: Icon(
                      Icons.add_task_rounded,
                      size: 16,
                      color: const Color(0xFF1565C0).withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Edit helpers ─────────────────────────────────────────────────────────────

class _EditSection {
  _EditSection({required this.heading, required this.bullets});

  final TextEditingController heading;
  final List<TextEditingController> bullets;

  static _EditSection fromSection(NoteSection s) => _EditSection(
        heading: TextEditingController(text: s.heading),
        bullets:
            s.bullets.map((t) => TextEditingController(text: t)).toList(),
      );

  NoteSection toSection() => NoteSection(
        heading: heading.text.trim(),
        bullets: bullets
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList(),
      );

  void dispose() {
    heading.dispose();
    for (final b in bullets) {
      b.dispose();
    }
  }
}

class _EditSectionCard extends StatelessWidget {
  const _EditSectionCard({
    super.key,
    required this.section,
    required this.onDelete,
    required this.onAddBullet,
    required this.onDeleteBullet,
  });

  final _EditSection section;
  final VoidCallback onDelete;
  final VoidCallback onAddBullet;
  final void Function(int) onDeleteBullet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: section.heading,
                    decoration: const InputDecoration(
                      labelText: 'Section heading',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                  onPressed: onDelete,
                  tooltip: 'Remove section',
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...section.bullets.asMap().entries.map((entry) {
              final i = entry.key;
              final ctrl = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.circle,
                        size: 6,
                        color: cs.primary.withValues(alpha: 0.5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(
                          hintText: 'Bullet point',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 18,
                          color: cs.onSurface.withValues(alpha: 0.4)),
                      onPressed: () => onDeleteBullet(i),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add bullet'),
              onPressed: onAddBullet,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
