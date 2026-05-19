import 'dart:math';

import 'difficulty.dart';

enum CellState { hidden, revealed, flagged }

class Cell {
  Cell({
    this.isMine = false,
    this.adjacentMines = 0,
    this.state = CellState.hidden,
    this.flaggedBy,
    this.revealedBy,
  });

  bool isMine;
  int adjacentMines;
  CellState state;
  String? flaggedBy;
  String? revealedBy;

  bool get isHidden => state == CellState.hidden;
  bool get isRevealed => state == CellState.revealed;
  bool get isFlagged => state == CellState.flagged;
}

class Board {
  Board(this.config)
      : _cells = List.generate(
          config.width * config.height,
          (_) => Cell(),
        );

  final GameConfig config;
  final List<Cell> _cells;
  bool _minesPlaced = false;
  int _revealedCount = 0;

  int get width => config.width;
  int get height => config.height;
  int get mineCount => config.mines;
  int get revealedCount => _revealedCount;
  bool get minesPlaced => _minesPlaced;

  Cell cellAt(int x, int y) => _cells[_index(x, y)];

  bool inBounds(int x, int y) =>
      x >= 0 && x < width && y >= 0 && y < height;

  int _index(int x, int y) => y * width + x;

  /// Place mines uniformly at random, excluding a 3x3 safe zone around
  /// (safeX, safeY). Deterministic for a given [seed].
  void placeMines({required int seed, required int safeX, required int safeY}) {
    assert(!_minesPlaced, 'mines already placed');
    final rng = Random(seed);
    final forbidden = <int>{};
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final nx = safeX + dx;
        final ny = safeY + dy;
        if (inBounds(nx, ny)) forbidden.add(_index(nx, ny));
      }
    }

    final candidates = <int>[];
    for (var i = 0; i < _cells.length; i++) {
      if (!forbidden.contains(i)) candidates.add(i);
    }
    candidates.shuffle(rng);
    final mines = candidates.take(mineCount);
    for (final i in mines) {
      _cells[i].isMine = true;
    }

    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (cellAt(x, y).isMine) continue;
        var count = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = x + dx;
            final ny = y + dy;
            if (inBounds(nx, ny) && cellAt(nx, ny).isMine) count++;
          }
        }
        cellAt(x, y).adjacentMines = count;
      }
    }
    _minesPlaced = true;
  }

  /// Reveal cell at (x,y). Returns list of newly revealed [Reveal]s.
  /// If a mine is revealed, the mine cell is included with [Reveal.isMine].
  List<Reveal> reveal(int x, int y, {required String playerId}) {
    if (!inBounds(x, y)) return const [];
    final root = cellAt(x, y);
    if (root.isRevealed || root.isFlagged) return const [];

    if (root.isMine) {
      root.state = CellState.revealed;
      root.revealedBy = playerId;
      // Note: mines do NOT count toward _revealedCount — that counter only
      // tracks non-mine reveals so that isWon() works in modes (like Hearts)
      // where mines may be revealed without ending the game.
      return [Reveal(x: x, y: y, value: -1, isMine: true)];
    }

    final out = <Reveal>[];
    final stack = <List<int>>[
      [x, y]
    ];
    while (stack.isNotEmpty) {
      final pos = stack.removeLast();
      final cx = pos[0];
      final cy = pos[1];
      final c = cellAt(cx, cy);
      if (c.isRevealed || c.isFlagged || c.isMine) continue;
      c.state = CellState.revealed;
      c.revealedBy = playerId;
      _revealedCount++;
      out.add(Reveal(x: cx, y: cy, value: c.adjacentMines));
      if (c.adjacentMines == 0) {
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            if (dx == 0 && dy == 0) continue;
            final nx = cx + dx;
            final ny = cy + dy;
            if (inBounds(nx, ny)) stack.add([nx, ny]);
          }
        }
      }
    }
    return out;
  }

  /// Toggle a flag on the cell. Returns null if the cell is already revealed.
  /// Returns true if the cell ended up flagged, false if unflagged.
  bool? toggleFlag(int x, int y, {required String playerId}) {
    if (!inBounds(x, y)) return null;
    final c = cellAt(x, y);
    if (c.isRevealed) return null;
    if (c.isFlagged) {
      c.state = CellState.hidden;
      c.flaggedBy = null;
      return false;
    }
    c.state = CellState.flagged;
    c.flaggedBy = playerId;
    return true;
  }

  /// Chord click: if cell is revealed with a number, and adjacent flags match
  /// that number, reveal all adjacent non-flagged hidden cells.
  List<Reveal> chord(int x, int y, {required String playerId}) {
    if (!inBounds(x, y)) return const [];
    final c = cellAt(x, y);
    if (!c.isRevealed || c.adjacentMines == 0) return const [];

    var flagCount = 0;
    final hiddenNeighbors = <List<int>>[];
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx;
        final ny = y + dy;
        if (!inBounds(nx, ny)) continue;
        final n = cellAt(nx, ny);
        if (n.isFlagged) {
          flagCount++;
        } else if (n.isHidden) {
          hiddenNeighbors.add([nx, ny]);
        }
      }
    }
    if (flagCount != c.adjacentMines) return const [];

    final out = <Reveal>[];
    for (final p in hiddenNeighbors) {
      out.addAll(reveal(p[0], p[1], playerId: playerId));
    }
    return out;
  }

  /// True when every non-mine cell has been revealed.
  bool isWon() {
    if (!_minesPlaced) return false;
    return _revealedCount >= cellCount - mineCount;
  }

  /// True when every mine on the board has been revealed (detonated).
  bool allMinesRevealed() {
    if (!_minesPlaced) return false;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final c = cellAt(x, y);
        if (c.isMine && !c.isRevealed) return false;
      }
    }
    return true;
  }

  /// Reveals every hidden non-mine cell (clearing any flags). Returns the
  /// list of Reveals so the network layer can broadcast them.
  List<Reveal> revealAllHiddenNonMines({required String playerId}) {
    final out = <Reveal>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final c = cellAt(x, y);
        if (c.isMine || c.isRevealed) continue;
        c.flaggedBy = null;
        c.state = CellState.revealed;
        c.revealedBy = playerId;
        _revealedCount++;
        out.add(Reveal(x: x, y: y, value: c.adjacentMines));
      }
    }
    return out;
  }

  /// Hard cap on how many mines a single chain can detonate. Keeps a single
  /// click from wiping out an arbitrarily large cluster.
  static const chainMaxMines = 10;

  /// Triggered when a mine at (startX, startY) detonates in Hearts mode.
  /// Reveals its 3x3 neighborhood; any neighboring mine chain-detonates
  /// recursively, up to [chainMaxMines]. Flags on chain-revealed cells are
  /// cleared.
  ChainExplosion chainExplode(int startX, int startY,
      {required String playerId}) {
    final reveals = <Reveal>[];
    final centers = <List<int>>[];
    final seen = <int>{};
    final queue = <List<int>>[
      [startX, startY]
    ];

    while (queue.isNotEmpty && centers.length < chainMaxMines) {
      final pos = queue.removeAt(0);
      final mx = pos[0];
      final my = pos[1];
      final mIdx = _index(mx, my);
      if (seen.contains(mIdx)) continue;
      seen.add(mIdx);

      final mineCell = cellAt(mx, my);
      if (!mineCell.isMine) continue;

      if (!mineCell.isRevealed) {
        mineCell.state = CellState.revealed;
        mineCell.revealedBy = playerId;
        mineCell.flaggedBy = null;
        reveals.add(Reveal(x: mx, y: my, value: -1, isMine: true));
      }
      centers.add([mx, my]);

      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = mx + dx;
          final ny = my + dy;
          if (!inBounds(nx, ny)) continue;
          final nIdx = _index(nx, ny);
          if (seen.contains(nIdx)) continue;
          final n = cellAt(nx, ny);
          if (n.isRevealed) continue;

          if (n.isMine) {
            queue.add([nx, ny]);
          } else {
            if (n.isFlagged) {
              n.state = CellState.hidden;
              n.flaggedBy = null;
            }
            final r = reveal(nx, ny, playerId: playerId);
            for (final rev in r) {
              seen.add(_index(rev.x, rev.y));
              reveals.add(rev);
            }
          }
        }
      }
    }
    return ChainExplosion(reveals: reveals, centers: centers);
  }

  int get cellCount => width * height;

  List<List<int>> minePositions() {
    final out = <List<int>>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (cellAt(x, y).isMine) out.add([x, y]);
      }
    }
    return out;
  }
}

class ChainExplosion {
  const ChainExplosion({required this.reveals, required this.centers});

  /// All cells revealed by the chain (mines AND adjacent non-mines).
  final List<Reveal> reveals;

  /// Positions of every mine that detonated, in detonation order.
  final List<List<int>> centers;

  bool get isEmpty => reveals.isEmpty;
}

class Reveal {
  const Reveal({
    required this.x,
    required this.y,
    required this.value,
    this.isMine = false,
  });

  final int x;
  final int y;

  /// 0..8 for non-mine cells, -1 for a mine reveal.
  final int value;
  final bool isMine;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'value': value,
        if (isMine) 'mine': true,
      };

  factory Reveal.fromJson(Map<String, dynamic> json) => Reveal(
        x: json['x'] as int,
        y: json['y'] as int,
        value: json['value'] as int,
        isMine: json['mine'] as bool? ?? false,
      );
}
