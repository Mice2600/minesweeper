import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeper/game/board.dart';
import 'package:minesweeper/game/difficulty.dart';
import 'package:minesweeper/game/engine.dart';
import 'package:minesweeper/net/messages.dart';

void main() {
  group('ClientMessage round-trip', () {
    final cases = <ClientMessage>[
      const CJoin(name: 'Alice', avatarSeed: 'abc'),
      const CReady(ready: true),
      const CStartGame(
          config: GameConfig(width: 9, height: 9, mines: 10)),
      const CReveal(x: 3, y: 7),
      const CFlag(x: 0, y: 0),
      const CChord(x: 1, y: 1),
      const CCursor(nx: 0.5, ny: 0.25),
      const CEmoji(code: '🎉'),
      const CRestart(),
      const CLeave(),
    ];

    for (final m in cases) {
      test(m.runtimeType.toString(), () {
        final encoded = m.encode();
        final decoded = ClientMessage.decode(encoded);
        expect(decoded.runtimeType, m.runtimeType);
        expect(decoded.encode(), encoded);
      });
    }
  });

  group('ServerMessage round-trip', () {
    final cases = <ServerMessage>[
      const SWelcome(yourId: 'abc', protocol: 4),
      SLobby(
        hostId: 'h',
        players: const [
          PlayerInfo(
              id: 'h',
              name: 'Host',
              avatarSeed: 'x',
              color: 0xFFAABBCC,
              isHost: true),
        ],
        status: GameStatus.waiting,
        config: const GameConfig(width: 9, height: 9, mines: 10),
      ),
      const SGameStarted(
        config: GameConfig(width: 9, height: 9, mines: 10),
        seed: 42,
        startedAt: 1234567890,
      ),
      SRevealed(
        cells: const [Reveal(x: 0, y: 0, value: 0)],
        byPlayerId: 'h',
      ),
      const SFlagged(x: 1, y: 2, mark: CellMark.flag, byPlayerId: 'h'),
      SGameOver(
        won: true,
        losingPlayerId: null,
        minePositions: const [
          [3, 4],
        ],
        stats: {'h': PlayerStats(cellsRevealed: 5, flagsPlaced: 2)},
      ),
      const SCursor(playerId: 'h', nx: 0.1, ny: 0.9),
      const SEmoji(playerId: 'h', code: '👍'),
      const SError(code: 'oops', message: 'something happened'),
      const SHeartsChanged(
        hearts: 2,
        byPlayerId: 'h',
        x: 5,
        y: 6,
        explosionCenters: [
          [5, 6],
          [6, 6]
        ],
      ),
    ];

    for (final m in cases) {
      test(m.runtimeType.toString(), () {
        final encoded = m.encode();
        final decoded = ServerMessage.decode(encoded);
        expect(decoded.runtimeType, m.runtimeType);
        expect(decoded.encode(), encoded);
      });
    }
  });
}
