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
      const CChat(text: 'hello world'),
      const CKick(playerId: 'p1'),
      const CKick(playerId: 'p1', reason: 'spamming'),
      const CReport(playerId: 'p1', reason: 'harassment'),
      const CReport(
          playerId: 'p1', reason: 'abusiveChat', details: 'kept swearing'),
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
      const SWelcome(yourId: 'abc', protocol: 5),
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
      const SChat(playerId: 'h', name: 'Host', text: 'hi all', ts: 1234567890),
      const SError(code: 'oops', message: 'something happened'),
      const SKicked(reason: 'The host removed you from this game.'),
      const SReportAck(targetId: 'p1'),
      const SModerationNotice(
        reporterId: 'p2',
        reporterName: 'Bea',
        targetId: 'p1',
        targetName: 'Al',
        reason: 'harassment',
        details: 'would not stop',
      ),
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

  group('forward compatibility', () {
    // The whole point of CUnknown/SUnknown: a v5 peer must survive the v6
    // moderation messages rather than tearing the connection down.
    test('unknown client type decodes to CUnknown, not a throw', () {
      final decoded =
          ClientMessage.decode('{"t":"somethingFromV9","d":{"a":1}}');
      expect(decoded, isA<CUnknown>());
    });

    test('unknown server type decodes to SUnknown, not a throw', () {
      final decoded =
          ServerMessage.decode('{"t":"somethingFromV9","d":{"a":1}}');
      expect(decoded, isA<SUnknown>());
    });

    test('optional moderation fields tolerate absence', () {
      final kicked = ServerMessage.decode('{"t":"kicked","d":{}}') as SKicked;
      expect(kicked.reason, '');
      final notice = ServerMessage.decode(
          '{"t":"moderationNotice","d":{"targetId":"p1"}}') as SModerationNotice;
      expect(notice.targetId, 'p1');
      expect(notice.reason, 'other');
      expect(notice.details, isNull);
    });
  });
}
