import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Falling/bursting confetti for the win moment. Self-contained: spawns a fixed
/// set of pieces from a seed (deterministic so it survives rebuilds) and drives
/// them with one [AnimationController]. Drawn in a single [CustomPaint] pass.
class Confetti extends StatefulWidget {
  const Confetti({
    super.key,
    this.pieces = 90,
    this.duration = const Duration(milliseconds: 4200),
    this.colors = const [
      Color(0xFFFFC93C),
      Color(0xFF9CCC65),
      Color(0xFF4C9A2A),
      Color(0xFFEE7B30),
      Color(0xFF3B82C4),
      Color(0xFFE94F64),
    ],
    this.burst = true,
  });

  final int pieces;
  final Duration duration;
  final List<Color> colors;

  /// When true, pieces launch upward/outward from the lower-center (a "pop")
  /// then fall. When false they simply rain from the top.
  final bool burst;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = math.Random(7);
    _pieces = List.generate(widget.pieces, (i) {
      return _Piece(
        startX: rng.nextDouble(),
        startY: widget.burst ? 0.55 + rng.nextDouble() * 0.1 : -0.1 - rng.nextDouble() * 0.2,
        vx: (rng.nextDouble() - 0.5) * (widget.burst ? 1.5 : 0.4),
        vy: widget.burst ? -(0.7 + rng.nextDouble() * 0.9) : (0.25 + rng.nextDouble() * 0.5),
        size: 6 + rng.nextDouble() * 8,
        color: widget.colors[rng.nextInt(widget.colors.length)],
        rotSpeed: (rng.nextDouble() - 0.5) * 12,
        phase: rng.nextDouble() * math.pi * 2,
        delay: widget.burst ? rng.nextDouble() * 0.12 : rng.nextDouble() * 0.6,
        round: rng.nextBool(),
      );
    });
    _c = AnimationController(vsync: this, duration: widget.duration)..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, _c.value, widget.burst),
          ),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.startX,
    required this.startY,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.rotSpeed,
    required this.phase,
    required this.delay,
    required this.round,
  });
  final double startX;
  final double startY;
  final double vx;
  final double vy;
  final double size;
  final Color color;
  final double rotSpeed;
  final double phase;
  final double delay;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t, this.burst);
  final List<_Piece> pieces;
  final double t;
  final bool burst;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const gravity = 0.9;
    for (final p in pieces) {
      final lt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (lt <= 0) continue;
      // Position: start + velocity*t + gravity (downward) integrated.
      final x = (p.startX + p.vx * lt) * size.width +
          math.sin(p.phase + lt * 6) * 8;
      final y = (p.startY + p.vy * lt + 0.5 * gravity * lt * lt) * size.height;
      if (y > size.height + 20) continue;
      // Fade out near the end of life.
      final alpha = burst ? (1.0 - lt * lt).clamp(0.0, 1.0) : (1.0 - lt).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: alpha);
      final rot = p.phase + lt * p.rotSpeed;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rot);
      final w = p.size;
      final h = p.size * 0.55;
      if (p.round) {
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: w), paint);
      } else {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: w, height: h), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
