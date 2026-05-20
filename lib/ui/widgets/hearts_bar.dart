import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Displays N hearts; the first (current..total) are filled and red, the
/// remaining are outlined and dim. The most recently lost heart shakes briefly.
class HeartsBar extends StatelessWidget {
  const HeartsBar({
    super.key,
    required this.current,
    required this.total,
  });

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Heart(
              key: ValueKey('h$i'),
              filled: i < current,
              isLastLost: i == current,
            ),
          ),
      ],
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({super.key, required this.filled, required this.isLastLost});
  final bool filled;
  final bool isLastLost;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = filled ? const Color(0xFFE53935) : cs.outlineVariant;
    final icon = Icon(
      filled ? Icons.favorite_rounded : Icons.heart_broken_rounded,
      color: color,
      size: 36,
    );
    if (isLastLost && !filled) {
      // Shake on heart loss.
      return icon
          .animate(key: ValueKey(isLastLost))
          .shake(
            duration: 600.ms,
            hz: 6,
            curve: Curves.easeOut,
            offset: const Offset(2, 0),
          )
          .tint(
            color: cs.error,
            duration: 300.ms,
          );
    }
    return icon;
  }
}
