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

    test('Hearts mode survives the first mine hit and decrements hearts', () {
      final e = GameEngine(
        const GameConfig(
          width: 14,
          height: 14,
          mines: 30,
          mode: GameMode.hearts,
          initialHearts: 3,
        ),
        seed: 7,
      );
      e.reveal(0, 0, playerId: 'p1');
      expect(e.hearts, 3);
      // Find a mine far enough from (0,0) to avoid the safe zone, and step
      // on it.
      for (var y = 0; y < 14; y++) {
        for (var x = 0; x < 14; x++) {
          if (e.board.cellAt(x, y).isMine) {
            final out = e.reveal(x, y, playerId: 'p1');
            expect(out.heartLost, isTrue);
            expect(out.heartsRemaining, 2);
            expect(e.hearts, 2);
            expect(e.status, GameStatus.playing);
            expect(e.board.cellAt(x, y).isRevealed, isTrue);
            return;
          }
        }
      }
      fail('no mines found');
    });

    test('Hearts mode: hitting all hearts ends the game', () {
      final e = GameEngine(
        const GameConfig(
          width: 6,
          height: 6,
          mines: 6,
          mode: GameMode.hearts,
          initialHearts: 1,
        ),
        seed: 3,
      );
      e.reveal(0, 0, playerId: 'p1');
      for (var y = 0; y < 6; y++) {
        for (var x = 0; x < 6; x++) {
          if (e.board.cellAt(x, y).isMine && !e.board.cellAt(x, y).isRevealed) {
            e.reveal(x, y, playerId: 'p1');
            if (e.status == GameStatus.lost) {
              expect(e.hearts, 0);
              return;
            }
          }
        }
      }
      fail('expected game to be lost after exhausting hearts');
    });

    test('Hearts chain: stepping on one of two adjacent mines detonates both',
        () {
      // 5x5 board with mines at (4,0) and (4,1) thanks to seed search; verify
      // dynamically.
      final e = GameEngine(
        const GameConfig(
          width: 5,
          height: 5,
          mines: 6,
          mode: GameMode.hearts,
          initialHearts: 3,
        ),
        seed: 11,
      );
      e.reveal(0, 0, playerId: 'p1');
      // Find two adjacent mines.
      List<int>? a;
      List<int>? b;
      outer:
      for (var y = 0; y < 5; y++) {
        for (var x = 0; x < 5; x++) {
          if (!e.board.cellAt(x, y).isMine) continue;
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final nx = x + dx;
              final ny = y + dy;
              if (nx < 0 || ny < 0 || nx >= 5 || ny >= 5) continue;
              if (e.board.cellAt(nx, ny).isMine) {
                a = [x, y];
                b = [nx, ny];
                break outer;
              }
            }
          }
        }
      }
      if (a == null || b == null) return; // seed has no adjacent mines; skip
      final preHearts = e.hearts;
      final out = e.reveal(a[0], a[1], playerId: 'p1');
      expect(out.heartLost, isTrue);
      expect(e.hearts, preHearts - 1);
      expect(e.board.cellAt(a[0], a[1]).isRevealed, isTrue);
      expect(e.board.cellAt(b[0], b[1]).isRevealed, isTrue,
          reason: 'adjacent mine should have chain-detonated');
    });

    test(
        'Hearts mode: detonating every mine auto-clears remaining cells and wins',
        () {
      // Small board so a few hits exhaust the mines.
      final e = GameEngine(
        const GameConfig(
          width: 6,
          height: 6,
          mines: 4,
          mode: GameMode.hearts,
          initialHearts: 5,
        ),
        seed: 21,
      );
      e.reveal(0, 0, playerId: 'p1');
      // Flag a hidden non-mine cell so it would otherwise block a win.
      for (var y = 0; y < 6; y++) {
        for (var x = 0; x < 6; x++) {
          final c = e.board.cellAt(x, y);
          if (!c.isMine && !c.isRevealed) {
            e.flag(x, y, playerId: 'p1');
            break;
          }
        }
        if (e.flagsRemaining() < 4) break;
      }
      // Step on every mine.
      for (var y = 0; y < 6; y++) {
        for (var x = 0; x < 6; x++) {
          if (e.board.cellAt(x, y).isMine && !e.board.cellAt(x, y).isRevealed) {
            e.reveal(x, y, playerId: 'p1');
          }
        }
      }
      expect(e.status, GameStatus.won,
          reason:
              'Once every mine is detonated the rest auto-clear and the game is won');
      // Every cell must end up revealed.
      for (var y = 0; y < 6; y++) {
        for (var x = 0; x < 6; x++) {
          expect(e.board.cellAt(x, y).isRevealed, isTrue);
        }
      }
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
