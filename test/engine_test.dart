import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeper/game/difficulty.dart';
import 'package:minesweeper/game/engine.dart';

void main() {
  group('GameEngine', () {
    test('first reveal places mines and starts the game', () {
      final e = GameEngine(
        const GameConfig(width: 5, height: 5, mines: 3),
        seed: 1,
      );
      expect(e.status, GameStatus.waiting);
      final out = e.reveal(2, 2, playerId: 'p1');
      expect(out.isEmpty, isFalse);
      expect(e.status, isNot(GameStatus.waiting));
      expect(e.board.minesPlaced, isTrue);
    });

    test('hitting a mine sets status to lost and credits losingPlayerId', () {
      final e = GameEngine(
        const GameConfig(width: 4, height: 4, mines: 5),
        seed: 9,
      );
      // First reveal: safe zone at (0,0).
      e.reveal(0, 0, playerId: 'p1');
      // Find a mine and reveal it.
      for (var y = 0; y < 4; y++) {
        for (var x = 0; x < 4; x++) {
          if (e.board.cellAt(x, y).isMine) {
            e.reveal(x, y, playerId: 'p2');
            expect(e.status, GameStatus.lost);
            expect(e.losingPlayerId, 'p2');
            return;
          }
        }
      }
    });

    test('flag stats increment and decrement', () {
      final e = GameEngine(
        const GameConfig(width: 8, height: 8, mines: 10),
        seed: 0,
      );
      e.reveal(0, 0, playerId: 'p1'); // place mines + start
      // Find any hidden non-mine cell to flag.
      int? fx, fy;
      for (var y = 0; y < 8 && fx == null; y++) {
        for (var x = 0; x < 8 && fx == null; x++) {
          final c = e.board.cellAt(x, y);
          if (c.isHidden && !c.isMine) {
            fx = x;
            fy = y;
          }
        }
      }
      expect(fx, isNotNull);
      final r1 = e.flag(fx!, fy!, playerId: 'p1');
      expect(r1!.flagged, isTrue);
      expect(e.stats['p1']!.flagsPlaced, 1);
      final r2 = e.flag(fx, fy, playerId: 'p1');
      expect(r2!.flagged, isFalse);
      expect(e.stats['p1']!.flagsPlaced, 0);
    });

    test('reveal after game over is a no-op', () {
      final e = GameEngine(
        const GameConfig(width: 3, height: 3, mines: 1),
        seed: 0,
      );
      // Win the game: reveal everything that isn't a mine.
      e.reveal(0, 0, playerId: 'p1');
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 3; x++) {
          if (!e.board.cellAt(x, y).isMine) {
            e.reveal(x, y, playerId: 'p1');
          }
        }
      }
      expect(e.status, GameStatus.won);
      final out = e.reveal(0, 0, playerId: 'p1');
      expect(out.isEmpty, isTrue);
    });
  });
}
