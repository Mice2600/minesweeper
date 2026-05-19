import 'package:flutter/material.dart';

/// Deterministic avatar: gradient derived from the seed + initial(s).
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.seed,
    required this.label,
    this.size = 40,
    this.color,
  });

  final String seed;
  final String label;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final hash = seed.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xFFFFFFFF);
    final base = color ?? Color(0xFF000000 | (hash & 0x00FFFFFF));
    final hslA = HSLColor.fromColor(base);
    final hslB = hslA.withLightness(
        (hslA.lightness + 0.18).clamp(0.0, 1.0));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hslA.toColor(), hslB.toColor()],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: base.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(label),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  static String _initials(String label) {
    final cleaned = label.trim();
    if (cleaned.isEmpty) return '?';
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts[1].substring(0, 1))
        .toUpperCase();
  }
}
