import 'package:flutter/material.dart';

/// The structural archetype of a skin — how cells are *shaped and bordered*,
/// not just colored. [CellTile] branches its decoration on this; [BoardView]
/// gates the cliff-edge painter, grid overdraw, and the board-background layer
/// on it. [CellStructure.grass] is the original Google-Minesweeper look and the
/// default; every other structural field defaults to a grass no-op so a skin
/// that only sets colors renders exactly like the original board.
enum CellStructure {
  /// Flat checkerboard fill + painted "cliff" edges. The original look.
  grass,

  /// Rounded raised chips separated by a visible gap; [boardBackground] shows
  /// through. Uses a dot flag.
  tile,

  /// Windows-95 raised 3D bevel on hidden cells, flat sunken revealed cells.
  bevel,

  /// Flat uniform cells with a thin hairline border grid. Minimal.
  flat,

  /// Dark cells with a glowing colored border and luminous numbers.
  neon,

  /// Soft monochrome extruded cells (dual light/dark drop shadows).
  neumorphic,
}

/// How a placed flag is drawn.
enum FlagGlyph {
  /// The original rounded pennant ([Icons.flag_rounded]).
  pennant,

  /// A small rounded-square chip with a colored circular pin (tile style).
  dot,

  /// A classic flag-on-a-pole ([Icons.tour_rounded]) for the retro bevel style.
  classicPole,
}

/// How a mine is drawn.
enum MineGlyph {
  /// The original soft dot ([Icons.brightness_low_rounded]).
  soft,

  /// A spoked circle ([Icons.brightness_high_rounded]) for the retro style.
  spoked,
}

/// A complete look for the game board ("skin") — both its **structure**
/// ([structure] + the shape/border/glyph fields below) and its **colors**.
///
/// All structural fields default to the [CellStructure.grass] no-op, so a skin
/// that sets only colors renders byte-for-byte like the original board.
/// [CellTile] reads these to build each cell's decoration and glyphs;
/// [BoardView] reads [structure] to gate the cliff painter, grid overdraw, and
/// the board-background layer. Swapping the active skin re-renders instantly.
///
/// Contrast rule: [hiddenLight]/[hiddenDark] (un-dug) and [revealedLight]/
/// [revealedDark] (dug-empty) should differ clearly in brightness AND hue — as
/// grass→dirt does — so a cleared blank cell is obviously distinct from an
/// un-dug one.
@immutable
class BoardSkin {
  const BoardSkin({
    required this.id,
    required this.name,
    required this.hiddenLight,
    required this.hiddenDark,
    required this.hiddenHover,
    required this.hiddenEdge,
    required this.revealedLight,
    required this.revealedDark,
    required this.mineBg,
    required this.mineBgCorrect,
    required this.mineBgExploded,
    required this.mineIconColor,
    required this.numberColors,
    this.structure = CellStructure.grass,
    this.boardBackground = Colors.transparent,
    this.cellRadiusFrac = 0.0,
    this.cellGapFrac = 0.0,
    this.cellBorderWidth = 0.0,
    this.cellBorderColor = Colors.transparent,
    this.bevelWidthFrac = 0.0,
    this.raisedLight = Colors.transparent,
    this.raisedDark = Colors.transparent,
    this.tileRaiseFrac = 0.0,
    this.glowColor = Colors.transparent,
    this.glowBlurFrac = 0.0,
    this.checkerboard = true,
    this.flagGlyph = FlagGlyph.pennant,
    this.mineGlyph = MineGlyph.soft,
  });

  /// Stable key (kebab-ish). Not shown to the user.
  final String id;

  /// Display label shown in the picker.
  final String name;

  // Hidden-cell checkerboard + hover highlight.
  final Color hiddenLight;
  final Color hiddenDark;
  final Color hiddenHover;

  /// Dark "cliff" stroke between hidden and revealed regions (grass only).
  final Color hiddenEdge;

  // Revealed-cell checkerboard.
  final Color revealedLight;
  final Color revealedDark;

  // Mine tile backgrounds: default detonation, correctly-flagged (win), and
  // detonated-on-win.
  final Color mineBg;
  final Color mineBgCorrect;
  final Color mineBgExploded;

  /// Color of the mine glyph drawn on a mine tile.
  final Color mineIconColor;

  /// Number colors, indexed by adjacent-mine count. Length 9; index 0 is
  /// transparent (empty cell, never drawn).
  final List<Color> numberColors;

  // ── Structure ──────────────────────────────────────────────────────────
  // All of the following default to a grass no-op (no shape/border change), so
  // the original 10 color skins inherit them and render identically.

  /// Structural archetype. See [CellStructure].
  final CellStructure structure;

  /// Color painted behind cells; only visible through gaps. Used by [tile];
  /// transparent (and not mounted) otherwise.
  final Color boardBackground;

  /// Corner radius as a fraction of the cell size (`tile`/`neumorphic`).
  final double cellRadiusFrac;

  /// Visual gap between cells as a fraction of the cell size, applied as a
  /// static inner padding so hit-testing is unaffected (`tile`).
  final double cellGapFrac;

  /// Thin hairline border width in logical px (`flat`; sunken revealed bevel).
  final double cellBorderWidth;

  /// Hairline border color (`flat`) / sunken border color (`bevel` revealed).
  final Color cellBorderColor;

  /// 3D bevel thickness as a fraction of the cell size (`bevel`).
  final double bevelWidthFrac;

  /// Top/left highlight edge (`bevel`) — also the light drop shadow
  /// (`neumorphic`).
  final Color raisedLight;

  /// Bottom/right shadow edge (`bevel`) — also the dark drop shadow
  /// (`neumorphic`).
  final Color raisedDark;

  /// Soft drop-shadow strength on raised chips as a fraction of the cell size
  /// (`tile`).
  final double tileRaiseFrac;

  /// Glow color around cells (`neon`).
  final Color glowColor;

  /// Glow blur radius as a fraction of the cell size (`neon`).
  final double glowBlurFrac;

  /// When false, hidden/revealed use a single uniform color instead of the
  /// `(x+y).isEven` checkerboard (`bevel`/`flat`/`neon`/`neumorphic`).
  final bool checkerboard;

  /// How placed flags are drawn.
  final FlagGlyph flagGlyph;

  /// How mines are drawn.
  final MineGlyph mineGlyph;
}

/// All selectable board skins. Index 0 ([kDefaultBoardSkin]) reproduces the
/// original hardcoded Google-Minesweeper grass/dirt look exactly. The first 10
/// are the original flat-grass color variants; the rest add distinct
/// structures (tile / bevel / flat / neon / neumorphic), each in several
/// palettes.
const List<BoardSkin> kBoardSkins = [
  // 1. Classic Grass — pixel-identical to the original board.
  BoardSkin(
    id: 'classic',
    name: 'Classic Grass',
    hiddenLight: Color(0xFFAAD751),
    hiddenDark: Color(0xFFA2D149),
    hiddenHover: Color(0xFFBFE17D),
    hiddenEdge: Color(0xFF4A7A1F),
    revealedLight: Color(0xFFE5C29F),
    revealedDark: Color(0xFFD7B899),
    mineBg: Color(0xFFDB3236),
    mineBgCorrect: Color(0xFF2E7D32),
    mineBgExploded: Color(0xFF7F0000),
    mineIconColor: Colors.black87,
    numberColors: [
      Colors.transparent,
      Color(0xFF1976D2), // 1 blue
      Color(0xFF388E3C), // 2 green
      Color(0xFFD32F2F), // 3 red
      Color(0xFF7B1FA2), // 4 purple
      Color(0xFFFF8F00), // 5 orange
      Color(0xFF0097A7), // 6 teal
      Color(0xFF424242), // 7 dark grey
      Color(0xFFC2185B), // 8 pink
    ],
  ),

  // 2. Midnight — dark slate cells, light readable numbers.
  BoardSkin(
    id: 'midnight',
    name: 'Midnight',
    hiddenLight: Color(0xFF3A4256),
    hiddenDark: Color(0xFF333B4D),
    hiddenHover: Color(0xFF4C566E),
    hiddenEdge: Color(0xFF1B2030),
    revealedLight: Color(0xFF222838),
    revealedDark: Color(0xFF1E2433),
    mineBg: Color(0xFFE2466B),
    mineBgCorrect: Color(0xFF3DA46B),
    mineBgExploded: Color(0xFF7A1030),
    mineIconColor: Color(0xFFEFF2FA),
    numberColors: [
      Colors.transparent,
      Color(0xFF64B5F6), // 1
      Color(0xFF81C784), // 2
      Color(0xFFE57373), // 3
      Color(0xFFBA8FE0), // 4
      Color(0xFFFFB74D), // 5
      Color(0xFF4DD0E1), // 6
      Color(0xFFB0BEC5), // 7
      Color(0xFFF06292), // 8
    ],
  ),

  // 3. Neon Grid — near-black cells, saturated neon numbers, cyan edge.
  BoardSkin(
    id: 'neon',
    name: 'Neon Grid',
    hiddenLight: Color(0xFF14233A),
    hiddenDark: Color(0xFF0F1B2D),
    hiddenHover: Color(0xFF1E3A5C),
    hiddenEdge: Color(0xFF00E5FF),
    revealedLight: Color(0xFF0A0F18),
    revealedDark: Color(0xFF070B12),
    mineBg: Color(0xFFFF1744),
    mineBgCorrect: Color(0xFF00E676),
    mineBgExploded: Color(0xFF880E4F),
    mineIconColor: Color(0xFFE0F7FF),
    numberColors: [
      Colors.transparent,
      Color(0xFF00E5FF), // 1 cyan
      Color(0xFF00FF9C), // 2 green
      Color(0xFFFF3D7F), // 3 hot pink
      Color(0xFFB388FF), // 4 violet
      Color(0xFFFFD740), // 5 yellow
      Color(0xFF18FFFF), // 6 aqua
      Color(0xFFFF6E40), // 7 orange
      Color(0xFFFF4081), // 8 magenta
    ],
  ),

  // 4. Desert Sand — warm tans and ochres.
  BoardSkin(
    id: 'desert',
    name: 'Desert Sand',
    hiddenLight: Color(0xFFE8C887),
    hiddenDark: Color(0xFFE0BD77),
    hiddenHover: Color(0xFFF1D9A0),
    hiddenEdge: Color(0xFF9C6F2E),
    revealedLight: Color(0xFFF3E4C4),
    revealedDark: Color(0xFFEAD8B0),
    mineBg: Color(0xFFC8472B),
    mineBgCorrect: Color(0xFF6B8E23),
    mineBgExploded: Color(0xFF6E2410),
    mineIconColor: Color(0xFF3E2A12),
    numberColors: [
      Colors.transparent,
      Color(0xFF1565C0), // 1
      Color(0xFF2E7D32), // 2
      Color(0xFFB23A1E), // 3
      Color(0xFF6A1B9A), // 4
      Color(0xFFD17B00), // 5
      Color(0xFF00796B), // 6
      Color(0xFF5D4037), // 7
      Color(0xFFAD1457), // 8
    ],
  ),

  // 5. Ocean — blue/teal hidden cells, sandy revealed.
  BoardSkin(
    id: 'ocean',
    name: 'Ocean',
    hiddenLight: Color(0xFF3FA9C9),
    hiddenDark: Color(0xFF359BBA),
    hiddenHover: Color(0xFF63C2DE),
    hiddenEdge: Color(0xFF124559),
    revealedLight: Color(0xFFEAD9B8),
    revealedDark: Color(0xFFDCC9A2),
    mineBg: Color(0xFFE34F4F),
    mineBgCorrect: Color(0xFF2E9E6B),
    mineBgExploded: Color(0xFF6E1414),
    mineIconColor: Color(0xFF0B2530),
    numberColors: [
      Colors.transparent,
      Color(0xFF0D47A1), // 1
      Color(0xFF1B7A3D), // 2
      Color(0xFFC62828), // 3
      Color(0xFF6A3DB0), // 4
      Color(0xFFE07B00), // 5
      Color(0xFF00838F), // 6
      Color(0xFF37474F), // 7
      Color(0xFFAD1457), // 8
    ],
  ),

  // 6. Sakura — soft pinks and mauve.
  BoardSkin(
    id: 'sakura',
    name: 'Sakura',
    hiddenLight: Color(0xFFF3B6CD),
    hiddenDark: Color(0xFFEEA9C4),
    hiddenHover: Color(0xFFF9CEDE),
    hiddenEdge: Color(0xFFB05478),
    revealedLight: Color(0xFFFCEAF1),
    revealedDark: Color(0xFFF6DCE7),
    mineBg: Color(0xFFD81B60),
    mineBgCorrect: Color(0xFF5DA271),
    mineBgExploded: Color(0xFF7A1038),
    mineIconColor: Color(0xFF4A1B30),
    numberColors: [
      Colors.transparent,
      Color(0xFF5C6BC0), // 1
      Color(0xFF43A047), // 2
      Color(0xFFD83A56), // 3
      Color(0xFF8E44AD), // 4
      Color(0xFFEF6C00), // 5
      Color(0xFF00897B), // 6
      Color(0xFF6D4C5A), // 7
      Color(0xFFC2185B), // 8
    ],
  ),

  // 7. Volcano — charcoal cells with red/orange numbers and lava-glow mines.
  BoardSkin(
    id: 'volcano',
    name: 'Volcano',
    hiddenLight: Color(0xFF39322E),
    hiddenDark: Color(0xFF312A26),
    hiddenHover: Color(0xFF4D423B),
    hiddenEdge: Color(0xFF120D0B),
    revealedLight: Color(0xFF221C19),
    revealedDark: Color(0xFF1C1714),
    mineBg: Color(0xFFFF5722),
    mineBgCorrect: Color(0xFF4CAF50),
    mineBgExploded: Color(0xFFB71C1C),
    mineIconColor: Color(0xFFFFE0B2),
    numberColors: [
      Colors.transparent,
      Color(0xFFFFB300), // 1
      Color(0xFFFF7043), // 2
      Color(0xFFFF5252), // 3
      Color(0xFFFFCA28), // 4
      Color(0xFFFF8A65), // 5
      Color(0xFFFFD54F), // 6
      Color(0xFFE0E0E0), // 7
      Color(0xFFEF5350), // 8
    ],
  ),

  // 8. Emerald Forest — deep greens, mossy revealed.
  BoardSkin(
    id: 'emerald',
    name: 'Emerald Forest',
    hiddenLight: Color(0xFF2E7D5B),
    hiddenDark: Color(0xFF286F51),
    hiddenHover: Color(0xFF3E9A72),
    hiddenEdge: Color(0xFF123524),
    revealedLight: Color(0xFFCBBF95),
    revealedDark: Color(0xFFBEB186),
    mineBg: Color(0xFFD84343),
    mineBgCorrect: Color(0xFF1B5E20),
    mineBgExploded: Color(0xFF611212),
    mineIconColor: Color(0xFF14241A),
    numberColors: [
      Colors.transparent,
      Color(0xFF1565C0), // 1
      Color(0xFF1B5E20), // 2
      Color(0xFFC62828), // 3
      Color(0xFF6A1B9A), // 4
      Color(0xFFD17B00), // 5
      Color(0xFF00695C), // 6
      Color(0xFF3E2723), // 7
      Color(0xFFAD1457), // 8
    ],
  ),

  // 9. Candy Pastel — light pastel checkerboard, candy-bright numbers.
  BoardSkin(
    id: 'candy',
    name: 'Candy Pastel',
    hiddenLight: Color(0xFFB5E2D3),
    hiddenDark: Color(0xFFA8DBC9),
    hiddenHover: Color(0xFFCBEEE2),
    hiddenEdge: Color(0xFF6FB5A0),
    revealedLight: Color(0xFFFDEFF6),
    revealedDark: Color(0xFFF6E1EE),
    mineBg: Color(0xFFFF6F91),
    mineBgCorrect: Color(0xFF66BB6A),
    mineBgExploded: Color(0xFFAD1457),
    mineIconColor: Color(0xFF5A3A47),
    numberColors: [
      Colors.transparent,
      Color(0xFF4FA3E3), // 1
      Color(0xFF55C277), // 2
      Color(0xFFF26D7D), // 3
      Color(0xFFAB7DDA), // 4
      Color(0xFFFFA24D), // 5
      Color(0xFF3FC1C9), // 6
      Color(0xFF8D6E63), // 7
      Color(0xFFEC6FA8), // 8
    ],
  ),

  // 10. Newspaper (Mono) — greyscale cells and numbers, classic print look.
  BoardSkin(
    id: 'newspaper',
    name: 'Newspaper',
    hiddenLight: Color(0xFFBDBDBD),
    hiddenDark: Color(0xFFB2B2B2),
    hiddenHover: Color(0xFFD4D4D4),
    hiddenEdge: Color(0xFF4A4A4A),
    revealedLight: Color(0xFFF2F2F0),
    revealedDark: Color(0xFFE6E6E3),
    mineBg: Color(0xFF424242),
    mineBgCorrect: Color(0xFF757575),
    mineBgExploded: Color(0xFF1A1A1A),
    mineIconColor: Color(0xFFF5F5F5),
    numberColors: [
      Colors.transparent,
      Color(0xFF2E2E2E), // 1
      Color(0xFF454545), // 2
      Color(0xFF1A1A1A), // 3
      Color(0xFF5C5C5C), // 4
      Color(0xFF383838), // 5
      Color(0xFF6E6E6E), // 6
      Color(0xFF222222), // 7
      Color(0xFF505050), // 8
    ],
  ),

  // ─── TILE: rounded raised chips with a gap; board shows through; dot flag ──
  // Un-dug = vivid raised chip; dug-empty = clearly paler/different-hue flat
  // chip, so the two read very differently.
  BoardSkin(
    id: 'tile-blossom',
    name: 'Blossom Tiles',
    structure: CellStructure.tile,
    boardBackground: Color(0xFF2B2D42),
    cellRadiusFrac: 0.22,
    cellGapFrac: 0.08,
    tileRaiseFrac: 0.12,
    flagGlyph: FlagGlyph.dot,
    hiddenLight: Color(0xFF53C2A0),
    hiddenDark: Color(0xFF49B896),
    hiddenHover: Color(0xFF6FD3B6),
    hiddenEdge: Color(0xFF2B2D42),
    revealedLight: Color(0xFFF7CCDB),
    revealedDark: Color(0xFFF0BCCF),
    mineBg: Color(0xFFE05780),
    mineBgCorrect: Color(0xFF2E9E6B),
    mineBgExploded: Color(0xFF7A1F3D),
    mineIconColor: Color(0xFF2B1721),
    numberColors: [
      Colors.transparent,
      Color(0xFF2563C9),
      Color(0xFF2E8B57),
      Color(0xFFD23F5A),
      Color(0xFF8E44AD),
      Color(0xFFE07B00),
      Color(0xFF1F9AA6),
      Color(0xFF5A4A52),
      Color(0xFFC2185B),
    ],
  ),
  BoardSkin(
    id: 'tile-mint',
    name: 'Mint Tiles',
    structure: CellStructure.tile,
    boardBackground: Color(0xFF143A33),
    cellRadiusFrac: 0.22,
    cellGapFrac: 0.08,
    tileRaiseFrac: 0.12,
    flagGlyph: FlagGlyph.dot,
    hiddenLight: Color(0xFF2FAE86),
    hiddenDark: Color(0xFF28A37C),
    hiddenHover: Color(0xFF45C29B),
    hiddenEdge: Color(0xFF143A33),
    revealedLight: Color(0xFFEAF6EE),
    revealedDark: Color(0xFFDCEFE3),
    mineBg: Color(0xFFE0573E),
    mineBgCorrect: Color(0xFF2E9E6B),
    mineBgExploded: Color(0xFF6E2410),
    mineIconColor: Color(0xFF0E2A24),
    numberColors: [
      Colors.transparent,
      Color(0xFF0D6E9C),
      Color(0xFF1B7A3D),
      Color(0xFFC0392B),
      Color(0xFF6A3DB0),
      Color(0xFFD17B00),
      Color(0xFF00897B),
      Color(0xFF37474F),
      Color(0xFFAD1457),
    ],
  ),
  BoardSkin(
    id: 'tile-slate',
    name: 'Slate Tiles',
    structure: CellStructure.tile,
    boardBackground: Color(0xFF101216),
    cellRadiusFrac: 0.22,
    cellGapFrac: 0.08,
    tileRaiseFrac: 0.12,
    flagGlyph: FlagGlyph.dot,
    hiddenLight: Color(0xFF3C4452),
    hiddenDark: Color(0xFF353C49),
    hiddenHover: Color(0xFF4C566A),
    hiddenEdge: Color(0xFF101216),
    revealedLight: Color(0xFFAEB7C6),
    revealedDark: Color(0xFFA1ABBC),
    mineBg: Color(0xFFD7567A),
    mineBgCorrect: Color(0xFF3DA46B),
    mineBgExploded: Color(0xFF6E1430),
    mineIconColor: Color(0xFF11151B),
    numberColors: [
      Colors.transparent,
      Color(0xFF1A4A7A),
      Color(0xFF1B6E3D),
      Color(0xFFB23030),
      Color(0xFF5C3A8A),
      Color(0xFF9A5A10),
      Color(0xFF146E6E),
      Color(0xFF2A323C),
      Color(0xFF8A2050),
    ],
  ),
  BoardSkin(
    id: 'tile-sunset',
    name: 'Sunset Tiles',
    structure: CellStructure.tile,
    boardBackground: Color(0xFF3A2233),
    cellRadiusFrac: 0.22,
    cellGapFrac: 0.08,
    tileRaiseFrac: 0.12,
    flagGlyph: FlagGlyph.dot,
    hiddenLight: Color(0xFFEE8348),
    hiddenDark: Color(0xFFE87A3E),
    hiddenHover: Color(0xFFF59C66),
    hiddenEdge: Color(0xFF3A2233),
    revealedLight: Color(0xFFFCEBDB),
    revealedDark: Color(0xFFF7DEC8),
    mineBg: Color(0xFFD7402F),
    mineBgCorrect: Color(0xFF5DA271),
    mineBgExploded: Color(0xFF6E1A10),
    mineIconColor: Color(0xFF3A1808),
    numberColors: [
      Colors.transparent,
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFFC0392B),
      Color(0xFF7B1FA2),
      Color(0xFFCF6500),
      Color(0xFF00796B),
      Color(0xFF4E342E),
      Color(0xFFAD1457),
    ],
  ),
  BoardSkin(
    id: 'tile-ocean',
    name: 'Ocean Tiles',
    structure: CellStructure.tile,
    boardBackground: Color(0xFF0E2A3A),
    cellRadiusFrac: 0.22,
    cellGapFrac: 0.08,
    tileRaiseFrac: 0.12,
    flagGlyph: FlagGlyph.dot,
    hiddenLight: Color(0xFF2E9CD4),
    hiddenDark: Color(0xFF2792CA),
    hiddenHover: Color(0xFF52B4E4),
    hiddenEdge: Color(0xFF0E2A3A),
    revealedLight: Color(0xFFF1E6CB),
    revealedDark: Color(0xFFE7D9B8),
    mineBg: Color(0xFFE0573E),
    mineBgCorrect: Color(0xFF2E9E6B),
    mineBgExploded: Color(0xFF6E1A10),
    mineIconColor: Color(0xFF0B2530),
    numberColors: [
      Colors.transparent,
      Color(0xFF0D47A1),
      Color(0xFF1B7A3D),
      Color(0xFFC62828),
      Color(0xFF6A3DB0),
      Color(0xFFE07B00),
      Color(0xFF00838F),
      Color(0xFF37474F),
      Color(0xFFAD1457),
    ],
  ),
  BoardSkin(
    id: 'tile-grape',
    name: 'Grape Tiles',
    structure: CellStructure.tile,
    boardBackground: Color(0xFF231733),
    cellRadiusFrac: 0.22,
    cellGapFrac: 0.08,
    tileRaiseFrac: 0.12,
    flagGlyph: FlagGlyph.dot,
    hiddenLight: Color(0xFF8E63CC),
    hiddenDark: Color(0xFF855AC4),
    hiddenHover: Color(0xFFA47FDB),
    hiddenEdge: Color(0xFF231733),
    revealedLight: Color(0xFFEEE7F7),
    revealedDark: Color(0xFFE2D8F0),
    mineBg: Color(0xFFD7567A),
    mineBgCorrect: Color(0xFF3DA46B),
    mineBgExploded: Color(0xFF6E1430),
    mineIconColor: Color(0xFF241636),
    numberColors: [
      Colors.transparent,
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFFC62828),
      Color(0xFF6A1B9A),
      Color(0xFFD17B00),
      Color(0xFF00838F),
      Color(0xFF4A4458),
      Color(0xFFAD1457),
    ],
  ),
  BoardSkin(
    id: 'tile-lemon',
    name: 'Lemon Tiles',
    structure: CellStructure.tile,
    boardBackground: Color(0xFF2E2A12),
    cellRadiusFrac: 0.22,
    cellGapFrac: 0.08,
    tileRaiseFrac: 0.12,
    flagGlyph: FlagGlyph.dot,
    hiddenLight: Color(0xFFE2C23E),
    hiddenDark: Color(0xFFD8B834),
    hiddenHover: Color(0xFFF0D45E),
    hiddenEdge: Color(0xFF2E2A12),
    revealedLight: Color(0xFFF7F1D6),
    revealedDark: Color(0xFFEFE7C2),
    mineBg: Color(0xFFD7402F),
    mineBgCorrect: Color(0xFF5DA271),
    mineBgExploded: Color(0xFF6E1A10),
    mineIconColor: Color(0xFF2E2A12),
    numberColors: [
      Colors.transparent,
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFFC0392B),
      Color(0xFF7B1FA2),
      Color(0xFFCF6500),
      Color(0xFF00796B),
      Color(0xFF5D4037),
      Color(0xFFAD1457),
    ],
  ),

  // ─── BEVEL: Windows-95 raised 3D hidden cells, flat sunken revealed ───────
  // Un-dug = raised mid-tone face; dug-empty = clearly LIGHTER sunken panel, so
  // cleared area reads as an opened, brighter region (not just a bevel cue).
  BoardSkin(
    id: 'bevel-classic95',
    name: 'Classic 95',
    structure: CellStructure.bevel,
    checkerboard: false,
    bevelWidthFrac: 0.075,
    raisedLight: Color(0xFFFFFFFF),
    raisedDark: Color(0xFF7B7B7B),
    cellBorderColor: Color(0xFF8C8C8C),
    cellBorderWidth: 1.0,
    flagGlyph: FlagGlyph.classicPole,
    mineGlyph: MineGlyph.spoked,
    hiddenLight: Color(0xFFB6B6B6),
    hiddenDark: Color(0xFFB6B6B6),
    hiddenHover: Color(0xFFC8C8C8),
    hiddenEdge: Color(0xFF7B7B7B),
    revealedLight: Color(0xFFE4E4E4),
    revealedDark: Color(0xFFE4E4E4),
    mineBg: Color(0xFFFF3030),
    mineBgCorrect: Color(0xFFB6B6B6),
    mineBgExploded: Color(0xFFFF3030),
    mineIconColor: Color(0xFF000000),
    numberColors: [
      Colors.transparent,
      Color(0xFF0000FF),
      Color(0xFF008000),
      Color(0xFFFF0000),
      Color(0xFF000080),
      Color(0xFF800000),
      Color(0xFF008080),
      Color(0xFF000000),
      Color(0xFF606060),
    ],
  ),
  BoardSkin(
    id: 'bevel-beige',
    name: 'Retro Beige',
    structure: CellStructure.bevel,
    checkerboard: false,
    bevelWidthFrac: 0.075,
    raisedLight: Color(0xFFFAF4E6),
    raisedDark: Color(0xFF8E8064),
    cellBorderColor: Color(0xFF9E906F),
    cellBorderWidth: 1.0,
    flagGlyph: FlagGlyph.classicPole,
    mineGlyph: MineGlyph.spoked,
    hiddenLight: Color(0xFFCBBC9C),
    hiddenDark: Color(0xFFCBBC9C),
    hiddenHover: Color(0xFFDACDB1),
    hiddenEdge: Color(0xFF8E8064),
    revealedLight: Color(0xFFF1E9D6),
    revealedDark: Color(0xFFF1E9D6),
    mineBg: Color(0xFFC8472B),
    mineBgCorrect: Color(0xFFCBBC9C),
    mineBgExploded: Color(0xFFC8472B),
    mineIconColor: Color(0xFF2E2114),
    numberColors: [
      Colors.transparent,
      Color(0xFF1F4E9C),
      Color(0xFF2E7D32),
      Color(0xFFB23A1E),
      Color(0xFF512E8A),
      Color(0xFF7A1010),
      Color(0xFF00695C),
      Color(0xFF3E2A12),
      Color(0xFF6D4C41),
    ],
  ),
  BoardSkin(
    id: 'bevel-steel',
    name: 'Steel',
    structure: CellStructure.bevel,
    checkerboard: false,
    bevelWidthFrac: 0.075,
    raisedLight: Color(0xFFE4ECF3),
    raisedDark: Color(0xFF54606C),
    cellBorderColor: Color(0xFF606C78),
    cellBorderWidth: 1.0,
    flagGlyph: FlagGlyph.classicPole,
    mineGlyph: MineGlyph.spoked,
    hiddenLight: Color(0xFF8B98A6),
    hiddenDark: Color(0xFF8B98A6),
    hiddenHover: Color(0xFFA3AFBB),
    hiddenEdge: Color(0xFF54606C),
    revealedLight: Color(0xFFCFD8E0),
    revealedDark: Color(0xFFCFD8E0),
    mineBg: Color(0xFFE04E4E),
    mineBgCorrect: Color(0xFF8B98A6),
    mineBgExploded: Color(0xFF7A1A1A),
    mineIconColor: Color(0xFF11181F),
    numberColors: [
      Colors.transparent,
      Color(0xFF0D3B66),
      Color(0xFF1B5E20),
      Color(0xFF8E1B1B),
      Color(0xFF3F2E73),
      Color(0xFF8A4B00),
      Color(0xFF00595B),
      Color(0xFF1A2129),
      Color(0xFF7A1340),
    ],
  ),
  BoardSkin(
    id: 'bevel-mint',
    name: 'Mint 95',
    structure: CellStructure.bevel,
    checkerboard: false,
    bevelWidthFrac: 0.075,
    raisedLight: Color(0xFFEAF5EF),
    raisedDark: Color(0xFF6E8C7B),
    cellBorderColor: Color(0xFF7C9A89),
    cellBorderWidth: 1.0,
    flagGlyph: FlagGlyph.classicPole,
    mineGlyph: MineGlyph.spoked,
    hiddenLight: Color(0xFF9DC2AE),
    hiddenDark: Color(0xFF9DC2AE),
    hiddenHover: Color(0xFFB4D2C1),
    hiddenEdge: Color(0xFF6E8C7B),
    revealedLight: Color(0xFFDCEDE2),
    revealedDark: Color(0xFFDCEDE2),
    mineBg: Color(0xFFE0573E),
    mineBgCorrect: Color(0xFF9DC2AE),
    mineBgExploded: Color(0xFF6E2410),
    mineIconColor: Color(0xFF13241B),
    numberColors: [
      Colors.transparent,
      Color(0xFF0D5C9C),
      Color(0xFF1B6E2E),
      Color(0xFFB23030),
      Color(0xFF5C2E8A),
      Color(0xFF8A4B00),
      Color(0xFF006E66),
      Color(0xFF2A3A30),
      Color(0xFF8A2050),
    ],
  ),
  BoardSkin(
    id: 'bevel-rose',
    name: 'Rose 95',
    structure: CellStructure.bevel,
    checkerboard: false,
    bevelWidthFrac: 0.075,
    raisedLight: Color(0xFFF6EAEE),
    raisedDark: Color(0xFF8C6E76),
    cellBorderColor: Color(0xFF9E7C85),
    cellBorderWidth: 1.0,
    flagGlyph: FlagGlyph.classicPole,
    mineGlyph: MineGlyph.spoked,
    hiddenLight: Color(0xFFC6A6AE),
    hiddenDark: Color(0xFFC6A6AE),
    hiddenHover: Color(0xFFD7BDC4),
    hiddenEdge: Color(0xFF8C6E76),
    revealedLight: Color(0xFFEFE0E4),
    revealedDark: Color(0xFFEFE0E4),
    mineBg: Color(0xFFD81B60),
    mineBgCorrect: Color(0xFFC6A6AE),
    mineBgExploded: Color(0xFF7A1038),
    mineIconColor: Color(0xFF351820),
    numberColors: [
      Colors.transparent,
      Color(0xFF3949AB),
      Color(0xFF2E7D32),
      Color(0xFFC2185B),
      Color(0xFF6A1B9A),
      Color(0xFFB23A1E),
      Color(0xFF00695C),
      Color(0xFF4A2E36),
      Color(0xFFAD1457),
    ],
  ),

  // ─── FLAT: uniform cells with a thin hairline grid; minimal ───────────────
  // Un-dug = mid-tone cell; dug-empty = clearly lighter (light skins) or darker
  // (dark skins) — a big brightness jump so cleared cells stand out.
  BoardSkin(
    id: 'flat-blueprint',
    name: 'Blueprint',
    structure: CellStructure.flat,
    checkerboard: false,
    cellBorderColor: Color(0xFF8AA6BF),
    cellBorderWidth: 1.0,
    hiddenLight: Color(0xFFA9C2D8),
    hiddenDark: Color(0xFFA9C2D8),
    hiddenHover: Color(0xFFBDD2E3),
    hiddenEdge: Color(0xFF8AA6BF),
    revealedLight: Color(0xFFEDF3F8),
    revealedDark: Color(0xFFEDF3F8),
    mineBg: Color(0xFFE0573E),
    mineBgCorrect: Color(0xFF4CAF7D),
    mineBgExploded: Color(0xFF7A2418),
    mineIconColor: Color(0xFF1B2A38),
    numberColors: [
      Colors.transparent,
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFFD23F3F),
      Color(0xFF7B3FB0),
      Color(0xFFE07B00),
      Color(0xFF00838F),
      Color(0xFF455A64),
      Color(0xFFC2185B),
    ],
  ),
  BoardSkin(
    id: 'flat-paper',
    name: 'Paper White',
    structure: CellStructure.flat,
    checkerboard: false,
    cellBorderColor: Color(0xFFC2BBA8),
    cellBorderWidth: 1.0,
    hiddenLight: Color(0xFFD9D2C2),
    hiddenDark: Color(0xFFD9D2C2),
    hiddenHover: Color(0xFFE6E0D2),
    hiddenEdge: Color(0xFFC2BBA8),
    revealedLight: Color(0xFFFBFAF5),
    revealedDark: Color(0xFFFBFAF5),
    mineBg: Color(0xFFD7402F),
    mineBgCorrect: Color(0xFF4CAF7D),
    mineBgExploded: Color(0xFF7A2418),
    mineIconColor: Color(0xFF3A352B),
    numberColors: [
      Colors.transparent,
      Color(0xFF1976D2),
      Color(0xFF388E3C),
      Color(0xFFD32F2F),
      Color(0xFF7B1FA2),
      Color(0xFFEF6C00),
      Color(0xFF0097A7),
      Color(0xFF555555),
      Color(0xFFC2185B),
    ],
  ),
  BoardSkin(
    id: 'flat-graphite',
    name: 'Graphite',
    structure: CellStructure.flat,
    checkerboard: false,
    cellBorderColor: Color(0xFF4A515B),
    cellBorderWidth: 1.0,
    hiddenLight: Color(0xFF3A4049),
    hiddenDark: Color(0xFF3A4049),
    hiddenHover: Color(0xFF49505B),
    hiddenEdge: Color(0xFF4A515B),
    revealedLight: Color(0xFF15181D),
    revealedDark: Color(0xFF15181D),
    mineBg: Color(0xFFE2466B),
    mineBgCorrect: Color(0xFF3DA46B),
    mineBgExploded: Color(0xFF7A1030),
    mineIconColor: Color(0xFFEFF2FA),
    numberColors: [
      Colors.transparent,
      Color(0xFF64B5F6),
      Color(0xFF81C784),
      Color(0xFFE57373),
      Color(0xFFBA8FE0),
      Color(0xFFFFB74D),
      Color(0xFF4DD0E1),
      Color(0xFFB0BEC5),
      Color(0xFFF06292),
    ],
  ),
  BoardSkin(
    id: 'flat-sky',
    name: 'Sky',
    structure: CellStructure.flat,
    checkerboard: false,
    cellBorderColor: Color(0xFF7FB0D8),
    cellBorderWidth: 1.0,
    hiddenLight: Color(0xFF9CC6EA),
    hiddenDark: Color(0xFF9CC6EA),
    hiddenHover: Color(0xFFB3D5F1),
    hiddenEdge: Color(0xFF7FB0D8),
    revealedLight: Color(0xFFEAF4FC),
    revealedDark: Color(0xFFEAF4FC),
    mineBg: Color(0xFFE0573E),
    mineBgCorrect: Color(0xFF4CAF7D),
    mineBgExploded: Color(0xFF7A2418),
    mineIconColor: Color(0xFF15384F),
    numberColors: [
      Colors.transparent,
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
      Color(0xFFD23F3F),
      Color(0xFF7B3FB0),
      Color(0xFFE07B00),
      Color(0xFF00838F),
      Color(0xFF37566B),
      Color(0xFFC2185B),
    ],
  ),
  BoardSkin(
    id: 'flat-mint',
    name: 'Mint Flat',
    structure: CellStructure.flat,
    checkerboard: false,
    cellBorderColor: Color(0xFF7BBBA2),
    cellBorderWidth: 1.0,
    hiddenLight: Color(0xFF9AD2BC),
    hiddenDark: Color(0xFF9AD2BC),
    hiddenHover: Color(0xFFB2E0CE),
    hiddenEdge: Color(0xFF7BBBA2),
    revealedLight: Color(0xFFE7F6EF),
    revealedDark: Color(0xFFE7F6EF),
    mineBg: Color(0xFFE0573E),
    mineBgCorrect: Color(0xFF2E9E6B),
    mineBgExploded: Color(0xFF6E2410),
    mineIconColor: Color(0xFF12342A),
    numberColors: [
      Colors.transparent,
      Color(0xFF0D6E9C),
      Color(0xFF1B7A3D),
      Color(0xFFC0392B),
      Color(0xFF6A3DB0),
      Color(0xFFD17B00),
      Color(0xFF00897B),
      Color(0xFF37474F),
      Color(0xFFAD1457),
    ],
  ),
  BoardSkin(
    id: 'flat-rose',
    name: 'Rose Flat',
    structure: CellStructure.flat,
    checkerboard: false,
    cellBorderColor: Color(0xFFD198AB),
    cellBorderWidth: 1.0,
    hiddenLight: Color(0xFFE6B4C4),
    hiddenDark: Color(0xFFE6B4C4),
    hiddenHover: Color(0xFFF0C8D4),
    hiddenEdge: Color(0xFFD198AB),
    revealedLight: Color(0xFFFBEDF1),
    revealedDark: Color(0xFFFBEDF1),
    mineBg: Color(0xFFD81B60),
    mineBgCorrect: Color(0xFF5DA271),
    mineBgExploded: Color(0xFF7A1038),
    mineIconColor: Color(0xFF4A1B30),
    numberColors: [
      Colors.transparent,
      Color(0xFF3949AB),
      Color(0xFF2E7D32),
      Color(0xFFD83A56),
      Color(0xFF8E44AD),
      Color(0xFFEF6C00),
      Color(0xFF00897B),
      Color(0xFF6D4C5A),
      Color(0xFFC2185B),
    ],
  ),

  // ─── NEON: dark cells, glowing borders + luminous numbers ─────────────────
  // Un-dug = visibly lit, glowing cell; dug-empty = near-black void with just a
  // crisp neon outline — so cleared cells go "dark/quiet" vs glowing un-dug.
  BoardSkin(
    id: 'neon-cyan',
    name: 'Cyber Cyan',
    structure: CellStructure.neon,
    checkerboard: false,
    boardBackground: Color(0xFF04070A),
    cellGapFrac: 0.05,
    cellRadiusFrac: 0.12,
    cellBorderColor: Color(0xFF00E5FF),
    cellBorderWidth: 1.4,
    glowColor: Color(0x6600E5FF),
    glowBlurFrac: 0.18,
    flagGlyph: FlagGlyph.dot,
    mineGlyph: MineGlyph.spoked,
    hiddenLight: Color(0xFF12384F),
    hiddenDark: Color(0xFF12384F),
    hiddenHover: Color(0xFF1A4C68),
    hiddenEdge: Color(0xFF00E5FF),
    revealedLight: Color(0xFF05080C),
    revealedDark: Color(0xFF05080C),
    mineBg: Color(0xFFFF1744),
    mineBgCorrect: Color(0xFF00E676),
    mineBgExploded: Color(0xFF880E4F),
    mineIconColor: Color(0xFFE0F7FF),
    numberColors: [
      Colors.transparent,
      Color(0xFF00E5FF),
      Color(0xFF00FF9C),
      Color(0xFFFF3D7F),
      Color(0xFFB388FF),
      Color(0xFFFFD740),
      Color(0xFF18FFFF),
      Color(0xFFFF6E40),
      Color(0xFFFF4081),
    ],
  ),
  BoardSkin(
    id: 'neon-synthwave',
    name: 'Synthwave',
    structure: CellStructure.neon,
    checkerboard: false,
    boardBackground: Color(0xFF09040F),
    cellGapFrac: 0.05,
    cellRadiusFrac: 0.12,
    cellBorderColor: Color(0xFFFF2EC4),
    cellBorderWidth: 1.4,
    glowColor: Color(0x66FF2EC4),
    glowBlurFrac: 0.18,
    flagGlyph: FlagGlyph.dot,
    mineGlyph: MineGlyph.spoked,
    hiddenLight: Color(0xFF2C1449),
    hiddenDark: Color(0xFF2C1449),
    hiddenHover: Color(0xFF3C1C60),
    hiddenEdge: Color(0xFFFF2EC4),
    revealedLight: Color(0xFF0A0512),
    revealedDark: Color(0xFF0A0512),
    mineBg: Color(0xFFFF3D7F),
    mineBgCorrect: Color(0xFF00E676),
    mineBgExploded: Color(0xFF7A1048),
    mineIconColor: Color(0xFFFFE0F5),
    numberColors: [
      Colors.transparent,
      Color(0xFF4DD0FF),
      Color(0xFF6EFFC4),
      Color(0xFFFF5C8A),
      Color(0xFFC77DFF),
      Color(0xFFFFD24D),
      Color(0xFF59F0FF),
      Color(0xFFFF8A5C),
      Color(0xFFFF61C7),
    ],
  ),
  BoardSkin(
    id: 'neon-acid',
    name: 'Acid',
    structure: CellStructure.neon,
    checkerboard: false,
    boardBackground: Color(0xFF040804),
    cellGapFrac: 0.05,
    cellRadiusFrac: 0.12,
    cellBorderColor: Color(0xFF7CFF3D),
    cellBorderWidth: 1.4,
    glowColor: Color(0x667CFF3D),
    glowBlurFrac: 0.18,
    flagGlyph: FlagGlyph.dot,
    mineGlyph: MineGlyph.spoked,
    hiddenLight: Color(0xFF173E1B),
    hiddenDark: Color(0xFF173E1B),
    hiddenHover: Color(0xFF205227),
    hiddenEdge: Color(0xFF7CFF3D),
    revealedLight: Color(0xFF050A05),
    revealedDark: Color(0xFF050A05),
    mineBg: Color(0xFFFF4D4D),
    mineBgCorrect: Color(0xFF00E676),
    mineBgExploded: Color(0xFF6E1A10),
    mineIconColor: Color(0xFFEFFFE0),
    numberColors: [
      Colors.transparent,
      Color(0xFF5CE1FF),
      Color(0xFF7CFF3D),
      Color(0xFFFF6B6B),
      Color(0xFFB388FF),
      Color(0xFFFFE14D),
      Color(0xFF4DFFD2),
      Color(0xFFFFB85C),
      Color(0xFFFF77C2),
    ],
  ),
  BoardSkin(
    id: 'neon-inferno',
    name: 'Inferno',
    structure: CellStructure.neon,
    checkerboard: false,
    boardBackground: Color(0xFF0A0502),
    cellGapFrac: 0.05,
    cellRadiusFrac: 0.12,
    cellBorderColor: Color(0xFFFF7A18),
    cellBorderWidth: 1.4,
    glowColor: Color(0x66FF7A18),
    glowBlurFrac: 0.18,
    flagGlyph: FlagGlyph.dot,
    mineGlyph: MineGlyph.spoked,
    hiddenLight: Color(0xFF45200B),
    hiddenDark: Color(0xFF45200B),
    hiddenHover: Color(0xFF5C2C12),
    hiddenEdge: Color(0xFFFF7A18),
    revealedLight: Color(0xFF0A0502),
    revealedDark: Color(0xFF0A0502),
    mineBg: Color(0xFFFF3D20),
    mineBgCorrect: Color(0xFF00E676),
    mineBgExploded: Color(0xFF7A1010),
    mineIconColor: Color(0xFFFFE6CC),
    numberColors: [
      Colors.transparent,
      Color(0xFFFFC24D),
      Color(0xFF7CFF8A),
      Color(0xFFFF6B5C),
      Color(0xFFFFA24D),
      Color(0xFFFFE14D),
      Color(0xFF5CE1FF),
      Color(0xFFFF8A5C),
      Color(0xFFFF61A0),
    ],
  ),
  BoardSkin(
    id: 'neon-ice',
    name: 'Ice',
    structure: CellStructure.neon,
    checkerboard: false,
    boardBackground: Color(0xFF050810),
    cellGapFrac: 0.05,
    cellRadiusFrac: 0.12,
    cellBorderColor: Color(0xFFAEE9FF),
    cellBorderWidth: 1.4,
    glowColor: Color(0x66AEE9FF),
    glowBlurFrac: 0.18,
    flagGlyph: FlagGlyph.dot,
    mineGlyph: MineGlyph.spoked,
    hiddenLight: Color(0xFF1B3550),
    hiddenDark: Color(0xFF1B3550),
    hiddenHover: Color(0xFF254668),
    hiddenEdge: Color(0xFFAEE9FF),
    revealedLight: Color(0xFF05080C),
    revealedDark: Color(0xFF05080C),
    mineBg: Color(0xFFFF4D6D),
    mineBgCorrect: Color(0xFF00E6B8),
    mineBgExploded: Color(0xFF7A1030),
    mineIconColor: Color(0xFFEAF8FF),
    numberColors: [
      Colors.transparent,
      Color(0xFF8AD8FF),
      Color(0xFF7CFFD2),
      Color(0xFFFF7A9C),
      Color(0xFFC7B8FF),
      Color(0xFFFFE99C),
      Color(0xFFAEF0FF),
      Color(0xFFFFB88C),
      Color(0xFFFF9ECF),
    ],
  ),

  // ─── NEUMORPHIC: soft monochrome extruded cells (dual drop shadows) ───────
  // Un-dug = raised surface; dug-empty = clearly DARKER recessed cell, so dug
  // areas read as pressed-in panels.
  BoardSkin(
    id: 'neu-light',
    name: 'Soft Light',
    structure: CellStructure.neumorphic,
    checkerboard: false,
    boardBackground: Color(0xFFE6E7EE),
    cellRadiusFrac: 0.28,
    cellGapFrac: 0.06,
    flagGlyph: FlagGlyph.dot,
    raisedLight: Color(0xFFFFFFFF),
    raisedDark: Color(0xFFBCBDC7),
    hiddenLight: Color(0xFFE6E7EE),
    hiddenDark: Color(0xFFE6E7EE),
    hiddenHover: Color(0xFFEFF0F6),
    hiddenEdge: Color(0xFFBCBDC7),
    revealedLight: Color(0xFFC8C9D6),
    revealedDark: Color(0xFFC8C9D6),
    mineBg: Color(0xFFE06A86),
    mineBgCorrect: Color(0xFF6DBF93),
    mineBgExploded: Color(0xFF9A3350),
    mineIconColor: Color(0xFF4A4A55),
    numberColors: [
      Colors.transparent,
      Color(0xFF3A6BB0),
      Color(0xFF3E9163),
      Color(0xFFC24E4E),
      Color(0xFF7E5FB0),
      Color(0xFFC07A3A),
      Color(0xFF3A9090),
      Color(0xFF5B6270),
      Color(0xFFA84C76),
    ],
  ),
  BoardSkin(
    id: 'neu-dark',
    name: 'Soft Dark',
    structure: CellStructure.neumorphic,
    checkerboard: false,
    boardBackground: Color(0xFF2D313A),
    cellRadiusFrac: 0.28,
    cellGapFrac: 0.06,
    flagGlyph: FlagGlyph.dot,
    raisedLight: Color(0xFF3D424C),
    raisedDark: Color(0xFF131519),
    hiddenLight: Color(0xFF2D313A),
    hiddenDark: Color(0xFF2D313A),
    hiddenHover: Color(0xFF373C46),
    hiddenEdge: Color(0xFF131519),
    revealedLight: Color(0xFF1B1E24),
    revealedDark: Color(0xFF1B1E24),
    mineBg: Color(0xFFE2466B),
    mineBgCorrect: Color(0xFF3DA46B),
    mineBgExploded: Color(0xFF7A1030),
    mineIconColor: Color(0xFFEFF2FA),
    numberColors: [
      Colors.transparent,
      Color(0xFF7FB6F0),
      Color(0xFF8FCF9A),
      Color(0xFFEF8585),
      Color(0xFFC2A0E6),
      Color(0xFFF0C46E),
      Color(0xFF6FD9D9),
      Color(0xFFAEB6C2),
      Color(0xFFEF8FB6),
    ],
  ),
  BoardSkin(
    id: 'neu-blue',
    name: 'Soft Blue',
    structure: CellStructure.neumorphic,
    checkerboard: false,
    boardBackground: Color(0xFFDCE4F0),
    cellRadiusFrac: 0.28,
    cellGapFrac: 0.06,
    flagGlyph: FlagGlyph.dot,
    raisedLight: Color(0xFFF2F6FC),
    raisedDark: Color(0xFFB2BDD0),
    hiddenLight: Color(0xFFDCE4F0),
    hiddenDark: Color(0xFFDCE4F0),
    hiddenHover: Color(0xFFE7EDF7),
    hiddenEdge: Color(0xFFB2BDD0),
    revealedLight: Color(0xFFBECCDF),
    revealedDark: Color(0xFFBECCDF),
    mineBg: Color(0xFFE06A86),
    mineBgCorrect: Color(0xFF6DBF93),
    mineBgExploded: Color(0xFF9A3350),
    mineIconColor: Color(0xFF3C4654),
    numberColors: [
      Colors.transparent,
      Color(0xFF2C5FA8),
      Color(0xFF3E9163),
      Color(0xFFC24E4E),
      Color(0xFF7250A8),
      Color(0xFFC07A3A),
      Color(0xFF2F8A8A),
      Color(0xFF4C5564),
      Color(0xFFA84C76),
    ],
  ),
  BoardSkin(
    id: 'neu-mint',
    name: 'Soft Mint',
    structure: CellStructure.neumorphic,
    checkerboard: false,
    boardBackground: Color(0xFFDCEDE5),
    cellRadiusFrac: 0.28,
    cellGapFrac: 0.06,
    flagGlyph: FlagGlyph.dot,
    raisedLight: Color(0xFFF0F8F4),
    raisedDark: Color(0xFFB0CDC0),
    hiddenLight: Color(0xFFDCEDE5),
    hiddenDark: Color(0xFFDCEDE5),
    hiddenHover: Color(0xFFE8F4EE),
    hiddenEdge: Color(0xFFB0CDC0),
    revealedLight: Color(0xFFBEDBCF),
    revealedDark: Color(0xFFBEDBCF),
    mineBg: Color(0xFFE06A6A),
    mineBgCorrect: Color(0xFF4FB07A),
    mineBgExploded: Color(0xFF8A2A20),
    mineIconColor: Color(0xFF2E4A40),
    numberColors: [
      Colors.transparent,
      Color(0xFF2C7AA8),
      Color(0xFF2E8B57),
      Color(0xFFC24E4E),
      Color(0xFF7250A8),
      Color(0xFFC07A3A),
      Color(0xFF2F8A8A),
      Color(0xFF45564E),
      Color(0xFFA84C76),
    ],
  ),
];

/// Default skin applied on launch (the original board look).
final BoardSkin kDefaultBoardSkin = kBoardSkins.first;
