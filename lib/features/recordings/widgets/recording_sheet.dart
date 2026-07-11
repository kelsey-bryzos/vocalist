import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/recorder_provider.dart';
import 'waveform_bars.dart';

/// Bottom sheet for recording. Opened from the home FAB.
class RecordingSheet extends ConsumerWidget {
  const RecordingSheet({super.key, this.projectId});

  final String? projectId;

  static Future<void> show(BuildContext context, {String? projectId}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RecordingSheet(projectId: projectId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(recorderProvider);
    final notifier = ref.read(recorderProvider.notifier);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            _titleFor(state),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
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
          const SizedBox(height: 24),

          // Waveform
          SizedBox(
            height: 72,
            child: state.isRecording
                ? WaveformBars(
                    amplitude: state.amplitude,
                    color: cs.primary,
                  )
                : _idleWave(cs, state),
          ),
          const SizedBox(height: 32),

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

                // Main action: Start / Pause / Resume / Stop
                _mainButton(context, ref, state, cs),

                const SizedBox(width: 16),

                // Stop (only while recording or paused)
                if (state.isRecording || state.isPaused)
                  _iconBtn(
                    icon: Icons.stop_rounded,
                    tooltip: 'Stop & save',
                    color: cs.tertiary,
                    onTap: () async {
                      final recording =
                          await notifier.stop(projectId: projectId);
                      // Only close if upload succeeded (recording != null)
                      if (context.mounted && recording != null) {
                        Navigator.of(context).pop(recording);
                      }
                      // If null, error is shown in the sheet — user can retry or cancel
                    },
                  ),
              ],
            ),

          // Error
          if (state.error != null) ...[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.error),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  // ── helpers ──────────────────────────────────────────────────────────────

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

  Widget _idleWave(ColorScheme cs, RecorderStateData state) {
    // Static flat line when idle/paused
    return Center(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        color: cs.onSurface.withValues(alpha: 0.15),
      ),
    );
  }

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
        onTap: () => notifier.start(projectId: projectId),
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
              border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
        ),
      );
}
