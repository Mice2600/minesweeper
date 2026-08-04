import 'dart:convert';

import '../game/board.dart';
import '../game/difficulty.dart';
import '../game/engine.dart';

/// Protocol version. Bump on breaking change.
///
/// v4: `SRevealed.cells` carries a packed `[x,y,v, x,y,v, …]` int list
/// instead of an array of `{x,y,value,mine?}` maps. Same information, ~60%
/// smaller on the wire — important for flood-fills that uncover hundreds of
/// cells in one frame.
///
/// v5: adds `CChat`/`SChat` (player text chat). Also makes both `decode`
/// switches tolerant of unknown message types ([CUnknown]/[SUnknown]) so a
/// future protocol addition no longer tears down a connection to a peer that
/// hasn't been updated yet.
///
/// v6: safety tools for user-generated content — `CKick`/`SKicked` (host
/// removes a player), `CReport`/`SReportAck`/`SModerationNotice` (any player
/// reports another to the host). Additive only: a v5 peer decodes all five as
/// [CUnknown]/[SUnknown] and keeps playing, it just can't moderate.
const protocolVersion = 6;

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
    this.avatarData,
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

  /// Base64-encoded JPEG avatar photo (72×72, q70). Null = use seed gradient.
  final String? avatarData;

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
        avatarData: avatarData,
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
        if (avatarData != null) 'av': avatarData,
      };

  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        avatarSeed: j['avatarSeed'] as String,
        color: j['color'] as int,
        isHost: j['isHost'] as bool? ?? false,
        isReady: j['isReady'] as bool? ?? false,
        isOffline: j['isOffline'] as bool? ?? false,
        avatarData: j['av'] as String?,
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
          avatarData: d['av'] as String?,
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
      'chat' => CChat(text: d['text'] as String),
      'kick' => CKick(
          playerId: d['playerId'] as String,
          reason: d['reason'] as String?,
        ),
      'report' => CReport(
          playerId: d['playerId'] as String,
          reason: d['reason'] as String,
          details: d['details'] as String?,
        ),
      'restart' => const CRestart(),
      'leave' => const CLeave(),
      // Unknown types are kept (not thrown) so a newer peer's additions don't
      // kill this connection — see [CUnknown].
      _ => CUnknown(type),
    };
  }
}

class CJoin extends ClientMessage {
  const CJoin({
    required this.name,
    required this.avatarSeed,
    this.rejoinToken,
    this.avatarData,
  });
  final String name;
  final String avatarSeed;

  /// Optional token. When present and known to the host, the join is treated
  /// as a reconnect: the player keeps their previous id, color, and stats.
  final String? rejoinToken;

  /// Base64-encoded JPEG avatar photo. Null = use seed gradient.
  final String? avatarData;

  @override
  String get _type => 'join';
  @override
  Map<String, dynamic> _payload() => {
        'name': name,
        'avatarSeed': avatarSeed,
        if (rejoinToken != null) 'rejoinToken': rejoinToken,
        if (avatarData != null) 'av': avatarData,
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

/// Free-text chat from a guest → host. The host trims/caps it and re-broadcasts
/// an authoritative [SChat] (with the author's name + timestamp) to everyone.
class CChat extends ClientMessage {
  const CChat({required this.text});
  final String text;
  @override
  String get _type => 'chat';
  @override
  Map<String, dynamic> _payload() => {'text': text};
}

/// Host-only intent: remove [playerId] from the room. The host validates the
/// sender (a guest sending this gets an `notHost` [SError]), tells the target
/// with [SKicked], drops their socket, and refuses their rejoin token for the
/// life of the room.
class CKick extends ClientMessage {
  const CKick({required this.playerId, this.reason});

  /// Logical id of the player to remove.
  final String playerId;

  /// Short free-text shown to the removed player. Null → a generic message.
  final String? reason;

  @override
  String get _type => 'kick';
  @override
  Map<String, dynamic> _payload() => {
        'playerId': playerId,
        if (reason != null) 'reason': reason,
      };
}

/// Any player → host: flag [playerId] for abusive content. The host is the
/// room's moderator, so this is what gives it something to act on; the
/// reporter also keeps a local copy (see `ReportLog`) that they can forward to
/// the developer. The host replies with [SReportAck] and raises a local
/// [SModerationNotice] on its own UI.
class CReport extends ClientMessage {
  const CReport({
    required this.playerId,
    required this.reason,
    this.details,
  });

  /// Logical id of the reported player.
  final String playerId;

  /// One of the fixed reason slugs (`abusiveChat`, `harassment`,
  /// `inappropriateAvatar`, `inappropriateName`, `spam`, `other`).
  final String reason;

  /// Optional free text from the reporter.
  final String? details;

  @override
  String get _type => 'report';
  @override
  Map<String, dynamic> _payload() => {
        'playerId': playerId,
        'reason': reason,
        if (details != null) 'details': details,
      };
}

/// A client message whose `t` this build doesn't recognize. Produced by
/// [ClientMessage.decode] instead of throwing, so forward-compat additions from
/// a newer peer are ignored rather than dropping the connection. Never sent.
class CUnknown extends ClientMessage {
  const CUnknown(this.type);
  final String type;
  @override
  String get _type => type;
  @override
  Map<String, dynamic> _payload() => const {};
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
          cells: _decodeReveals(d['cells']),
          byPlayerId: d['byPlayerId'] as String,
        ),
      'flagged' => SFlagged(
          x: d['x'] as int,
          y: d['y'] as int,
          mark: _markFromJson(d['mark'], d['flagged']),
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
      'chat' => SChat(
          playerId: d['playerId'] as String,
          name: d['name'] as String,
          text: d['text'] as String,
          ts: d['ts'] as int,
        ),
      'kicked' => SKicked(reason: d['reason'] as String? ?? ''),
      'reportAck' => SReportAck(targetId: d['targetId'] as String? ?? ''),
      'moderationNotice' => SModerationNotice(
          reporterId: d['reporterId'] as String? ?? '',
          reporterName: d['reporterName'] as String? ?? '',
          targetId: d['targetId'] as String? ?? '',
          targetName: d['targetName'] as String? ?? '',
          reason: d['reason'] as String? ?? 'other',
          details: d['details'] as String?,
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
      'playerPatch' => SPlayerPatch(
          playerId: d['playerId'] as String,
          isReady: d['isReady'] as bool?,
          isOffline: d['isOffline'] as bool?,
          name: d['name'] as String?,
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
          heartsLostBy:
              ((d['heartsLostBy'] as List?) ?? const []).cast<String>(),
          rejoinToken: d['rejoinToken'] as String?,
        ),
      // Unknown types are kept (not thrown) so a newer host's additions don't
      // kill this connection — see [SUnknown].
      _ => SUnknown(type),
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
  Map<String, dynamic> _payload() {
    // Packed triplet form: [x0,y0,v0, x1,y1,v1, ...]. Drops field names
    // (`x`, `y`, `value`) and the rarely-used `mine` flag — value == -1
    // already encodes a mine, which is all the client reducer looks at.
    final flat = List<int>.filled(cells.length * 3, 0);
    for (var i = 0; i < cells.length; i++) {
      final c = cells[i];
      flat[i * 3] = c.x;
      flat[i * 3 + 1] = c.y;
      flat[i * 3 + 2] = c.value;
    }
    return {
      'cells': flat,
      'byPlayerId': byPlayerId,
    };
  }
}

/// Decodes either the packed v4 form (flat int triplets) or the legacy v3
/// form (array of `{x,y,value,mine?}` maps), so a client running this build
/// can still talk to a host that hasn't been upgraded yet.
List<Reveal> _decodeReveals(Object? raw) {
  if (raw is! List) return const [];
  if (raw.isEmpty) return const [];
  final first = raw.first;
  if (first is num) {
    // Packed: [x,y,v, x,y,v, ...]
    final out = <Reveal>[];
    for (var i = 0; i + 2 < raw.length; i += 3) {
      final x = (raw[i] as num).toInt();
      final y = (raw[i + 1] as num).toInt();
      final v = (raw[i + 2] as num).toInt();
      out.add(Reveal(x: x, y: y, value: v, isMine: v == -1));
    }
    return out;
  }
  // Legacy maps.
  return raw
      .cast<Map>()
      .map((m) => Reveal.fromJson(m.cast<String, dynamic>()))
      .toList();
}

class SFlagged extends ServerMessage {
  const SFlagged({
    required this.x,
    required this.y,
    required this.mark,
    required this.byPlayerId,
  });
  final int x;
  final int y;
  final CellMark mark;
  final String byPlayerId;

  bool get flagged => mark == CellMark.flag;
  bool get questioned => mark == CellMark.question;

  @override
  String get _type => 'flagged';
  @override
  Map<String, dynamic> _payload() => {
        'x': x,
        'y': y,
        'mark': mark.name,
        // Legacy field kept so older builds can still decode our messages.
        'flagged': flagged,
        'byPlayerId': byPlayerId,
      };
}

/// Decodes a CellMark from a wire payload. Prefer the explicit `mark` string
/// when present; otherwise fall back to the legacy `flagged: bool` field.
CellMark _markFromJson(Object? markRaw, Object? flaggedRaw) {
  if (markRaw is String) {
    for (final m in CellMark.values) {
      if (m.name == markRaw) return m;
    }
  }
  if (flaggedRaw is bool) {
    return flaggedRaw ? CellMark.flag : CellMark.none;
  }
  return CellMark.none;
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

/// Authoritative chat line broadcast by the host. [playerId] is the logical
/// author id (resolve their live avatar/color via `GameSnapshot.playerById`);
/// [name] is a snapshot of their name at send time (fallback if they later
/// leave); [ts] is host epoch-ms, the single source of truth for ordering.
class SChat extends ServerMessage {
  const SChat({
    required this.playerId,
    required this.name,
    required this.text,
    required this.ts,
  });
  final String playerId;
  final String name;
  final String text;
  final int ts;
  @override
  String get _type => 'chat';
  @override
  Map<String, dynamic> _payload() =>
      {'playerId': playerId, 'name': name, 'text': text, 'ts': ts};
}

/// Sent to a player the host is removing, immediately before their socket is
/// dropped. Distinct from [SError] because the guest must *not* treat it as a
/// transient failure: the session cancels its reconnect loop on receipt, since
/// the host will also refuse the rejoin token.
class SKicked extends ServerMessage {
  const SKicked({required this.reason});

  /// Host-supplied explanation. May be empty.
  final String reason;

  @override
  String get _type => 'kicked';
  @override
  Map<String, dynamic> _payload() => {'reason': reason};
}

/// Host's acknowledgement of a [CReport], so the reporter's UI can confirm the
/// report actually reached the room owner rather than optimistically claiming
/// it did.
class SReportAck extends ServerMessage {
  const SReportAck({required this.targetId});

  /// Logical id of the player that was reported.
  final String targetId;

  @override
  String get _type => 'reportAck';
  @override
  Map<String, dynamic> _payload() => {'targetId': targetId};
}

/// Raised on the **host's own** event stream when a [CReport] arrives, so the
/// host UI can surface "X reported Y" and offer to kick. Never broadcast — the
/// rest of the room has no business seeing who reported whom.
class SModerationNotice extends ServerMessage {
  const SModerationNotice({
    required this.reporterId,
    required this.reporterName,
    required this.targetId,
    required this.targetName,
    required this.reason,
    this.details,
  });

  final String reporterId;
  final String reporterName;
  final String targetId;
  final String targetName;

  /// Reason slug — see [CReport.reason].
  final String reason;
  final String? details;

  @override
  String get _type => 'moderationNotice';
  @override
  Map<String, dynamic> _payload() => {
        'reporterId': reporterId,
        'reporterName': reporterName,
        'targetId': targetId,
        'targetName': targetName,
        'reason': reason,
        if (details != null) 'details': details,
      };
}

/// A server message whose `t` this build doesn't recognize. Produced by
/// [ServerMessage.decode] instead of throwing, so forward-compat additions from
/// a newer host are ignored rather than dropping the connection. Never sent.
class SUnknown extends ServerMessage {
  const SUnknown(this.type);
  final String type;
  @override
  String get _type => type;
  @override
  Map<String, dynamic> _payload() => const {};
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

/// Partial player update — used for high-frequency lobby changes (ready
/// toggles, going-offline / coming-back) so we don't have to re-broadcast the
/// whole [SLobby] every time. Any field left null is unchanged.
class SPlayerPatch extends ServerMessage {
  const SPlayerPatch({
    required this.playerId,
    this.isReady,
    this.isOffline,
    this.name,
  });
  final String playerId;
  final bool? isReady;
  final bool? isOffline;
  final String? name;

  @override
  String get _type => 'playerPatch';
  @override
  Map<String, dynamic> _payload() => {
        'playerId': playerId,
        if (isReady != null) 'isReady': isReady,
        if (isOffline != null) 'isOffline': isOffline,
        if (name != null) 'name': name,
      };
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
    this.heartsLostBy = const [],
    this.rejoinToken,
  });

  /// width * height entries: -2 hidden, -1 mine, 0..8 number. Same encoding
  /// as `GameSnapshot.cells`.
  final List<int> cells;
  final List<FlagEntry> flags;
  final int hearts;
  final Map<String, PlayerStats> stats;

  /// Chronological list of player ids that lost each heart so far
  /// (length = initialHearts - hearts). Needed on rejoin so the catch-up
  /// guest can render the same per-heart attribution as everyone else.
  final List<String> heartsLostBy;

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
        if (heartsLostBy.isNotEmpty) 'heartsLostBy': heartsLostBy,
        if (rejoinToken != null) 'rejoinToken': rejoinToken,
      };
}
