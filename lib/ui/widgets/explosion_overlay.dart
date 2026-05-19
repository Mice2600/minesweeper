import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'explosion_timing.dart';

/// Renders an expanding shock-wave ring at each detonation center, on top of
/// the board. `cellSize` is the per-cell square size used by the board.
class ExplosionOverlay extends StatelessWidget {
  const ExplosionOverlay({
    super.key,
    required this.eventId,
    required this.centers,
    required this.cellSize,
  });

  final int eventId;
  final List<List<int>> centers;
  final double cellSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          for (var i = 0; i < centers.length; i++)
            _Ring(
              key: ValueKey('$eventId-$i'),
              x: centers[i][0],
              y: centers[i][1],
              cellSize: cellSize,
              delayMs: i * ExplosionTiming.msPerCenter,
            ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    super.key,
    required this.x,
    required this.y,
    required this.cellSize,
    required this.delayMs,
  });

  final int x;
  final int y;
  final double cellSize;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final cx = (x + 0.5) * cellSize;
    final cy = (y + 0.5) * cellSize;
    final size = cellSize * 5;
    return Positioned(
      left: cx - size / 2,
      top: cy - size / 2,
      width: size,
      height: size,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Color(0xFFFFE082),
              Color(0xCCFF7043),
              Color(0x44E53935),
              Color(0x00000000),
            ],
            stops: [0.0, 0.35, 0.7, 1.0],
          ),
        ),
      )
          .animate(delay: Duration(milliseconds: delayMs))
          .scale(
            duration: Duration(milliseconds: ExplosionTiming.ringDurationMs),
            curve: Curves.easeOut,
            begin: const Offset(0.05, 0.05),
            end: const Offset(1, 1),
          )
          .fadeIn(duration: 80.ms)
          .fadeOut(
            delay: Duration(milliseconds: ExplosionTiming.ringDurationMs - 120),
            duration: 200.ms,
          ),
    );
  }
}
