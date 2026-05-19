import 'dart:convert';

import '../game/board.dart';
import '../game/difficulty.dart';
import '../game/engine.dart';

/// Protocol version. Bump on breaking change.
const protocolVersion = 1;

// ───────────────────────────────────────── Player ─────────────────────────────

class PlayerInfo {
  const PlayerInfo({
    required this.id,
    required this.name,
    required this.avatarSeed,
    required this.color,
    this.isHost = false,
    this.isReady = false,
  });

  final String id;
  final String name;
  final String avatarSeed;
  final int color;
  final bool isHost;
  final bool isReady;

  PlayerInfo copyWith({
    String? name,
    String? avatarSeed,
    int? color,
    bool? isHost,
    bool? isReady,
  }) =>
      PlayerInfo(
        id: id,
        name: name ?? this.name,
        avatarSeed: avatarSeed ?? this.avatarSeed,
        color: color ?? this.color,
        isHost: isHost ?? this.isHost,
        isReady: isReady ?? this.isReady,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarSeed': avatarSeed,
        'color': color,
        'isHost': isHost,
        'isReady': isReady,
      };

  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarSeed: j['avatarSeed'] as String,
        color: j['color'] as int,
        isHost: j['isHost'] as bool? ?? false,
        isReady: j['isReady'] as bool? ?? false,
      );
}

// ─────────────────────────────────────── Client → Host ────────────────────────

sealed class ClientMessage {
  const ClientMessage();

  Map<String, dynamic> _payload();
  String get _type;

  String encode() => jsonEncode({'t': _type, 'd': _payload()});

  static ClientMessage decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final type = j['t'] as String;
    final d = (j['d'] as Map?)?.cast<String, dynamic>() ?? const {};
    return switch (type) {
      'join' => CJoin(
          name: d['name'] as String,
          avatarSeed: d['avatarSeed'] as String,
        ),
      'ready' => CReady(ready: d['ready'] as bool),
      'startGame' => CStartGame(
          config: GameConfig.fromJson(
              (d['config'] as Map).cast<String, dynamic>()),
        ),
      'reveal' => CReveal(x: d['x'] as int, y: d['y'] as int),
      'flag' => CFlag(x: d['x'] as int, y: d['y'] as int),
      'chord' => CChord(x: d['x'] as int, y: d['y'] as int),
      'cursor' =>
        CCursor(nx: (d['nx'] as num).toDouble(), ny: (d['ny'] as num).toDouble()),
      'emoji' => CEmoji(code: d['code'] as String),
      'restart' => const CRestart(),
      'leave' => const CLeave(),
      _ => throw FormatException('unknown client message: $type'),
    };
  }
}

class CJoin extends ClientMessage {
  const CJoin({required this.name, required this.avatarSeed});
  final String name;
  final String avatarSeed;
  @override
  String get _type => 'join';
  @override
  Map<String, dynamic> _payload() =>
      {'name': name, 'avatarSeed': avatarSeed};
}

class CReady extends ClientMessage {
  const CReady({required this.ready});
  final bool ready;
  @override
  String get _type => 'ready';
  @override
  Map<String, dynamic> _payload() => {'ready': ready};
}

class CStartGame extends ClientMessage {
  const CStartGame({required this.config});
  final GameConfig config;
  @override
  String get _type => 'startGame';
  @override
  Map<String, dynamic> _payload() => {'config': config.toJson()};
}

class CReveal extends ClientMessage {
  const CReveal({required this.x, required this.y});
  final int x;
  final int y;
  @override
  String get _type => 'reveal';
  @override
  Map<String, dynamic> _payload() => {'x': x, 'y': y};
}

class CFlag extends ClientMessage {
  const CFlag({required this.x, required this.y});
  final int x;
  final int y;
  @override
  String get _type => 'flag';
  @override
  Map<String, dynamic> _payload() => {'x': x, 'y': y};
}

class CChord extends ClientMessage {
  const CChord({required this.x, required this.y});
  final int x;
  final int y;
  @override
  String get _type => 'chord';
  @override
  Map<String, dynamic> _payload() => {'x': x, 'y': y};
}

class CCursor extends ClientMessage {
  const CCursor({required this.nx, required this.ny});
  final double nx;
  final double ny;
  @override
  String get _type => 'cursor';
  @override
  Map<String, dynamic> _payload() => {'nx': nx, 'ny': ny};
}

class CEmoji extends ClientMessage {
  const CEmoji({required this.code});
  final String code;
  @override
  String get _type => 'emoji';
  @override
  Map<String, dynamic> _payload() => {'code': code};
}

class CRestart extends ClientMessage {
  const CRestart();
  @override
  String get _type => 'restart';
  @override
  Map<String, dynamic> _payload() => const {};
}

class CLeave extends ClientMessage {
  const CLeave();
  @override
  String get _type => 'leave';
  @override
  Map<String, dynamic> _payload() => const {};
}

// ─────────────────────────────────────── Host → Client ────────────────────────

sealed class ServerMessage {
  const ServerMessage();

  Map<String, dynamic> _payload();
  String get _type;

  String encode() => jsonEncode({'t': _type, 'd': _payload()});

  static ServerMessage decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final type = j['t'] as String;
    final d = (j['d'] as Map?)?.cast<String, dynamic>() ?? const {};
    return switch (type) {
      'welcome' => SWelcome(
          yourId: d['yourId'] as String,
          protocol: d['protocol'] as int,
        ),
      'lobby' => SLobby(
          hostId: d['hostId'] as String,
          players: (d['players'] as List)
              .cast<Map>()
              .map((m) => PlayerInfo.fromJson(m.cast<String, dynamic>()))
              .toList(),
          status: GameStatus.values.byName(d['status'] as String),
          config: GameConfig.fromJson(
              (d['config'] as Map).cast<String, dynamic>()),
        ),
      'gameStarted' => SGameStarted(
          config: GameConfig.fromJson(
              (d['config'] as Map).cast<String, dynamic>()),
          seed: d['seed'] as int,
          startedAt: d['startedAt'] as int,
        ),
      'revealed' => SRevealed(
          cells: (d['cells'] as List)
              .cast<Map>()
              .map((m) => Reveal.fromJson(m.cast<String, dynamic>()))
              .toList(),
          byPlayerId: d['byPlayerId'] as String,
        ),
      'flagged' => SFlagged(
          x: d['x'] as int,
          y: d['y'] as int,
          flagged: d['flagged'] as bool,
          byPlayerId: d['byPlayerId'] as String,
        ),
      'gameOver' => SGameOver(
          won: d['won'] as bool,
          losingPlayerId: d['losingPlayerId'] as String?,
          minePositions: (d['minePositions'] as List)
              .cast<List>()
              .map((p) => [p[0] as int, p[1] as int])
              .toList(),
          stats: (d['stats'] as Map).map(
            (k, v) => MapEntry(
                k as String, PlayerStats.fromJson((v as Map).cast<String, dynamic>())),
          ),
        ),
      'cursor' => SCursor(
          playerId: d['playerId'] as String,
          nx: (d['nx'] as num).toDouble(),
          ny: (d['ny'] as num).toDouble(),
        ),
      'emoji' => SEmoji(
          playerId: d['playerId'] as String,
          code: d['code'] as String,
        ),
      'error' =>
        SError(code: d['code'] as String, message: d['message'] as String),
      _ => throw FormatException('unknown server message: $type'),
    };
  }
}

class SWelcome extends ServerMessage {
  const SWelcome({required this.yourId, required this.protocol});
  final String yourId;
  final int protocol;
  @override
  String get _type => 'welcome';
  @override
  Map<String, dynamic> _payload() =>
      {'yourId': yourId, 'protocol': protocol};
}

class SLobby extends ServerMessage {
  const SLobby({
    required this.hostId,
    required this.players,
    required this.status,
    required this.config,
  });
  final String hostId;
  final List<PlayerInfo> players;
  final GameStatus status;
  final GameConfig config;
  @override
  String get _type => 'lobby';
  @override
  Map<String, dynamic> _payload() => {
        'hostId': hostId,
        'players': players.map((p) => p.toJson()).toList(),
        'status': status.name,
        'config': config.toJson(),
      };
}

class SGameStarted extends ServerMessage {
  const SGameStarted({
    required this.config,
    required this.seed,
    required this.startedAt,
  });
  final GameConfig config;
  final int seed;
  final int startedAt;
  @override
  String get _type => 'gameStarted';
  @override
  Map<String, dynamic> _payload() => {
        'config': config.toJson(),
        'seed': seed,
        'startedAt': startedAt,
      };
}

class SRevealed extends ServerMessage {
  const SRevealed({required this.cells, required this.byPlayerId});
  final List<Reveal> cells;
  final String byPlayerId;
  @override
  String get _type => 'revealed';
  @override
  Map<String, dynamic> _payload() => {
        'cells': cells.map((c) => c.toJson()).toList(),
        'byPlayerId': byPlayerId,
      };
}

class SFlagged extends ServerMessage {
  const SFlagged({
    required this.x,
    required this.y,
    required this.flagged,
    required this.byPlayerId,
  });
  final int x;
  final int y;
  final bool flagged;
  final String byPlayerId;
  @override
  String get _type => 'flagged';
  @override
  Map<String, dynamic> _payload() => {
        'x': x,
        'y': y,
        'flagged': flagged,
        'byPlayerId': byPlayerId,
      };
}

class SGameOver extends ServerMessage {
  const SGameOver({
    required this.won,
    required this.losingPlayerId,
    required this.minePositions,
    required this.stats,
  });
  final bool won;
  final String? losingPlayerId;
  final List<List<int>> minePositions;
  final Map<String, PlayerStats> stats;
  @override
  String get _type => 'gameOver';
  @override
  Map<String, dynamic> _payload() => {
        'won': won,
        'losingPlayerId': losingPlayerId,
        'minePositions': minePositions,
        'stats': stats.map((k, v) => MapEntry(k, v.toJson())),
      };
}

class SCursor extends ServerMessage {
  const SCursor({
    required this.playerId,
    required this.nx,
    required this.ny,
  });
  final String playerId;
  final double nx;
  final double ny;
  @override
  String get _type => 'cursor';
  @override
  Map<String, dynamic> _payload() =>
      {'playerId': playerId, 'nx': nx, 'ny': ny};
}

class SEmoji extends ServerMessage {
  const SEmoji({required this.playerId, required this.code});
  final String playerId;
  final String code;
  @override
  String get _type => 'emoji';
  @override
  Map<String, dynamic> _payload() => {'playerId': playerId, 'code': code};
}

class SError extends ServerMessage {
  const SError({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String get _type => 'error';
  @override
  Map<String, dynamic> _payload() => {'code': code, 'message': message};
}
