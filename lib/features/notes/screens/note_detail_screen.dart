import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  // Editing controllers
  late TextEditingController _titleCtrl;
  late TextEditingController _summaryCtrl;

  // Sections as mutable list for editing
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note saved')),
        );
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
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pull from provider — shows loading/error states, keeps data fresh
    final notesAsync = ref.watch(notesProvider(null));

    return notesAsync.when(
      loading: () => _scaffold(null, const Center(child: CircularProgressIndicator())),
      error: (e, _) => _scaffold(null, Center(child: Text('Error: $e'))),
      data: (list) {
        final note = list.where((n) => n.id == widget.noteId).firstOrNull;
        if (note == null) {
          // Try fetching directly
          return _scaffold(null, const Center(child: CircularProgressIndicator()));
        }
        // Keep local reference for edit operations
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
          if (note != null && !_editing)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit',
              onPressed: () => _beginEdit(note),
            ),
          if (note != null && !_editing)
            IconButton(
              icon: Icon(Icons.delete_outline_rounded,
                  color: theme.colorScheme.error),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(note),
            ),
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _cancelEdit,
              child: const Text('Cancel'),
            ),
          if (_editing)
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
      ),
      body: body,
    );
  }

  // ─── Read View ───────────────────────────────────────────────────────────

  Widget _readView(Note note) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Title
        Text(
          note.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formattedDate(note.createdAt),
          style: theme.textTheme.labelSmall?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.4),
          ),
        ),

        // Summary card
        if (note.summary.isNotEmpty) ...[
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: cs.primary.withValues(alpha: 0.2)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 15, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('Summary',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                Text(note.summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.85))),
              ],
            ),
          ),
        ],

        // Sections
        ...note.sections.map((section) => _SectionBlock(section: section)),
      ],
    );
  }

  // ─── Edit View ───────────────────────────────────────────────────────────

  Widget _editView(Note note) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        // Title field
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

        // Summary field
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

        // Sections
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
            onAddBullet: () => setState(() => sec.bullets.add(TextEditingController())),
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
    final months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }
}

// ─── Section Block (read mode) ────────────────────────────────────────────────

class _SectionBlock extends StatelessWidget {
  const _SectionBlock({required this.section});

  final NoteSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...section.bullets.map((bullet) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6, right: 10),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        bullet,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.85),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
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
        bullets: s.bullets
            .map((t) => TextEditingController(text: t))
            .toList(),
      );

  NoteSection toSection() => NoteSection(
        heading: heading.text.trim(),
        bullets: bullets.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
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
                  icon: Icon(Icons.delete_outline_rounded,
                      color: cs.error),
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
