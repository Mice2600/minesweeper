import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/board_skin.dart';

class CellTile extends StatelessWidget {
  const CellTile({
    super.key,
    required this.value, // -2 hidden, -1 mine, 0..8 number
    required this.flagColor,
    required this.questionColor,
    required this.size,
    required this.x,
    required this.y,
    required this.skin,
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

  /// Color + structure set for the board. All cell visuals are sourced here.
  final BoardSkin skin;
  final bool highlight;

  /// Game ended in a win. When true, mines are tinted by outcome:
  /// green if [flagColor] is non-null (correctly flagged), dark red if
  /// [wasExploded] is true (Hearts-mode detonation), neutral otherwise.
  final bool won;

  /// This mine was detonated mid-play (came through SRevealed with -1),
  /// as opposed to being revealed at game-end by SGameOver.
  final bool wasExploded;

  static const _glyphShadows = [
    Shadow(color: Color(0x55000000), blurRadius: 1.5, offset: Offset(0.8, 0.8)),
  ];

  @override
  Widget build(BuildContext context) {
    final hidden = value == -2;
    final isMine = value == -1;
    final even = (x + y).isEven;

    final bg = _bg(hidden, isMine, even);

    Widget cell = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: _decoration(hidden, bg),
      alignment: Alignment.center,
      child: _content(hidden, isMine),
    );

    // Gap is a STATIC inner padding inside the full cell box, so hit-testing
    // (pos ~/ cellSize on the full rect) is unaffected. Grass has gap 0 → no
    // Padding widget at all, keeping the default path identical.
    final gap = size * skin.cellGapFrac;
    if (gap > 0) {
      cell = Padding(padding: EdgeInsets.all(gap), child: cell);
    }
    return cell;
  }

  Color _bg(bool hidden, bool isMine, bool even) {
    if (hidden) {
      if (highlight) return skin.hiddenHover;
      if (!skin.checkerboard) return skin.hiddenLight;
      return even ? skin.hiddenLight : skin.hiddenDark;
    }
    if (isMine) {
      if (won && flagColor != null) return skin.mineBgCorrect;
      if (won && wasExploded) return skin.mineBgExploded;
      return skin.mineBg;
    }
    if (!skin.checkerboard) return skin.revealedLight;
    return even ? skin.revealedLight : skin.revealedDark;
  }

  /// Builds the cell's [BoxDecoration] for the active [BoardSkin.structure].
  /// Grass returns a bare `BoxDecoration(color: bg)` — byte-for-byte the
  /// original look.
  BoxDecoration _decoration(bool hidden, Color bg) {
    switch (skin.structure) {
      case CellStructure.grass:
        return BoxDecoration(color: bg);

      case CellStructure.flat:
        return BoxDecoration(
          color: bg,
          border: Border.all(
            color: skin.cellBorderColor,
            width: skin.cellBorderWidth,
          ),
        );

      case CellStructure.tile:
        return BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size * skin.cellRadiusFrac),
          boxShadow: hidden && skin.tileRaiseFrac > 0
              ? [
                  BoxShadow(
                    color: const Color(0x33000000),
                    blurRadius: size * skin.tileRaiseFrac,
                    offset: Offset(0, size * skin.tileRaiseFrac * 0.45),
                  ),
                ]
              : null,
        );

      case CellStructure.bevel:
        final w = size * skin.bevelWidthFrac;
        if (hidden) {
          // Win95 raised: bright top/left, dark bottom/right.
          return BoxDecoration(
            color: bg,
            border: Border(
              top: BorderSide(color: skin.raisedLight, width: w),
              left: BorderSide(color: skin.raisedLight, width: w),
              bottom: BorderSide(color: skin.raisedDark, width: w),
              right: BorderSide(color: skin.raisedDark, width: w),
            ),
          );
        }
        // Revealed / mine: flat sunken with a thin uniform border.
        return BoxDecoration(
          color: bg,
          border: Border.all(
            color: skin.cellBorderColor,
            width: skin.cellBorderWidth > 0 ? skin.cellBorderWidth : 1.0,
          ),
        );

      case CellStructure.neon:
        final r = size * skin.cellRadiusFrac;
        return BoxDecoration(
          color: bg,
          borderRadius: r > 0 ? BorderRadius.circular(r) : null,
          border: Border.all(
            color: skin.cellBorderColor,
            width: skin.cellBorderWidth,
          ),
          // Glow only on uncleared (hidden) cells: a luminous grid that dims as
          // the board is solved, and far cheaper than glowing every cell.
          boxShadow: hidden && skin.glowBlurFrac > 0
              ? [
                  BoxShadow(
                    color: skin.glowColor,
                    blurRadius: size * skin.glowBlurFrac,
                  ),
                ]
              : null,
        );

      case CellStructure.neumorphic:
        final d = size * 0.08;
        final b = size * 0.12;
        return BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(size * skin.cellRadiusFrac),
          // Soft dual drop shadow on raised (hidden) cells; revealed cells lie
          // flat/recessed.
          boxShadow: hidden
              ? [
                  BoxShadow(
                    color: skin.raisedLight,
                    offset: Offset(-d, -d),
                    blurRadius: b,
                  ),
                  BoxShadow(
                    color: skin.raisedDark,
                    offset: Offset(d, d),
                    blurRadius: b,
                  ),
                ]
              : null,
        );
    }
  }

  Widget _content(bool hidden, bool isMine) {
    if (hidden && flagColor != null) return _flag();
    if (hidden && questionColor != null) return _question();
    if (isMine) return _mine();
    if (value > 0) return _number();
    return const SizedBox.shrink();
  }

  Widget _flag() {
    switch (skin.flagGlyph) {
      case FlagGlyph.pennant:
        return Icon(
          Icons.flag_rounded,
          color: flagColor,
          size: size * 0.6,
          shadows: _glyphShadows,
        );
      case FlagGlyph.classicPole:
        return Icon(
          Icons.tour_rounded,
          color: flagColor,
          size: size * 0.62,
          shadows: _glyphShadows,
        );
      case FlagGlyph.dot:
        return Container(
          width: size * 0.42,
          height: size * 0.42,
          decoration: BoxDecoration(
            color: flagColor,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 2,
                offset: Offset(0.5, 1),
              ),
            ],
          ),
        );
    }
  }

  Widget _question() {
    return Text(
      '?',
      style: GoogleFonts.jetBrainsMono(
        fontSize: size * 0.72,
        fontWeight: FontWeight.w900,
        color: questionColor,
        height: 1.0,
        shadows: _glyphShadows,
      ),
    );
  }

  Widget _mine() {
    final icon = skin.mineGlyph == MineGlyph.spoked
        ? Icons.brightness_high_rounded
        : Icons.brightness_low_rounded;
    return Icon(icon, color: skin.mineIconColor, size: size * 0.7);
  }

  Widget _number() {
    return Text(
      '$value',
      style: GoogleFonts.jetBrainsMono(
        fontSize: size * 0.62,
        fontWeight: FontWeight.w900,
        color: skin.numberColors[value],
        height: 1.0,
      ),
    );
  }
}
