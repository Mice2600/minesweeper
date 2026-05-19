import 'dart:math';

import 'board.dart';
import 'difficulty.dart';

enum GameStatus { waiting, playing, won, lost }

/// Authoritative game engine. The host owns one of these; guests mirror via
/// applied events. Pure Dart, no I/O.
class GameEngine {
  GameEngine(this.config, {int? seed})
      : _board = Board(config),
        seed = seed ?? Random().nextInt(0x7fffffff),
        _hearts = config.initialHearts;

  final GameConfig config;
  final int seed;
  final Board _board;

  GameStatus _status = GameStatus.waiting;
  DateTime? _startedAt;
  DateTime? _endedAt;
  String? _losingPlayerId;
  int _hearts;

  final Map<String, PlayerStats> _stats = {};

  Board get board => _board;
  GameStatus get status => _status;
  DateTime? get startedAt => _startedAt;
  DateTime? get endedAt => _endedAt;
  String? get losingPlayerId => _losingPlayerId;
  int get hearts => _hearts;
  int get initialHearts => config.initialHearts;
  Map<String, PlayerStats> get stats => Map.unmodifiable(_stats);

  PlayerStats _statsFor(String id) =>
      _stats.putIfAbsent(id, () => PlayerStats());

  RevealOutcome reveal(int x, int y, {required String playerId}) {
    if (_status == GameStatus.won || _status == GameStatus.lost) {
      return RevealOutcome.empty;
    }
    if (!_board.minesPlaced) {
      _board.placeMines(seed: seed, safeX: x, safeY: y);
      _status = GameStatus.playing;
      _startedAt = DateTime.now();
    }
    final cells = _board.reveal(x, y, playerId: playerId);
    if (cells.isEmpty) return RevealOutcome.empty;

    return _processReveal(cells, x, y, playerId);
  }

  FlagOutcome? flag(int x, int y, {required String playerId}) {
    if (_status == GameStatus.won || _status == GameStatus.lost) return null;
    final flagged = _board.toggleFlag(x, y, playerId: playerId);
    if (flagged == null) return null;
    final stats = _statsFor(playerId);
    if (flagged) {
      stats.flagsPlaced++;
    } else {
      stats.flagsPlaced = (stats.flagsPlaced - 1).clamp(0, 1 << 30);
    }
    return FlagOutcome(
      x: x,
      y: y,
      flagged: flagged,
      byPlayerId: playerId,
    );
  }

  RevealOutcome chord(int x, int y, {required String playerId}) {
    if (_status != GameStatus.playing) return RevealOutcome.empty;
    final cells = _board.chord(x, y, playerId: playerId);
    if (cells.isEmpty) return RevealOutcome.empty;
    return _processReveal(cells, x, y, playerId);
  }

  /// Shared post-processing for `reveal` and `chord`: counts stats, handles
  /// mine hits (with Hearts-mode chain explosions), and updates win/lose
  /// status.
  RevealOutcome _processReveal(
    List<Reveal> initialCells,
    int triggerX,
    int triggerY,
    String playerId,
  ) {
    final stats = _statsFor(playerId);
    final allCells = List<Reveal>.from(initialCells);
    final explosionCenters = <List<int>>[];
    var mineHit = false;

    for (final r in initialCells) {
      if (r.isMine) {
        mineHit = true;
      } else {
        stats.cellsRevealed++;
      }
    }

    if (mineHit) {
      if (config.mode == GameMode.hearts && _hearts > 0) {
        _hearts--;
        // Chain off the trigger cell (or each mine cell that just revealed).
        for (final r in initialCells.where((c) => c.isMine)) {
          final chain = _board.chainExplode(r.x, r.y, playerId: playerId);
          for (final c in chain.reveals) {
            allCells.add(c);
            if (!c.isMine) stats.cellsRevealed++;
          }
          explosionCenters.addAll(chain.centers);
        }
        // If every mine has now detonated, the field is safe — auto-reveal
        // the rest so the team wins cleanly without having to unflag.
        if (_board.allMinesRevealed()) {
          final remaining =
              _board.revealAllHiddenNonMines(playerId: playerId);
          for (final c in remaining) {
            allCells.add(c);
            stats.cellsRevealed++;
          }
        }
        if (_hearts <= 0) {
          _status = GameStatus.lost;
          _endedAt = DateTime.now();
          _losingPlayerId = playerId;
        } else if (_board.isWon()) {
          _status = GameStatus.won;
          _endedAt = DateTime.now();
        }
      } else {
        _status = GameStatus.lost;
        _endedAt = DateTime.now();
        _losingPlayerId = playerId;
      }
    } else if (_board.isWon()) {
      _status = GameStatus.won;
      _endedAt = DateTime.now();
    }

    return RevealOutcome(
      cells: allCells,
      byPlayerId: playerId,
      heartLost: mineHit && config.mode == GameMode.hearts,
      heartsRemaining: _hearts,
      explosionCenters: explosionCenters,
      triggerX: triggerX,
      triggerY: triggerY,
    );
  }

  int flagsRemaining() {
    var placed = 0;
    for (var y = 0; y < _board.height; y++) {
      for (var x = 0; x < _board.width; x++) {
        if (_board.cellAt(x, y).isFlagged) placed++;
      }
    }
    return _board.mineCount - placed;
  }
}

class PlayerStats {
  PlayerStats({this.cellsRevealed = 0, this.flagsPlaced = 0});
  int cellsRevealed;
  int flagsPlaced;

  Map<String, dynamic> toJson() => {
        'cellsRevealed': cellsRevealed,
        'flagsPlaced': flagsPlaced,
      };

  factory PlayerStats.fromJson(Map<String, dynamic> json) => PlayerStats(
        cellsRevealed: json['cellsRevealed'] as int? ?? 0,
        flagsPlaced: json['flagsPlaced'] as int? ?? 0,
      );
}

class RevealOutcome {
  const RevealOutcome({
    required this.cells,
    required this.byPlayerId,
    this.heartLost = false,
    this.heartsRemaining = 0,
    this.explosionCenters = const [],
    this.triggerX = 0,
    this.triggerY = 0,
  });
  static const empty = RevealOutcome(cells: [], byPlayerId: '');
  final List<Reveal> cells;
  final String byPlayerId;
  final bool heartLost;
  final int heartsRemaining;
  final List<List<int>> explosionCenters;
  final int triggerX;
  final int triggerY;
  bool get isEmpty => cells.isEmpty;
}

class FlagOutcome {
  const FlagOutcome({
    required this.x,
    required this.y,
    required this.flagged,
    required this.byPlayerId,
  });
  final int x;
  final int y;
  final bool flagged;
  final String byPlayerId;
}
