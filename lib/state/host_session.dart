import 'dart:async';

import '../core/ids.dart';
import '../game/board.dart';
import '../game/difficulty.dart';
import '../game/engine.dart';
import '../net/messages.dart';
import '../net/transport.dart';

/// Engine + lobby state for the host. Receives [HostTransportEvent]s from a
/// [HostTransport], applies them to the authoritative [GameEngine], and sends
/// the resulting [ServerMessage]s back out via the transport.
///
/// The host's own UI subscribes to [localEvents] to see the same messages a
/// guest would, so the rendering path is identical.
class HostSession {
  HostSession({
    required this.hostName,
    required this.hostAvatarSeed,
    required this.config,
    required this.transport,
  });

  final String hostName;
  final String hostAvatarSeed;
  GameConfig config;
  final HostTransport transport;

  late final String hostId = shortId();

  GameEngine? _engine;
  GameEngine? get engine => _engine;

  final Map<String, PlayerInfo> _players = {};
  Iterable<PlayerInfo> get players => _players.values;

  final StreamController<ServerMessage> _localCtrl =
      StreamController<ServerMessage>.broadcast();

  /// The host's UI subscribes here — same shape as a guest's stream.
  Stream<ServerMessage> get localEvents => _localCtrl.stream;

  StreamSubscription<HostTransportEvent>? _sub;
  HostJoinInfo? _joinInfo;
  HostJoinInfo? get joinInfo => _joinInfo;

  // ─── Reconnect bookkeeping (host side) ──────────────────────────────────
  // Guests get a fresh transport id from the relay/LAN socket on every
  // connect, but their *logical* player id (what's stored in [_players] and
  // in the [GameEngine] stats/board) must be stable so reveals, flags, and
  // PlayerStats survive a drop. These maps translate between the two.
  final Map<String, String> _transportToLogical = {}; // transportId → logical
  final Map<String, String> _logicalToTransport = {}; // logical → transportId
  final Map<String, String> _playerToken = {}; // logicalId → rejoinToken
  final Map<String, String> _tokenToPlayer = {}; // rejoinToken → logicalId
  final Map<String, Timer> _graceTimers = {}; // logicalId → eviction timer
  static const _graceWindow = Duration(seconds: 30);

  Future<HostJoinInfo> start() async {
    _sub = transport.events.listen(_handleTransportEvent);
    final info = await transport.start();
    _joinInfo = info;
    _players[hostId] = PlayerInfo(
      id: hostId,
      name: hostName,
      avatarSeed: hostAvatarSeed,
      color: _colorFor(0),
      isHost: true,
      isReady: true,
    );
    _broadcastLobby();
    return info;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    for (final t in _graceTimers.values) {
      t.cancel();
    }
    _graceTimers.clear();
    await transport.stop();
    if (!_localCtrl.isClosed) await _localCtrl.close();
  }

  /// Host's own UI feeds intents through here.
  void onLocalIntent(ClientMessage msg) => _applyClientMessage(hostId, msg);

  /// Host UI updates config (e.g. switching difficulty in the lobby).
  void setConfig(GameConfig cfg) {
    config = cfg;
    _broadcastLobby();
  }

  /// Public so [SessionNotifier] can force a lobby refresh after subscribing.
  void broadcastLobby() => _broadcastLobby();

  // ─── Transport events ──────────────────────────────────────────────────────

  void _handleTransportEvent(HostTransportEvent e) {
    switch (e) {
      case GuestConnected(:final playerId):
        // Provisional welcome with the transport id. If their CJoin carries
        // a known rejoin token, we'll send a corrected SWelcome that points
        // at the *logical* id instead, and the guest will overwrite their
        // local id accordingly.
        transport.sendToGuest(
          playerId,
          SWelcome(yourId: playerId, protocol: protocolVersion),
        );
      case GuestMessage(:final playerId, :final message):
        _applyClientMessage(playerId, message);
      case GuestDisconnected(:final playerId):
        _onGuestDisconnected(playerId);
      case HostTransportError(:final code, :final message):
        // The transport surfaces its own reconnect lifecycle through these
        // codes so the host UI can show the same "reconnecting" banner a
        // guest gets when the host went away.
        if (code == 'reclaiming') {
          _localCtrl.add(const SHostAway());
        } else if (code == 'reclaimed') {
          _localCtrl.add(const SHostBack());
        } else {
          _localCtrl.add(SError(code: code, message: message));
        }
    }
  }

  void _onGuestDisconnected(String transportId) {
    final logicalId = _transportToLogical.remove(transportId) ?? transportId;
    // Keep the logical→transport map clean. (Don't remove on tearDown though
    // — only on a confirmed disconnect of *this* transport id.)
    if (_logicalToTransport[logicalId] == transportId) {
      _logicalToTransport.remove(logicalId);
    }
    final existing = _players[logicalId];
    if (existing == null) return;

    // Mark the slot offline immediately so the UI can show a "reconnecting"
    // badge — but hold the player record for the grace window so a rejoin
    // can restore them in place. Patch instead of full lobby; the player set
    // hasn't actually changed yet.
    _players[logicalId] = existing.copyWith(isOffline: true);
    _broadcast(SPlayerPatch(playerId: logicalId, isOffline: true));

    _graceTimers[logicalId]?.cancel();
    _graceTimers[logicalId] = Timer(_graceWindow, () {
      _graceTimers.remove(logicalId);
      final stillOffline = _players[logicalId]?.isOffline ?? false;
      if (!stillOffline) return;
      _players.remove(logicalId);
      final token = _playerToken.remove(logicalId);
      if (token != null) _tokenToPlayer.remove(token);
      _broadcastLobby();
    });
  }

  // ─── Game logic dispatch ───────────────────────────────────────────────────

  /// [transportId] is whatever the transport tagged the inbound message with
  /// — the relay-assigned guest id, the LAN socket id, or [hostId] for local
  /// intents. It's mapped to the logical player id via [_transportToLogical]
  /// (CJoin/rejoin populates this).
  void _applyClientMessage(String transportId, ClientMessage msg) {
    final logicalId = _logicalIdFor(transportId);
    switch (msg) {
      case CJoin(:final name, :final avatarSeed, :final rejoinToken):
        _handleJoin(transportId, name, avatarSeed, rejoinToken);
      case CPing():
        _sendTo(logicalId, const SPong());
      case CReady(:final ready):
        final p = _players[logicalId];
        if (p == null) return;
        _players[logicalId] = p.copyWith(isReady: ready);
        // Just patch the one field instead of re-broadcasting the whole lobby
        // — ready toggling is the most-clicked button in the lobby.
        _broadcast(SPlayerPatch(playerId: logicalId, isReady: ready));
      case CStartGame(:final config):
        if (logicalId != hostId) {
          _sendTo(logicalId,
              const SError(code: 'notHost', message: 'Only host can start'));
          return;
        }
        this.config = config;
        _engine = GameEngine(config);
        _broadcast(SGameStarted(
          config: config,
          seed: _engine!.seed,
          startedAt: DateTime.now().millisecondsSinceEpoch,
        ));
      case CReveal(:final x, :final y):
        final e = _engine;
        if (e == null) return;
        final out = e.reveal(x, y, playerId: logicalId);
        if (out.cells.isNotEmpty) {
          _broadcast(SRevealed(cells: out.cells, byPlayerId: out.byPlayerId));
        }
        if (out.heartLost) {
          _broadcast(SHeartsChanged(
            hearts: out.heartsRemaining,
            byPlayerId: logicalId,
            x: out.triggerX,
            y: out.triggerY,
            explosionCenters: out.explosionCenters,
          ));
        }
        _checkGameEnd();
      case CFlag(:final x, :final y):
        final e = _engine;
        if (e == null) return;
        final out = e.flag(x, y, playerId: logicalId);
        if (out != null) {
          _broadcast(SFlagged(
            x: out.x,
            y: out.y,
            mark: out.mark,
            byPlayerId: out.byPlayerId,
          ));
        }
      case CChord(:final x, :final y):
        final e = _engine;
        if (e == null) return;
        final out = e.chord(x, y, playerId: logicalId);
        if (out.cells.isNotEmpty) {
          _broadcast(SRevealed(cells: out.cells, byPlayerId: out.byPlayerId));
        }
        for (final p in out.autoFlagged) {
          _broadcast(SFlagged(
            x: p[0],
            y: p[1],
            mark: CellMark.flag,
            byPlayerId: logicalId,
          ));
        }
        if (out.heartLost) {
          _broadcast(SHeartsChanged(
            hearts: out.heartsRemaining,
            byPlayerId: logicalId,
            x: out.triggerX,
            y: out.triggerY,
            explosionCenters: out.explosionCenters,
          ));
        }
        _checkGameEnd();
      case CCursor(:final nx, :final ny):
        _broadcast(SCursor(playerId: logicalId, nx: nx, ny: ny),
            excludePlayerId: logicalId);
      case CCursorLeave():
        _broadcast(SCursorLeave(playerId: logicalId),
            excludePlayerId: logicalId);
      case CEmoji(:final code):
        _broadcast(SEmoji(playerId: logicalId, code: code));
      case CRestart():
        if (logicalId != hostId) return;
        _engine = null;
        _broadcastLobby();
      case CLeave():
        // The transport will surface a GuestDisconnected when the socket
        // closes; that path runs the grace timer and broadcasts the lobby.
        break;
    }
  }

  void _handleJoin(
    String transportId,
    String name,
    String avatarSeed,
    String? rejoinToken,
  ) {
    // 1) Rejoin path: token matches a player we're holding inside the grace
    //    window. Reuse their logical id (and color and stats and board
    //    ownership). Cancel the eviction timer.
    if (rejoinToken != null && _tokenToPlayer.containsKey(rejoinToken)) {
      final oldLogicalId = _tokenToPlayer[rejoinToken]!;
      _graceTimers.remove(oldLogicalId)?.cancel();

      // Re-bind this transport connection to the old logical id.
      _bindTransport(transportId, oldLogicalId);

      final existing = _players[oldLogicalId];
      if (existing != null) {
        _players[oldLogicalId] = existing.copyWith(
          name: name,
          avatarSeed: avatarSeed,
          isOffline: false,
        );
      } else {
        // The grace timer had already fired before this rejoin landed —
        // treat it as a fresh join under the supplied token instead of
        // creating an orphaned record.
        _materializeNewPlayer(
            transportId, name, avatarSeed, token: rejoinToken);
        return;
      }

      // Tell the rejoining guest their authoritative id, then refresh the
      // lobby for everyone, then catch this guest up mid-game.
      transport.sendToGuest(
        transportId,
        SWelcome(yourId: oldLogicalId, protocol: protocolVersion),
      );
      _broadcastLobby();
      _sendMidGameSnapshot(oldLogicalId, transportId);
      return;
    }

    // 2) Fresh join.
    _materializeNewPlayer(
        transportId, name, avatarSeed, token: rejoinToken ?? shortId(20));
  }

  void _materializeNewPlayer(
    String transportId,
    String name,
    String avatarSeed, {
    required String token,
  }) {
    final logicalId = transportId; // brand-new player: ids coincide
    _bindTransport(transportId, logicalId);
    _playerToken[logicalId] = token;
    _tokenToPlayer[token] = logicalId;
    _players[logicalId] = PlayerInfo(
      id: logicalId,
      name: name,
      avatarSeed: avatarSeed,
      color: _colorFor(_players.length),
    );
    _broadcastLobby();
    // If a game is already underway, hand them a full board state so they
    // can render it correctly instead of starting from a blank snapshot.
    _sendMidGameSnapshot(logicalId, transportId);
  }

  void _bindTransport(String transportId, String logicalId) {
    // Drop any prior reverse mapping for this logical id (the previous
    // transport socket is gone) and any prior mapping for this transport id.
    final stale = _logicalToTransport[logicalId];
    if (stale != null && stale != transportId) {
      _transportToLogical.remove(stale);
    }
    _transportToLogical[transportId] = logicalId;
    _logicalToTransport[logicalId] = transportId;
  }

  String _logicalIdFor(String transportId) {
    if (transportId == hostId) return hostId;
    return _transportToLogical[transportId] ?? transportId;
  }

  /// Pushes the engine's current board + flags + hearts + stats to a single
  /// guest. Used on first join (no-op effect: empty board) and on rejoin to
  /// resync a guest whose local snapshot is now stale.
  void _sendMidGameSnapshot(String logicalId, String transportId) {
    final e = _engine;
    if (e == null) return; // lobby state, nothing to catch up
    if (e.status == GameStatus.waiting) return;

    final board = e.board;
    final width = board.width;
    final height = board.height;
    final cells = List<int>.filled(width * height, -2);
    final flags = <FlagEntry>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final c = board.cellAt(x, y);
        if (c.isRevealed) {
          cells[y * width + x] = c.isMine ? -1 : c.adjacentMines;
        } else if (c.isFlagged) {
          final by = c.flaggedBy;
          if (by != null) flags.add(FlagEntry(x: x, y: y, by: by));
        }
      }
    }
    final token = _playerToken[logicalId];
    transport.sendToGuest(
      transportId,
      SSnapshot(
        cells: cells,
        flags: flags,
        hearts: e.hearts,
        stats: e.stats,
        heartsLostBy: e.heartsLostBy,
        rejoinToken: token,
      ),
    );
  }

  void _checkGameEnd() {
    final e = _engine;
    if (e == null) return;
    if (e.status == GameStatus.won || e.status == GameStatus.lost) {
      _finalizeFlagAccuracy(e);
      _broadcast(SGameOver(
        won: e.status == GameStatus.won,
        losingPlayerId: e.losingPlayerId,
        minePositions: e.board.minePositions(),
        stats: e.stats,
        startedAtMs: e.startedAt?.millisecondsSinceEpoch ?? 0,
        endedAtMs: e.endedAt?.millisecondsSinceEpoch ?? 0,
      ));
    }
  }

  /// Walks the final board state and credits each player's `correctFlags` /
  /// `incorrectFlags`. Computed at game-end (not per toggle) so first-click
  /// safe-zone mine placement and flag toggling don't desync the count.
  void _finalizeFlagAccuracy(GameEngine e) {
    final stats = e.stats;
    for (final s in stats.values) {
      s.correctFlags = 0;
      s.incorrectFlags = 0;
    }
    final board = e.board;
    for (var y = 0; y < board.height; y++) {
      for (var x = 0; x < board.width; x++) {
        final c = board.cellAt(x, y);
        if (!c.isFlagged) continue;
        final pid = c.flaggedBy;
        if (pid == null) continue;
        final s = stats[pid];
        if (s == null) continue;
        if (c.isMine) {
          s.correctFlags++;
        } else {
          s.incorrectFlags++;
        }
      }
    }
  }

  void _broadcast(ServerMessage msg, {String? excludePlayerId}) {
    transport.broadcast(msg, excludePlayerId: excludePlayerId);
    _localCtrl.add(msg);
  }

  void _sendTo(String logicalId, ServerMessage msg) {
    if (logicalId == hostId) {
      _localCtrl.add(msg);
      return;
    }
    final transportId = _logicalToTransport[logicalId];
    if (transportId == null) return; // offline; will catch up via SSnapshot
    transport.sendToGuest(transportId, msg);
  }

  void _broadcastLobby() {
    final lobby = SLobby(
      hostId: hostId,
      players: _players.values.toList(),
      status: _engine?.status ?? GameStatus.waiting,
      config: config,
      hearts: _engine?.hearts ?? config.initialHearts,
    );
    _broadcast(lobby);
  }

  static const _palette = <int>[
    0xFF6750A4,
    0xFF03A9F4,
    0xFFE91E63,
    0xFFFFB300,
    0xFF43A047,
    0xFFE53935,
  ];

  int _colorFor(int idx) => _palette[idx % _palette.length];
}
