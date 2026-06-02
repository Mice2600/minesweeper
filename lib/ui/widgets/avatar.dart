import 'dart:convert';

import 'package:flutter/material.dart';

/// Avatar widget. When [avatarData] (base64 JPEG) is provided it shows the
/// real photo; otherwise falls back to a deterministic gradient + initials
/// derived from [seed] and [label].
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.seed,
    required this.label,
    this.avatarData,
    this.size = 40,
    this.color,
  });

  final String seed;
  final String label;

  /// Base64-encoded JPEG. When non-null, shown instead of the gradient.
  final String? avatarData;

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final data = avatarData;
    if (data != null) {
      return _PhotoAvatar(key: ValueKey(data), data: data, size: size);
    }

    final hash =
        seed.codeUnits.fold<int>(7, (a, c) => (a * 31 + c) & 0xFFFFFFFF);
    final base = color ?? Color(0xFF000000 | (hash & 0x00FFFFFF));
    final hslA = HSLColor.fromColor(base);
    final hslB =
        hslA.withLightness((hslA.lightness + 0.18).clamp(0.0, 1.0));

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

class _PhotoAvatar extends StatefulWidget {
  const _PhotoAvatar({super.key, required this.data, required this.size});
  final String data;
  final double size;

  @override
  State<_PhotoAvatar> createState() => _PhotoAvatarState();
}

class _PhotoAvatarState extends State<_PhotoAvatar> {
  late final _bytes = base64Decode(widget.data);

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.memory(
        _bytes,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
