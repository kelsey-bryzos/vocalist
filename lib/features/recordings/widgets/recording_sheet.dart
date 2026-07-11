import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/router.dart';
import '../../../core/supabase/supabase_client.dart';
import '../providers/recorder_provider.dart';
import 'waveform_bars.dart';

/// Bottom sheet for recording. Opened from the home FAB.
class RecordingSheet extends ConsumerStatefulWidget {
  const RecordingSheet({super.key, this.projectId});

  final String? projectId;

  static Future<void> show(BuildContext context, {String? projectId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // prevent accidental swipe-dismiss while recording
      backgroundColor: Colors.transparent,
      builder: (_) => RecordingSheet(projectId: projectId),
    );
  }

  @override
  ConsumerState<RecordingSheet> createState() => _RecordingSheetState();
}

class _RecordingSheetState extends ConsumerState<RecordingSheet> {
  final _liveScrollController = ScrollController();

  @override
  void dispose() {
    _liveScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(recorderProvider);
    final notifier = ref.read(recorderProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Auto-scroll live text to bottom as new words arrive
    if (state.liveText.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_liveScrollController.hasClients) {
          _liveScrollController.animateTo(
            _liveScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: state.isDone
          ? _doneView(context, theme, cs, state, notifier)
          : _recordingView(context, theme, cs, state, notifier),
    );
  }

  // ── Recording / uploading view ─────────────────────────────────────────────

  Widget _recordingView(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    RecorderStateData state,
    RecorderNotifier notifier,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Handle
        _handle(cs),
        const SizedBox(height: 24),

        // Title
        Text(
          _titleFor(state),
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),

        // Timer
        Text(
          _formatTime(state.elapsedMs),
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontFeatures: const [FontFeature.tabularFigures()],
            color: _timerColor(state, cs),
          ),
        ),
        const SizedBox(height: 16),

        // Live transcript text — shown while recording
        if (state.isRecording || state.isPaused) ...[
          _liveTranscriptBox(theme, cs, state),
          const SizedBox(height: 16),
        ],

        // Waveform
        SizedBox(
          height: 56,
          child: state.isRecording
              ? WaveformBars(amplitude: state.amplitude, color: cs.primary)
              : _idleWave(cs),
        ),
        const SizedBox(height: 24),

        // Controls
        if (state.isUploading)
          Column(
            children: [
              CircularProgressIndicator(color: cs.primary),
              const SizedBox(height: 12),
              Text('Uploading…', style: theme.textTheme.bodyMedium),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cancel
              if (!state.isIdle)
                _iconBtn(
                  icon: Icons.close,
                  tooltip: 'Cancel',
                  color: cs.error,
                  onTap: () async {
                    await notifier.cancel();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              const SizedBox(width: 16),

              // Main action: Start / Pause / Resume
              _mainButton(context, ref, state, cs),

              const SizedBox(width: 16),

              // Stop (only while recording or paused)
              if (state.isRecording || state.isPaused)
                _iconBtn(
                  icon: Icons.stop_rounded,
                  tooltip: 'Stop & save',
                  color: cs.tertiary,
                  onTap: () async {
                    await notifier.stop(projectId: widget.projectId);
                    // Sheet stays open — transitions to done view
                  },
                ),
            ],
          ),

        // Error
        if (state.error != null) ...[
          const SizedBox(height: 16),
          Text(
            state.error!,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  // ── Done view ──────────────────────────────────────────────────────────────

  Widget _doneView(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    RecorderStateData state,
    RecorderNotifier notifier,
  ) {
    final recording = state.lastRecording;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _handle(cs),
        const SizedBox(height: 24),

        // Checkmark
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded,
              color: cs.onPrimaryContainer, size: 36),
        ),
        const SizedBox(height: 16),

        Text(
          'Recording saved!',
          style:
              theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Processing your note in the background…',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: cs.onSurface.withValues(alpha: 0.55)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),

        // View Transcript button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.text_snippet_outlined),
            label: const Text('View Transcript'),
            onPressed: recording == null
                ? null
                : () {
                    Navigator.of(context).pop();
                    notifier.reset();
                    context.push(
                      kRouteTranscript.replaceAll(
                          ':recordingId', recording.id),
                    );
                  },
          ),
        ),
        const SizedBox(height: 12),

        // View Notes button
        SizedBox(
          width: double.infinity,
          child: _NoteButton(recording: recording, notifier: notifier),
        ),
        const SizedBox(height: 16),

        // Dismiss
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            notifier.reset();
          },
          child: const Text('Done'),
        ),
      ],
    );
  }

  // ── Live transcript box ────────────────────────────────────────────────────

  Widget _liveTranscriptBox(
      ThemeData theme, ColorScheme cs, RecorderStateData state) {
    final hasText = state.liveText.isNotEmpty;
    return Container(
      constraints: const BoxConstraints(maxHeight: 120),
      width: double.infinity,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.2),
        ),
      ),
      child: hasText
          ? SingleChildScrollView(
              controller: _liveScrollController,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                state.liveText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ),
            )
          : Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: cs.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Listening…',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurface.withValues(alpha: 0.4),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _handle(ColorScheme cs) => Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(2),
        ),
      );

  String _titleFor(RecorderStateData state) {
    if (state.isRecording) {
      return state.elapsedMs >= 8 * 60 * 1000
          ? '⚠️  2 minutes left'
          : 'Recording…';
    }
    if (state.isPaused) return 'Paused';
    if (state.isUploading) return 'Saving…';
    return 'Tap to start';
  }

  Color _timerColor(RecorderStateData state, ColorScheme cs) {
    if (state.elapsedMs >= 8 * 60 * 1000) return cs.error;
    if (state.isRecording) return cs.primary;
    return cs.onSurface.withValues(alpha: 0.5);
  }

  String _formatTime(int ms) {
    final total = ms ~/ 1000;
    final m = total ~/ 60;
    final s = total % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _idleWave(ColorScheme cs) => Center(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          color: cs.onSurface.withValues(alpha: 0.15),
        ),
      );

  Widget _mainButton(
    BuildContext context,
    WidgetRef ref,
    RecorderStateData state,
    ColorScheme cs,
  ) {
    final notifier = ref.read(recorderProvider.notifier);

    if (state.isIdle) {
      return _bigBtn(
        icon: Icons.mic_rounded,
        color: cs.primary,
        tooltip: 'Start recording',
        onTap: () => notifier.start(projectId: widget.projectId),
      );
    }
    if (state.isRecording) {
      return _bigBtn(
        icon: Icons.pause_rounded,
        color: cs.secondary,
        tooltip: 'Pause',
        onTap: () => notifier.pause(),
      );
    }
    if (state.isPaused) {
      return _bigBtn(
        icon: Icons.mic_rounded,
        color: cs.primary,
        tooltip: 'Resume',
        onTap: () => notifier.resume(),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _bigBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
      );

  Widget _iconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
                  Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      );
}

// ── Note navigation button — polls until the note is ready ─────────────────

class _NoteButton extends ConsumerStatefulWidget {
  const _NoteButton({required this.recording, required this.notifier});

  final dynamic recording; // Recording?
  final RecorderNotifier notifier;

  @override
  ConsumerState<_NoteButton> createState() => _NoteButtonState();
}

class _NoteButtonState extends ConsumerState<_NoteButton> {
  String? _noteId;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    if (widget.recording != null) _pollForNote();
  }

  Future<void> _pollForNote() async {
    setState(() => _polling = true);
    final recordingId = widget.recording!.id as String;

    // Poll every 3 seconds for up to 2 minutes
    for (var i = 0; i < 40; i++) {
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;

      try {
        final data = await supabase
            .from('notes')
            .select('id')
            .eq('recording_id', recordingId)
            .maybeSingle();

        if (data != null) {
          if (mounted) setState(() => _noteId = data['id'] as String);
          break;
        }
      } catch (_) {}
    }

    if (mounted) setState(() => _polling = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_noteId != null) {
      return FilledButton.icon(
        icon: const Icon(Icons.description_outlined),
        label: const Text('View Notes'),
        onPressed: () {
          Navigator.of(context).pop();
          widget.notifier.reset();
          context.push('/notes/$_noteId');
        },
      );
    }

    return FilledButton.icon(
      icon: _polling
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.description_outlined),
      label: Text(_polling ? 'Processing note…' : 'View Notes'),
      onPressed: null, // disabled until note is ready
    );
  }
}
