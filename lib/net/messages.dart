import 'dart:convert';

import '../game/board.dart';
import '../game/difficulty.dart';
import '../game/engine.dart';

/// Protocol version. Bump on breaking change.
const protocolVersion = 3;

// ───────────────────────────────────────── Player ─────────────────────────────

class PlayerInfo {
  const PlayerInfo({
    required this.id,
    required this.name,
    required this.avatarSeed,
    required this.color,
    this.isHost = false,
    this.isReady = false,
    this.isOffline = false,
  });

  final String id;
  final String name;
  final String avatarSeed;
  final int color;
  final bool isHost;
  final bool isReady;

  /// True while this player has dropped the socket but the host is still
  /// holding their slot inside the rejoin grace window.
  final bool isOffline;

  PlayerInfo copyWith({
    String? name,
    String? avatarSeed,
    int? color,
    bool? isHost,
    bool? isReady,
    bool? isOffline,
  }) =>
      PlayerInfo(
        id: id,
        name: name ?? this.name,
        avatarSeed: avatarSeed ?? this.avatarSeed,
        color: color ?? this.color,
        isHost: isHost ?? this.isHost,
        isReady: isReady ?? this.isReady,
        isOffline: isOffline ?? this.isOffline,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatarSeed': avatarSeed,
        'color': color,
        'isHost': isHost,
        'isReady': isReady,
        'isOffline': isOffline,
      };

  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarSeed: j['avatarSeed'] as String,
        color: j['color'] as int,
        isHost: j['isHost'] as bool? ?? false,
        isReady: j['isReady'] as bool? ?? false,
        isOffline: j['isOffline'] as bool? ?? false,
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
          rejoinToken: d['rejoinToken'] as String?,
        ),
      'ping' => const CPing(),
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
      'cursorLeave' => const CCursorLeave(),
      'emoji' => CEmoji(code: d['code'] as String),
      'restart' => const CRestart(),
      'leave' => const CLeave(),
      _ => throw FormatException('unknown client message: $type'),
    };
  }
}

class CJoin extends ClientMessage {
  const CJoin({
    required this.name,
    required this.avatarSeed,
    this.rejoinToken,
  });
  final String name;
  final String avatarSeed;

  /// Optional token. When present and known to the host, the join is treated
  /// as a reconnect: the player keeps their previous id, color, and stats.
  final String? rejoinToken;

  @override
  String get _type => 'join';
  @override
  Map<String, dynamic> _payload() => {
        'name': name,
        'avatarSeed': avatarSeed,
        if (rejoinToken != null) 'rejoinToken': rejoinToken,
      };
}

/// Liveness ping from guest → host. The host replies with [SPong] immediately
/// (see [HostSession]) so each side can detect a silently dead socket.
class CPing extends ClientMessage {
  const CPing();
  @override
  String get _type => 'ping';
  @override
  Map<String, dynamic> _payload() => const {};
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

class CCursorLeave extends ClientMessage {
  const CCursorLeave();
  @override
  String get _type => 'cursorLeave';
  @override
  Map<String, dynamic> _payload() => const {};
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
          hearts: d['hearts'] as int? ?? 0,
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
          startedAtMs: d['startedAtMs'] as int? ?? 0,
          endedAtMs: d['endedAtMs'] as int? ?? 0,
        ),
      'cursor' => SCursor(
          playerId: d['playerId'] as String,
          nx: (d['nx'] as num).toDouble(),
          ny: (d['ny'] as num).toDouble(),
        ),
      'cursorLeave' =>
        SCursorLeave(playerId: d['playerId'] as String),
      'emoji' => SEmoji(
          playerId: d['playerId'] as String,
          code: d['code'] as String,
        ),
      'error' =>
        SError(code: d['code'] as String, message: d['message'] as String),
      'hearts' => SHeartsChanged(
          hearts: d['hearts'] as int,
          byPlayerId: d['byPlayerId'] as String,
          x: d['x'] as int,
          y: d['y'] as int,
          explosionCenters: (d['centers'] as List)
              .cast<List>()
              .map((p) => [p[0] as int, p[1] as int])
              .toList(),
        ),
      'pong' => const SPong(),
      'hostAway' => const SHostAway(),
      'hostBack' => const SHostBack(),
      'snapshot' => SSnapshot(
          cells: (d['cells'] as List).cast<int>(),
          flags: (d['flags'] as List)
              .cast<Map>()
              .map((m) => FlagEntry(
                    x: m['x'] as int,
                    y: m['y'] as int,
                    by: m['by'] as String,
                  ))
              .toList(),
          hearts: d['hearts'] as int? ?? 0,
          stats: (d['stats'] as Map).map(
            (k, v) => MapEntry(
                k as String,
                PlayerStats.fromJson((v as Map).cast<String, dynamic>())),
          ),
          rejoinToken: d['rejoinToken'] as String?,
        ),
      _ => throw FormatException('unknown server message: $type'),
    };
  }
}

class SHeartsChanged extends ServerMessage {
  const SHeartsChanged({
    required this.hearts,
    required this.byPlayerId,
    required this.x,
    required this.y,
    this.explosionCenters = const [],
  });
  final int hearts;
  final String byPlayerId;
  final int x;
  final int y;
  final List<List<int>> explosionCenters;
  @override
  String get _type => 'hearts';
  @override
  Map<String, dynamic> _payload() => {
        'hearts': hearts,
        'byPlayerId': byPlayerId,
        'x': x,
        'y': y,
        'centers': explosionCenters,
      };
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
    this.hearts = 0,
  });
  final String hostId;
  final List<PlayerInfo> players;
  final GameStatus status;
  final GameConfig config;
  final int hearts;
  @override
  String get _type => 'lobby';
  @override
  Map<String, dynamic> _payload() => {
        'hostId': hostId,
        'players': players.map((p) => p.toJson()).toList(),
        'status': status.name,
        'config': config.toJson(),
        'hearts': hearts,
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
    this.startedAtMs = 0,
    this.endedAtMs = 0,
  });
  final bool won;
  final String? losingPlayerId;
  final List<List<int>> minePositions;
  final Map<String, PlayerStats> stats;

  /// Epoch-ms when the game started. 0 if unknown (e.g. legacy clients).
  final int startedAtMs;

  /// Epoch-ms when the game ended. 0 if unknown.
  final int endedAtMs;
  @override
  String get _type => 'gameOver';
  @override
  Map<String, dynamic> _payload() => {
        'won': won,
        'losingPlayerId': losingPlayerId,
        'minePositions': minePositions,
        'stats': stats.map((k, v) => MapEntry(k, v.toJson())),
        'startedAtMs': startedAtMs,
        'endedAtMs': endedAtMs,
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

class SCursorLeave extends ServerMessage {
  const SCursorLeave({required this.playerId});
  final String playerId;
  @override
  String get _type => 'cursorLeave';
  @override
  Map<String, dynamic> _payload() => {'playerId': playerId};
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

/// Host's reply to [CPing]. Lets the guest's watchdog confirm the socket is
/// still alive end-to-end (not just at the TCP layer).
class SPong extends ServerMessage {
  const SPong();
  @override
  String get _type => 'pong';
  @override
  Map<String, dynamic> _payload() => const {};
}

/// Synthesized by the relay guest transport when the relay reports the host
/// has dropped its socket. The session uses this to show a "reconnecting"
/// banner without tearing down the local snapshot — the room is still alive
/// inside the host-grace window.
class SHostAway extends ServerMessage {
  const SHostAway();
  @override
  String get _type => 'hostAway';
  @override
  Map<String, dynamic> _payload() => const {};
}

/// Counterpart to [SHostAway]: the host has reclaimed the room. The session
/// re-sends [CJoin] with the saved rejoin token so the host can fast-path it
/// back into its [PlayerInfo] slot and reply with a fresh [SSnapshot].
class SHostBack extends ServerMessage {
  const SHostBack();
  @override
  String get _type => 'hostBack';
  @override
  Map<String, dynamic> _payload() => const {};
}

/// One flagged cell carried by [SSnapshot].
class FlagEntry {
  const FlagEntry({required this.x, required this.y, required this.by});
  final int x;
  final int y;
  final String by;

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'by': by};
}

/// Full mid-game board catchup. Sent by the host to a guest that just
/// (re)joined while a game is in progress, so they can replace their stale
/// local snapshot with authoritative state. Lobby/player list arrive via the
/// regular [SLobby] broadcast that precedes this message.
class SSnapshot extends ServerMessage {
  const SSnapshot({
    required this.cells,
    required this.flags,
    required this.hearts,
    required this.stats,
    this.rejoinToken,
  });

  /// width * height entries: -2 hidden, -1 mine, 0..8 number. Same encoding
  /// as `GameSnapshot.cells`.
  final List<int> cells;
  final List<FlagEntry> flags;
  final int hearts;
  final Map<String, PlayerStats> stats;

  /// Echoes back the token the host has on file for this player (whether
  /// freshly minted or reused on a rejoin). Guests store it for the next
  /// reconnect attempt.
  final String? rejoinToken;

  @override
  String get _type => 'snapshot';
  @override
  Map<String, dynamic> _payload() => {
        'cells': cells,
        'flags': flags.map((f) => f.toJson()).toList(),
        'hearts': hearts,
        'stats': stats.map((k, v) => MapEntry(k, v.toJson())),
        if (rejoinToken != null) 'rejoinToken': rejoinToken,
      };
}
