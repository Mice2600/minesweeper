import 'dart:math';

import 'board.dart';
import 'difficulty.dart';

enum GameStatus { waiting, playing, won, lost }

/// Authoritative game engine. The host owns one of these; guests mirror via
/// applied events. Pure Dart, no I/O.
class GameEngine {
  GameEngine(this.config, {int? seed})
      : _board = Board(config),
        seed = seed ?? Random().nextInt(0x7fffffff);

  final GameConfig config;
  final int seed;
  final Board _board;

  GameStatus _status = GameStatus.waiting;
  DateTime? _startedAt;
  DateTime? _endedAt;
  String? _losingPlayerId;

  final Map<String, PlayerStats> _stats = {};

  Board get board => _board;
  GameStatus get status => _status;
  DateTime? get startedAt => _startedAt;
  DateTime? get endedAt => _endedAt;
  String? get losingPlayerId => _losingPlayerId;
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

    final stats = _statsFor(playerId);
    var mineHit = false;
    for (final r in cells) {
      if (r.isMine) {
        mineHit = true;
      } else {
        stats.cellsRevealed++;
      }
    }
    if (mineHit) {
      _status = GameStatus.lost;
      _endedAt = DateTime.now();
      _losingPlayerId = playerId;
    } else if (_board.isWon()) {
      _status = GameStatus.won;
      _endedAt = DateTime.now();
    }
    return RevealOutcome(cells: cells, byPlayerId: playerId);
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
    final stats = _statsFor(playerId);
    var mineHit = false;
    for (final r in cells) {
      if (r.isMine) {
        mineHit = true;
      } else {
        stats.cellsRevealed++;
      }
    }
    if (mineHit) {
      _status = GameStatus.lost;
      _endedAt = DateTime.now();
      _losingPlayerId = playerId;
    } else if (_board.isWon()) {
      _status = GameStatus.won;
      _endedAt = DateTime.now();
    }
    return RevealOutcome(cells: cells, byPlayerId: playerId);
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
  const RevealOutcome({required this.cells, required this.byPlayerId});
  static const empty = RevealOutcome(cells: [], byPlayerId: '');
  final List<Reveal> cells;
  final String byPlayerId;
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
