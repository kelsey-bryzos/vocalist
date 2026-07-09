import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Animated waveform that shows a rolling history of amplitude bars.
class WaveformBars extends StatefulWidget {
  const WaveformBars({
    super.key,
    required this.amplitude,
    this.barCount = 40,
    this.color,
  });

  final double amplitude; // 0.0–1.0, updated each tick
  final int barCount;
  final Color? color;

  @override
  State<WaveformBars> createState() => _WaveformBarsState();
}

class _WaveformBarsState extends State<WaveformBars> {
  final _history = <double>[];

  @override
  void didUpdateWidget(WaveformBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.amplitude != widget.amplitude) {
      setState(() {
        _history.add(widget.amplitude);
        if (_history.length > widget.barCount) _history.removeAt(0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? Theme.of(context).colorScheme.primary;

    return LayoutBuilder(builder: (context, constraints) {
      final barWidth = (constraints.maxWidth / widget.barCount) * 0.6;
      final maxHeight = constraints.maxHeight;

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(widget.barCount, (i) {
          final amp = i < _history.length ? _history[i] : 0.0;
          final height = math.max(4.0, amp * maxHeight);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: barWidth,
            height: height,
            margin: EdgeInsets.symmetric(
              horizontal: (constraints.maxWidth / widget.barCount) * 0.2,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.4 + amp * 0.6),
              borderRadius: BorderRadius.circular(barWidth / 2),
            ),
          );
        }),
      );
    });
  }
}
