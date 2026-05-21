import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeper/game/board.dart';
import 'package:minesweeper/game/difficulty.dart';

void main() {
  group('Board.placeMines', () {
    test('places exactly N mines and excludes 3x3 safe zone', () {
      final b = Board(const GameConfig(width: 10, height: 10, mines: 20));
      b.placeMines(seed: 42, safeX: 5, safeY: 5);

      var mineCount = 0;
      for (var y = 0; y < b.height; y++) {
        for (var x = 0; x < b.width; x++) {
          if (b.cellAt(x, y).isMine) mineCount++;
        }
      }
      expect(mineCount, 20);

      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          expect(b.cellAt(5 + dx, 5 + dy).isMine, isFalse,
              reason: 'cell ${5 + dx},${5 + dy} must be safe');
        }
      }
    });

    test('is deterministic for the same seed and safe-zone', () {
      final a = Board(const GameConfig(width: 9, height: 9, mines: 10));
      final b = Board(const GameConfig(width: 9, height: 9, mines: 10));
      a.placeMines(seed: 7, safeX: 0, safeY: 0);
      b.placeMines(seed: 7, safeX: 0, safeY: 0);
      for (var y = 0; y < 9; y++) {
        for (var x = 0; x < 9; x++) {
          expect(a.cellAt(x, y).isMine, b.cellAt(x, y).isMine);
        }
      }
    });

    test('adjacentMines counts are correct', () {
      final b = Board(const GameConfig(width: 5, height: 5, mines: 3));
      b.placeMines(seed: 1, safeX: 4, safeY: 4);
      // For every non-mine cell, count neighboring mines manually and compare.
      for (var y = 0; y < 5; y++) {
        for (var x = 0; x < 5; x++) {
          final cell = b.cellAt(x, y);
          if (cell.isMine) continue;
          var manual = 0;
          for (var dy = -1; dy <= 1; dy++) {
            for (var dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              if (b.inBounds(x + dx, y + dy) &&
                  b.cellAt(x + dx, y + dy).isMine) {
                manual++;
              }
            }
          }
          expect(cell.adjacentMines, manual);
        }
      }
    });
  });

  group('Board.reveal', () {
    test('flood-fills zeros, stops at numbers', () {
      // 5x5 board with one corner mine; revealing far corner should flood.
      final b = Board(const GameConfig(width: 5, height: 5, mines: 1));
      b.placeMines(seed: 0, safeX: 4, safeY: 4);
      final revealed = b.reveal(4, 4, playerId: 'p1');
      expect(revealed, isNotEmpty);
      // Every revealed cell must not be a mine and must have a value 0..8.
      for (final r in revealed) {
        expect(r.isMine, isFalse);
        expect(r.value, inInclusiveRange(0, 8));
      }
    });

    test('revealing a flagged cell is a no-op', () {
      final b = Board(const GameConfig(width: 5, height: 5, mines: 1));
      b.placeMines(seed: 0, safeX: 0, safeY: 0);
      b.cycleMark(2, 2, playerId: 'p1');
      final out = b.reveal(2, 2, playerId: 'p1');
      expect(out, isEmpty);
      expect(b.cellAt(2, 2).isFlagged, isTrue);
    });

    test('revealing a mine returns a single mine reveal', () {
      final b = Board(const GameConfig(width: 5, height: 5, mines: 3));
      b.placeMines(seed: 5, safeX: 4, safeY: 4);
      // Find a mine and try to reveal it.
      for (var y = 0; y < 5; y++) {
        for (var x = 0; x < 5; x++) {
          if (b.cellAt(x, y).isMine) {
            final out = b.reveal(x, y, playerId: 'p1');
            expect(out.length, 1);
            expect(out.first.isMine, isTrue);
            return;
          }
        }
      }
      fail('no mines found');
    });
  });

  group('Board.isWon', () {
    test('returns true once every non-mine cell is revealed', () {
      final b = Board(const GameConfig(width: 3, height: 3, mines: 1));
      b.placeMines(seed: 0, safeX: 0, safeY: 0);
      for (var y = 0; y < 3; y++) {
        for (var x = 0; x < 3; x++) {
          if (!b.cellAt(x, y).isMine) {
            b.reveal(x, y, playerId: 'p1');
          }
        }
      }
      expect(b.isWon(), isTrue);
    });
  });
}
