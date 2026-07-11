import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
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

// College-ruled line spacing — single source of truth used by painter AND text
const double _kLineSpacing = 28.0;

// Every text style must have lineHeight = _kLineSpacing.
// Flutter's TextStyle.height is a multiplier of fontSize, so:
//   height = _kLineSpacing / fontSize
// This ensures every line of text lands exactly on a blue rule.
TextStyle _ruled(double fontSize, {Color? color, FontWeight? weight}) =>
    TextStyle(
      fontSize: fontSize,
      height: _kLineSpacing / fontSize,
      color: color ?? const Color(0xFF212121),
      fontWeight: weight,
    );

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
      if (mounted) context.pop();
    }
  }

  Future<Uint8List> _buildPdfBytes(Note note) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.only(
            left: 72, right: 40, top: 40, bottom: 40),
        build: (ctx) => [
          pw.Text(note.title,
              style: pw.TextStyle(
                  fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(_formattedDate(note.createdAt),
              style: const pw.TextStyle(
                  fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 14),
          if (note.summary.isNotEmpty) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey200),
                color: PdfColors.blueGrey50,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Summary',
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey700)),
                  pw.SizedBox(height: 4),
                  pw.Text(note.summary,
                      style: const pw.TextStyle(fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
          ],
          ...note.sections.expand((section) => [
                pw.SizedBox(height: 14),
                pw.Text(section.heading,
                    style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900)),
                pw.SizedBox(height: 6),
                ...section.bullets.map((bullet) => pw.Padding(
                      padding: const pw.EdgeInsets.only(left: 10, bottom: 4),
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
              ]),
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> _exportPdf(Note note) async {
    try {
      final bytes = await _buildPdfBytes(note);
      if (kIsWeb) {
        await Printing.sharePdf(bytes: bytes, filename: '${note.title}.pdf');
      } else {
        await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: '${note.title}.pdf',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    }
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
              DropdownButtonFormField<TaskPriority>(
                value: priority,
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
              if (projects.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: selectedProjectId,
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

  // ─── Read View ────────────────────────────────────────────────────────────

  Widget _readView(Note note) {
    return LayoutBuilder(builder: (context, constraints) {
      // Two pages side-by-side on desktop (>=900px wide), single page on mobile
      final twoPage = constraints.maxWidth >= 900;

      // Single page width: 8.5x11 ratio. Cap at 620px.
      final pageW = twoPage
          ? ((constraints.maxWidth - 80) / 2).clamp(300.0, 620.0)
          : (constraints.maxWidth - 32.0).clamp(0.0, 620.0);

      final pageContent = _NotebookPage(
        note: note,
        pageWidth: pageW,
        onAddToTasks: (text) => _showAddTaskSheet(note, prefillText: text),
        formattedDate: _formattedDate(note.createdAt),
      );

      if (twoPage) {
        // Desktop: two pages side-by-side (second page is blank continuation)
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              pageContent,
              const SizedBox(width: 32),
              _BlankNotebookPage(pageWidth: pageW),
            ],
          ),
        );
      } else {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Center(child: pageContent),
        );
      }
    });
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
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
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

// ─── Single notebook page widget ─────────────────────────────────────────────

class _NotebookPage extends StatelessWidget {
  const _NotebookPage({
    required this.note,
    required this.pageWidth,
    required this.onAddToTasks,
    required this.formattedDate,
  });

  final Note note;
  final double pageWidth;
  final void Function(String) onAddToTasks;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
    // 8.5x11 minimum height
    final minH = pageWidth * (11 / 8.5);

    return SizedBox(
      width: pageWidth,
      child: Container(
        constraints: BoxConstraints(minHeight: minH),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(3, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _NotebookPainter(),
          child: Padding(
            // Left: 72px (clears punch holes + margin line)
            // Top: starts at first ruled line. The painter draws first line at
            // y=56. We pad top to 56 - half a line so title baseline hits line 1.
            padding: const EdgeInsets.fromLTRB(72, 42, 24, 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title — fontSize 18, line height = 28
                Text(
                  note.title,
                  style: _ruled(18,
                      color: const Color(0xFF1A237E),
                      weight: FontWeight.bold),
                ),
                // Date — fontSize 11, line height = 28
                Text(
                  formattedDate,
                  style: _ruled(11, color: const Color(0xFF9E9E9E)),
                ),

                // Summary block — height snaps to multiple of 28
                if (note.summary.isNotEmpty) ...[
                  const SizedBox(height: _kLineSpacing),
                  _SummaryBox(summary: note.summary),
                ],

                // Sections
                ...note.sections.map((section) => _NotebookSection(
                      section: section,
                      onAddToTasks: onAddToTasks,
                    )),

                const SizedBox(height: _kLineSpacing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Blank second page (desktop right-hand page) ─────────────────────────────

class _BlankNotebookPage extends StatelessWidget {
  const _BlankNotebookPage({required this.pageWidth});

  final double pageWidth;

  @override
  Widget build(BuildContext context) {
    final minH = pageWidth * (11 / 8.5);
    return SizedBox(
      width: pageWidth,
      child: Container(
        constraints: BoxConstraints(minHeight: minH),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(3, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: CustomPaint(
          painter: _NotebookPainter(),
        ),
      ),
    );
  }
}

// ─── Summary box ─────────────────────────────────────────────────────────────
// Height is a multiple of _kLineSpacing so content after it stays on-grid.

class _SummaryBox extends StatelessWidget {
  const _SummaryBox({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD).withValues(alpha: 0.7),
        border: Border.all(color: const Color(0xFF90CAF9), width: 1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — 28px tall
          SizedBox(
            height: _kLineSpacing,
            child: Row(
              children: const [
                Icon(Icons.auto_awesome_rounded,
                    size: 12, color: Color(0xFF1565C0)),
                SizedBox(width: 5),
                Text('Summary',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1565C0),
                      height: _kLineSpacing / 11,
                    )),
              ],
            ),
          ),
          // Summary text — each line = 28px
          Text(
            summary,
            style: _ruled(13, color: const Color(0xFF212121)),
          ),
        ],
      ),
    );
  }
}

// ─── Notebook paper CustomPainter ────────────────────────────────────────────
// Draws: college-ruled blue lines, red vertical margin, 3 punch holes.
// First line at y=56 so the title (top padding 42 + one line = 70px rendered,
// but baseline lands on the line).

class _NotebookPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const marginX = 64.0;
    const holeX = 22.0;
    const holeR = 9.0;
    // First rule at y=56 — aligns with the first text baseline given top
    // padding of 42px and fontSize 18 ascent ~14px.
    const firstRuleY = 56.0;

    // ── College-ruled lines ──────────────────────────────────────────────────
    final linePaint = Paint()
      ..color = const Color(0xFFADD8E6)
      ..strokeWidth = 0.75;

    var y = firstRuleY;
    while (y <= size.height + _kLineSpacing) {
      canvas.drawLine(
        Offset(marginX, y),
        Offset(size.width, y),
        linePaint,
      );
      y += _kLineSpacing;
    }

    // ── Red margin line ──────────────────────────────────────────────────────
    final marginPaint = Paint()
      ..color = const Color(0xFFFF8A80)
      ..strokeWidth = 1.5;

    canvas.drawLine(
      const Offset(marginX, 0),
      Offset(marginX, size.height),
      marginPaint,
    );

    // ── 3 punch holes ────────────────────────────────────────────────────────
    final holePaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.fill;

    final holeBorderPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    final holePositions = [
      size.height * 0.15,
      size.height * 0.50,
      size.height * 0.85,
    ];

    for (final hy in holePositions) {
      final center = Offset(holeX, hy);
      canvas.drawCircle(center, holeR, holePaint);
      canvas.drawCircle(center, holeR, holeBorderPaint);
    }
  }

  @override
  bool shouldRepaint(_NotebookPainter old) => false;
}

// ─── Notebook section ─────────────────────────────────────────────────────────

class _NotebookSection extends StatelessWidget {
  const _NotebookSection({
    required this.section,
    required this.onAddToTasks,
  });

  final NoteSection section;
  final void Function(String) onAddToTasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Blank rule gap before each section heading
        const SizedBox(height: _kLineSpacing),
        // Heading — sits on its own ruled line
        SizedBox(
          height: _kLineSpacing,
          child: Text(
            section.heading,
            style: _ruled(14,
                color: const Color(0xFF1A237E), weight: FontWeight.w700),
          ),
        ),
        ...section.bullets.map((bullet) => _BulletRow(
              bullet: bullet,
              onAddToTasks: () => onAddToTasks(bullet),
            )),
      ],
    );
  }
}

// ─── Bullet row — each row is exactly _kLineSpacing tall ─────────────────────

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
      child: Container(
        // Exact line height so each bullet row aligns to the next blue rule
        height: _kLineSpacing,
        color: _hovered
            ? const Color(0xFFE3F2FD).withValues(alpha: 0.5)
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bullet dot
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
            ),
            // Bullet text — clips if multi-line (single rule per bullet)
            Expanded(
              child: Text(
                widget.bullet,
                style: _ruled(13, color: const Color(0xFF212121)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // "+ Task" button — appears on hover
            AnimatedOpacity(
              opacity: _hovered ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 120),
              child: Tooltip(
                message: 'Add as task',
                child: InkWell(
                  onTap: widget.onAddToTasks,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add_task_rounded,
                            size: 14, color: Color(0xFF1565C0)),
                        SizedBox(width: 3),
                        Text('Task',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.w600,
                            )),
                      ],
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
