import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CellTile extends StatelessWidget {
  const CellTile({
    super.key,
    required this.value, // -2 hidden, -1 mine, 0..8 number
    required this.flagColor,
    required this.questionColor,
    required this.size,
    required this.x,
    required this.y,
    this.highlight = false,
    this.won = false,
    this.wasExploded = false,
  });

  /// -2 hidden, -1 mine, 0..8 number.
  final int value;
  final Color? flagColor;
  final Color? questionColor;
  final double size;
  final int x;
  final int y;
  final bool highlight;

  /// Game ended in a win. When true, mines are tinted by outcome:
  /// green if [flagColor] is non-null (correctly flagged), dark red if
  /// [wasExploded] is true (Hearts-mode detonation), neutral otherwise.
  final bool won;

  /// This mine was detonated mid-play (came through SRevealed with -1),
  /// as opposed to being revealed at game-end by SGameOver.
  final bool wasExploded;

  // Dark color used by [BoardEdgesPainter] for the cliff between hidden
  // and revealed regions.
  static const hiddenEdge = Color(0xFF4A7A1F);

  // Google-Minesweeper grass / dirt checkerboard.
  static const _hiddenLight = Color(0xFFAAD751);
  static const _hiddenDark = Color(0xFFA2D149);
  static const _hiddenHover = Color(0xFFBFE17D);
  static const _revealedLight = Color(0xFFE5C29F);
  static const _revealedDark = Color(0xFFD7B899);
  static const _mineBg = Color(0xFFDB3236);
  static const _mineBgCorrect = Color(0xFF2E7D32); // green 800
  static const _mineBgExploded = Color(0xFF7F0000); // dark red

  static const _numberColors = <Color>[
    Colors.transparent,
    Color(0xFF1976D2), // 1 blue
    Color(0xFF388E3C), // 2 green
    Color(0xFFD32F2F), // 3 red
    Color(0xFF7B1FA2), // 4 purple
    Color(0xFFFF8F00), // 5 orange
    Color(0xFF0097A7), // 6 teal
    Color(0xFF424242), // 7 dark grey
    Color(0xFFC2185B), // 8 pink
  ];

  @override
  Widget build(BuildContext context) {
    final hidden = value == -2;
    final isMine = value == -1;
    final even = (x + y).isEven;

    final Color bg;
    if (hidden) {
      bg = highlight
          ? _hiddenHover
          : (even ? _hiddenLight : _hiddenDark);
    } else if (isMine) {
      if (won && flagColor != null) {
        bg = _mineBgCorrect;
      } else if (won && wasExploded) {
        bg = _mineBgExploded;
      } else {
        bg = _mineBg;
      }
    } else {
      bg = even ? _revealedLight : _revealedDark;
    }

    Widget content;
    if (hidden && flagColor != null) {
      content = Icon(
        Icons.flag_rounded,
        color: flagColor,
        size: size * 0.6,
        shadows: const [
          Shadow(
            color: Color(0x55000000),
            blurRadius: 1.5,
            offset: Offset(0.8, 0.8),
          ),
        ],
      );
    } else if (hidden && questionColor != null) {
      content = Text(
        '?',
        style: GoogleFonts.jetBrainsMono(
          fontSize: size * 0.72,
          fontWeight: FontWeight.w900,
          color: questionColor,
          height: 1.0,
          shadows: const [
            Shadow(
              color: Color(0x55000000),
              blurRadius: 1.5,
              offset: Offset(0.8, 0.8),
            ),
          ],
        ),
      );
    } else if (isMine) {
      content = Icon(
        Icons.brightness_low_rounded,
        color: Colors.black87,
        size: size * 0.7,
      );
    } else if (value > 0) {
      content = Text(
        '$value',
        style: GoogleFonts.jetBrainsMono(
          fontSize: size * 0.62,
          fontWeight: FontWeight.w900,
          color: _numberColors[value],
          height: 1.0,
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(color: bg),
      alignment: Alignment.center,
      child: content,
    );
  }
}
