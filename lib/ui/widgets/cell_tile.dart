import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CellTile extends StatelessWidget {
  const CellTile({
    super.key,
    required this.value, // -2 hidden, -1 mine, 0..8 number
    required this.flagColor,
    required this.size,
    this.highlight = false,
  });

  /// -2 hidden, -1 mine, 0..8 number.
  final int value;
  final Color? flagColor;
  final double size;
  final bool highlight;

  static const _numberColors = <Color>[
    Colors.transparent,
    Color(0xFF1565C0), // 1 blue
    Color(0xFF2E7D32), // 2 green
    Color(0xFFC62828), // 3 red
    Color(0xFF6A1B9A), // 4 purple
    Color(0xFF6D4C41), // 5 brown
    Color(0xFF00838F), // 6 cyan
    Color(0xFF424242), // 7 grey
    Color(0xFFD81B60), // 8 pink
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hidden = value == -2;
    final isMine = value == -1;

    final bg = hidden
        ? (highlight
            ? cs.primaryContainer
            : cs.surfaceContainerHigh)
        : isMine
            ? cs.errorContainer
            : cs.surface;

    final border = hidden
        ? cs.outlineVariant
        : cs.outlineVariant.withValues(alpha: 0.4);

    Widget content;
    if (hidden && flagColor != null) {
      content = Icon(
        Icons.flag_rounded,
        color: flagColor,
        size: size * 0.6,
      );
    } else if (isMine) {
      content = Icon(Icons.brightness_low_rounded,
          color: cs.error, size: size * 0.6);
    } else if (value > 0) {
      content = Text(
        '$value',
        style: GoogleFonts.jetBrainsMono(
          fontSize: size * 0.55,
          fontWeight: FontWeight.w800,
          color: _numberColors[value],
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 0.5),
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      alignment: Alignment.center,
      child: content,
    );
  }
}
