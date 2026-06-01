import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ids.dart';
import '../game/board.dart';
import '../game/difficulty.dart';
import '../game/engine.dart';
import '../net/client.dart';
import '../net/discovery.dart';
import '../net/local_ip.dart';
import '../net/messages.dart';
import '../net/relay_transport.dart';
import '../net/server.dart';
import '../net/transport.dart';
import 'chat.dart';
import 'host_session.dart';

/// All UI-facing game state derived from server messages.
class GameSnapshot {
  GameSnapshot({
    required this.config,
    required this.hostId,
    required this.players,
    required this.status,
    required this.cells,
    required this.flags,
    required this.questions,
    required this.lastEvent,
    required this.cursors,
    required this.minePositions,
    required this.losingPlayerId,
    required this.stats,
    required this.hearts,
    this.heartsLostBy = const [],
    this.explodedMines = const {},
    this.lastExplosion,
    this.startedAtMs = 0,
    this.endedAtMs = 0,
  });

  final GameConfig config;
  final String hostId;
  final List<PlayerInfo> players;
  final GameStatus status;

  /// width * height entries: -2 hidden, -1 mine, 0..8 number.
  final List<int> cells;

  /// width * height entries: playerId of flag, or null.
  final List<String?> flags;

  /// width * height entries: playerId of "?" mark, or null. Mutually
  /// exclusive with [flags] per cell — flag → question → none is the cycle.
  final List<String?> questions;

  /// Last (x,y) flash for animations, or null.
  final ({int x, int y, String byPlayer})? lastEvent;

  /// Normalized cursor positions by playerId.
  final Map<String, ({double nx, double ny})> cursors;

  final List<List<int>> minePositions;
  final String? losingPlayerId;
  final Map<String, PlayerStats> stats;

  /// Hearts remaining in Hearts mode. In Classic mode this equals 1 while
  /// playing and 0 after a loss.
  final int hearts;

  /// Chronological list of player ids who lost each heart in Hearts mode.
  /// `length == initialHearts - hearts`; index 0 is the first heart lost.
  final List<String> heartsLostBy;

  /// Cell indices (`y * width + x`) of mines that were detonated *during play*
  /// — i.e. revealed via SRevealed, not via SGameOver's reveal-all. Used on
  /// the win screen to distinguish "mines you blew up" (dark red) from "mines
  /// you correctly flagged" (green).
  final Set<int> explodedMines;

  /// Most recent chain-explosion event for animation.
  final ({int x, int y, List<List<int>> centers, int id})? lastExplosion;

  /// Epoch-ms when the active game started. 0 until the host broadcasts the
  /// final SGameOver carrying authoritative timing.
  final int startedAtMs;

  /// Epoch-ms when the game ended. 0 while still playing.
  final int endedAtMs;

  /// Total match duration in ms (0 until game ends).
  int get durationMs =>
      (endedAtMs > 0 && startedAtMs > 0) ? endedAtMs - startedAtMs : 0;

  GameMode get mode => config.mode;
  int get initialHearts => config.initialHearts;

  int get width => config.width;
  int get height => config.height;

  int cellAt(int x, int y) => cells[y * width + x];
  String? flagAt(int x, int y) => flags[y * width + x];
  String? questionAt(int x, int y) => questions[y * width + x];

  PlayerInfo? playerById(String? id) {
    if (id == null) return null;
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  int flagsPlaced() {
    var n = 0;
    for (final f in flags) {
      if (f != null) n++;
    }
    return n;
  }

  GameSnapshot copyWith({
    GameConfig? config,
    String? hostId,
    List<PlayerInfo>? players,
    GameStatus? status,
    List<int>? cells,
    List<String?>? flags,
    List<String?>? questions,
    ({int x, int y, String byPlayer})? lastEvent,
    bool clearLastEvent = false,
    Map<String, ({double nx, double ny})>? cursors,
    List<List<int>>? minePositions,
    String? losingPlayerId,
    Map<String, PlayerStats>? stats,
    int? hearts,
    List<String>? heartsLostBy,
    Set<int>? explodedMines,
    ({int x, int y, List<List<int>> centers, int id})? lastExplosion,
    bool clearLastExplosion = false,
    int? startedAtMs,
    int? endedAtMs,
  }) =>
      GameSnapshot(
        config: config ?? this.config,
        hostId: hostId ?? this.hostId,
        players: players ?? this.players,
        status: status ?? this.status,
        cells: cells ?? this.cells,
        flags: flags ?? this.flags,
        questions: questions ?? this.questions,
        lastEvent: clearLastEvent ? null : (lastEvent ?? this.lastEvent),
        cursors: cursors ?? this.cursors,
        minePositions: minePositions ?? this.minePositions,
        losingPlayerId: losingPlayerId ?? this.losingPlayerId,
        stats: stats ?? this.stats,
        hearts: hearts ?? this.hearts,
        heartsLostBy: heartsLostBy ?? this.heartsLostBy,
        explodedMines: explodedMines ?? this.explodedMines,
        lastExplosion:
            clearLastExplosion ? null : (lastExplosion ?? this.lastExplosion),
        startedAtMs: startedAtMs ?? this.startedAtMs,
        endedAtMs: endedAtMs ?? this.endedAtMs,
      );
}

enum HostMode { lan, online }
enum JoinMode { lan, online }

/// Captures everything about the current play session: am I host or guest,
/// who's connected, and the latest game state.
class SessionState {
  SessionState({
    required this.config,
    required this.isHost,
    required this.localId,
    required this.snapshot,
    required this.connectionState,
    required this.errorMessage,
    required this.hostUrls,
    required this.hostPort,
    required this.roomCode,
  });

  factory SessionState.idle() => SessionState(
        config: GameConfig.fromDifficulty(Difficulty.easy),
        isHost: false,
        localId: '',
        snapshot: null,
        connectionState: SessionConnState.idle,
        errorMessage: null,
        hostUrls: const [],
        hostPort: 0,
        roomCode: null,
      );

  final GameConfig config;
  final bool isHost;
  final String localId;
  final GameSnapshot? snapshot;
  final SessionConnState connectionState;
  final String? errorMessage;

  /// For LAN host: URLs derived from local IPs (for QR / manual entry).
  final List<String> hostUrls;
  final int hostPort;

  /// For online host: short room code to share with friends.
  final String? roomCode;

  SessionState copyWith({
    GameConfig? config,
    bool? isHost,
    String? localId,
    GameSnapshot? snapshot,
    SessionConnState? connectionState,
    String? errorMessage,
    List<String>? hostUrls,
    int? hostPort,
    String? roomCode,
    bool clearSnapshot = false,
    bool clearError = false,
    bool clearRoomCode = false,
  }) =>
      SessionState(
        config: config ?? this.config,
        isHost: isHost ?? this.isHost,
        localId: localId ?? this.localId,
        snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
        connectionState: connectionState ?? this.connectionState,
        errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
        hostUrls: hostUrls ?? this.hostUrls,
        hostPort: hostPort ?? this.hostPort,
        roomCode: clearRoomCode ? null : (roomCode ?? this.roomCode),
      );
}

enum SessionConnState {
  idle,
  connecting,
  lobby,
  playing,
  ended,
  reconnecting,
  disconnected,
}

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

class _SessionLifecycleObserver extends WidgetsBindingObserver {
  _SessionLifecycleObserver(this.onResume);
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

class SessionNotifier extends Notifier<SessionState> {
  HostSession? _host;
  GuestTransport? _guest;
  DiscoveryAdvertiser? _advertiser;
  StreamSubscription? _guestSub;
  StreamSubscription? _hostLocalSub;

  // ─── Reconnect bookkeeping (guest side) ─────────────────────────────────
  // Set once on first joinHost(); carried verbatim across reconnect attempts
  // so the host can recognize this as the same player via [_rejoinToken] and
  // restore their slot/stats inside its grace window.
  String? _joinName;
  String? _joinAvatarSeed;
  JoinMode? _joinMode;
  Uri? _joinLanUri;
  String? _joinRoomCode;
  String? _rejoinToken;
  int _reconnectAttempt = 0;
  Timer? _reconnectTimer;
  static const _reconnectBackoffSecs = <int>[1, 2, 4, 8, 8, 8];

  @override
  SessionState build() {
    final observer = _SessionLifecycleObserver(_onAppResumed);
    WidgetsBinding.instance.addObserver(observer);
    ref.onDispose(() async {
      WidgetsBinding.instance.removeObserver(observer);
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      await _guestSub?.cancel();
      await _hostLocalSub?.cancel();
      await _guest?.close();
      await _advertiser?.stop();
      await _host?.stop();
    });
    return SessionState.idle();
  }

  /// Called when the OS reports the app has come back to the foreground.
  /// On mobile this is the typical "woke up from sleep" signal — if we were
  /// in a reconnect backoff we cut the wait short and try right now, and if
  /// we had given up (disconnected) we restart the loop from attempt 0.
  void _onAppResumed() {
    if (_joinMode == null) return;
    final cs = state.connectionState;
    if (cs == SessionConnState.reconnecting) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _attemptConnect(isFirst: false);
    } else if (cs == SessionConnState.disconnected) {
      _reconnectAttempt = 0;
      _attemptConnect(isFirst: false);
    }
  }

  // ─── Hosting ───────────────────────────────────────────────────────────────

  Future<void> startHost({
    required String name,
    required String avatarSeed,
    Difficulty difficulty = Difficulty.easy,
    HostMode mode = HostMode.lan,
  }) async {
    ref.read(chatProvider.notifier).clear();
    state = state.copyWith(
      isHost: true,
      connectionState: SessionConnState.connecting,
      clearError: true,
      clearRoomCode: true,
    );

    final cfg = GameConfig.fromDifficulty(difficulty);
    final HostTransport transport = switch (mode) {
      HostMode.lan => LanHostTransport(),
      HostMode.online => RelayHostTransport(),
    };
    final session = HostSession(
      hostName: name,
      hostAvatarSeed: avatarSeed,
      config: cfg,
      transport: transport,
    );

    _hostLocalSub = session.localEvents.listen(_handleServerMessage);

    final HostJoinInfo info;
    try {
      info = await session.start();
    } catch (e) {
      await session.stop();
      await _hostLocalSub?.cancel();
      _hostLocalSub = null;
      state = state.copyWith(
        connectionState: SessionConnState.idle,
        errorMessage: e is RelayJoinException
            ? e.userMessage
            : 'Failed to start host: $e',
      );
      return;
    }
    _host = session;

    final urls = <String>[];
    var port = 0;
    String? roomCode;
    if (info.kind == HostJoinKind.lan) {
      port = info.lanPort ?? 0;
      final ips = await getLocalIPv4Addresses();
      for (final ip in ips) {
        urls.add('ws://$ip:$port');
      }
      _advertiser = DiscoveryAdvertiser(
        serviceName: 'Minesweeper-${name.isEmpty ? 'Host' : name}',
        port: port,
      );
      unawaited(_advertiser!.start());
    } else {
      roomCode = info.roomCode;
    }

    state = state.copyWith(
      localId: session.hostId,
      config: cfg,
      hostUrls: urls,
      hostPort: port,
      roomCode: roomCode,
      connectionState: SessionConnState.lobby,
    );
    // Re-broadcast lobby so this subscriber sees the initial state.
    session.broadcastLobby();
  }

  void hostStartGame() {
    final s = _host;
    if (s == null) return;
    s.onLocalIntent(CStartGame(config: state.config));
  }

  void setDifficulty(Difficulty d) => setConfig(GameConfig.fromDifficulty(d));

  void setConfig(GameConfig cfg) {
    state = state.copyWith(config: cfg);
    _host?.setConfig(cfg);
  }

  // ─── Joining ───────────────────────────────────────────────────────────────

  Future<void> joinHost({
    required String name,
    required String avatarSeed,
    JoinMode mode = JoinMode.lan,
    Uri? lanUri,
    String? roomCode,
  }) async {
    // Validate params before mutating state or stashing them for reconnect.
    if (mode == JoinMode.lan && lanUri == null) {
      state = state.copyWith(
        connectionState: SessionConnState.idle,
        errorMessage: 'Missing LAN address',
      );
      return;
    }
    String? normalizedRoomCode;
    if (mode == JoinMode.online) {
      normalizedRoomCode = (roomCode ?? '')
          .toUpperCase()
          .replaceAll(RegExp(r'[^0-9A-Z]'), '');
      if (normalizedRoomCode.isEmpty) {
        state = state.copyWith(
          connectionState: SessionConnState.idle,
          errorMessage: 'Enter a room code',
        );
        return;
      }
    }

    ref.read(chatProvider.notifier).clear();
    _joinName = name;
    _joinAvatarSeed = avatarSeed;
    _joinMode = mode;
    _joinLanUri = lanUri;
    _joinRoomCode = normalizedRoomCode;
    _rejoinToken = shortId(20);
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _attemptConnect(isFirst: true);
  }

  /// Builds a fresh [GuestTransport] from the saved join params and attaches
  /// the session's event listener. Used both for the initial join and for
  /// every reconnect attempt — the only externally visible difference is the
  /// connection-state value while in flight.
  Future<void> _attemptConnect({required bool isFirst}) async {
    final mode = _joinMode;
    final name = _joinName;
    final avatarSeed = _joinAvatarSeed;
    if (mode == null || name == null || avatarSeed == null) return;

    // Reset any prior transport before we open a new one.
    await _guestSub?.cancel();
    _guestSub = null;
    await _guest?.close();
    _guest = null;

    state = state.copyWith(
      isHost: false,
      connectionState: isFirst
          ? SessionConnState.connecting
          : SessionConnState.reconnecting,
      clearError: true,
    );

    final GuestTransport transport;
    switch (mode) {
      case JoinMode.lan:
        transport = LanGuestTransport(_joinLanUri!);
      case JoinMode.online:
        transport = RelayGuestTransport(roomCode: _joinRoomCode!);
    }

    try {
      await transport.connect();
      _guest = transport;
      transport.send(CJoin(
        name: name,
        avatarSeed: avatarSeed,
        rejoinToken: _rejoinToken,
      ));
      // Cleared once the join is acknowledged so the next drop starts at 1s.
      _reconnectAttempt = 0;
      _guestSub = transport.events.listen(
        _handleServerMessage,
        onError: (e) => _handleTransportDown(_friendlyConnectError(e, mode)),
        onDone: () => _handleTransportDown(null),
      );
    } catch (e) {
      try {
        await transport.close();
      } catch (_) {}
      if (isFirst) {
        // First attempt failed before the session was ever established —
        // surface the error to the UI and reset rather than retrying silently.
        _clearReconnectState();
        state = state.copyWith(
          connectionState: SessionConnState.idle,
          errorMessage: _friendlyConnectError(e, mode),
        );
      } else {
        _scheduleReconnect();
      }
    }
  }

  /// Maps the raw exception from a failed connect attempt into a message that
  /// tells the user what to do next. The default `SocketException.toString()`
  /// includes scary fragments like `errno = 13` that aren't actionable.
  String _friendlyConnectError(Object e, JoinMode mode) {
    if (e is RelayJoinException) return e.userMessage;
    final raw = e.toString();
    final lower = raw.toLowerCase();
    // Android returns EACCES on connect() when a VPN, captive portal, or AP
    // isolation blocks the LAN socket. The OS-level INTERNET permission is
    // unrelated; surfacing the OS error verbatim is misleading.
    if (lower.contains('permission denied') || lower.contains('errno = 13')) {
      return mode == JoinMode.lan
          ? "Can't reach the host on this network.\n\n"
              "• Make sure both devices are on the same Wi-Fi (not cellular).\n"
              "• Turn off any VPN on this device.\n"
              "• Some Wi-Fi networks (public, guest, work) block device-to-device "
              "connections. Try a home network or a phone hotspot."
          : "The network is blocking the connection. Turn off any VPN, or try a different Wi-Fi.";
    }
    if (lower.contains('network is unreachable') ||
        lower.contains('no route to host') ||
        lower.contains('errno = 101') ||
        lower.contains('errno = 113')) {
      return mode == JoinMode.lan
          ? "Host isn't reachable. Make sure both devices are on the same Wi-Fi network."
          : "Network unreachable — check your internet connection.";
    }
    if (lower.contains('connection refused') || lower.contains('errno = 111')) {
      return mode == JoinMode.lan
          ? 'Host is not accepting connections. Ask them to restart the lobby and try again.'
          : "Couldn't reach the relay. Try again in a moment.";
    }
    if (lower.contains('timed out') || lower.contains('timeout')) {
      return mode == JoinMode.lan
          ? "Host didn't respond. Check that both devices are on the same Wi-Fi and the host is still in the lobby."
          : 'Connection timed out — check your internet and try again.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('no address associated')) {
      return mode == JoinMode.lan
          ? "Couldn't resolve the host address — double-check the LAN URL."
          : "Couldn't resolve the relay address — check your internet.";
    }
    return 'Failed to connect. Check your network and try again.';
  }

  void _handleTransportDown(String? errMsg) {
    // Don't fight the user's explicit leave().
    if (_joinMode == null) return;
    // If the game already wrapped up on the host side, treat the close as
    // expected and don't try to reconnect into a finished session.
    if (state.connectionState == SessionConnState.ended) return;

    state = state.copyWith(
      connectionState: SessionConnState.reconnecting,
      errorMessage: errMsg,
    );
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_joinMode == null) return;
    if (_reconnectAttempt >= _reconnectBackoffSecs.length) {
      _clearReconnectState();
      state = state.copyWith(
        connectionState: SessionConnState.disconnected,
        errorMessage: state.errorMessage ??
            'Could not reconnect — check your network and rejoin.',
      );
      return;
    }
    final delaySecs = _reconnectBackoffSecs[_reconnectAttempt];
    _reconnectAttempt++;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySecs), () {
      _reconnectTimer = null;
      _attemptConnect(isFirst: false);
    });
  }

  void _clearReconnectState() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempt = 0;
    _joinName = null;
    _joinAvatarSeed = null;
    _joinMode = null;
    _joinLanUri = null;
    _joinRoomCode = null;
    _rejoinToken = null;
  }

  // ─── Common: send intents ──────────────────────────────────────────────────

  void sendReveal(int x, int y) => _send(CReveal(x: x, y: y));
  void sendFlag(int x, int y) => _send(CFlag(x: x, y: y));
  void sendChord(int x, int y) => _send(CChord(x: x, y: y));
  void sendCursor(double nx, double ny) => _send(CCursor(nx: nx, ny: ny));
  void clearCursor() => _send(const CCursorLeave());
  void sendEmoji(String code) => _send(CEmoji(code: code));
  void sendChat(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    _send(CChat(text: t));
  }
  void sendReady(bool ready) => _send(CReady(ready: ready));
  void sendRestart() => _send(const CRestart());

  void _send(ClientMessage msg) {
    final h = _host;
    if (h != null) {
      h.onLocalIntent(msg);
      return;
    }
    _guest?.send(msg);
  }

  // ─── Outbound disconnect ───────────────────────────────────────────────────

  Future<void> leave() async {
    _clearReconnectState();
    ref.read(chatProvider.notifier).clear();
    await _guestSub?.cancel();
    _guestSub = null;
    await _hostLocalSub?.cancel();
    _hostLocalSub = null;
    await _guest?.close();
    _guest = null;
    await _advertiser?.stop();
    _advertiser = null;
    await _host?.stop();
    _host = null;
    state = SessionState.idle();
  }

  // ─── Apply server messages to snapshot ─────────────────────────────────────

  void _handleServerMessage(ServerMessage msg) {
    final snap = state.snapshot;
    switch (msg) {
      case SWelcome(:final yourId):
        state = state.copyWith(localId: yourId);
      case SLobby(
          :final players,
          :final hostId,
          :final status,
          :final config,
          :final hearts
        ):
        // Preserve existing reveals/flags if game is in progress. A stale
        // `waiting` lobby that arrives during play (e.g. right after
        // SGameStarted, before the engine has registered the first reveal)
        // must not tear down the active match — only let SLobby move us out
        // of `playing` when it explicitly signals a finished game.
        final inGame = snap != null &&
            snap.config.width == config.width &&
            snap.config.height == config.height &&
            (snap.status == GameStatus.playing ||
                status == GameStatus.playing);
        if (inGame) {
          final effectiveStatus =
              (status == GameStatus.won || status == GameStatus.lost)
                  ? status
                  : GameStatus.playing;
          state = state.copyWith(
            config: config,
            snapshot: snap.copyWith(
              config: config,
              hostId: hostId,
              players: players,
              status: effectiveStatus,
              hearts: hearts,
            ),
            connectionState: _stateFromStatus(effectiveStatus),
          );
        } else {
          final empty = _emptySnapshot(config, hostId, players, status,
              hearts: hearts > 0 ? hearts : config.initialHearts);
          state = state.copyWith(
            config: config,
            snapshot: empty,
            connectionState: _stateFromStatus(status),
          );
        }
      case SGameStarted(:final config):
        final hostId = snap?.hostId ?? '';
        final players = snap?.players ?? const <PlayerInfo>[];
        state = state.copyWith(
          config: config,
          snapshot: _emptySnapshot(
            config,
            hostId,
            players,
            GameStatus.playing,
            hearts: config.initialHearts,
          ),
          connectionState: SessionConnState.playing,
        );
      case SRevealed(:final cells, :final byPlayerId):
        if (snap == null) return;
        final newCells = List<int>.from(snap.cells);
        final newFlags = List<String?>.from(snap.flags);
        final newQuestions = List<String?>.from(snap.questions);
        Set<int>? newExploded;
        for (final r in cells) {
          final idx = r.y * snap.width + r.x;
          newCells[idx] = r.value;
          newFlags[idx] = null;
          newQuestions[idx] = null;
          if (r.value == -1) {
            newExploded ??= Set<int>.from(snap.explodedMines);
            newExploded.add(idx);
          }
        }
        final last = cells.isNotEmpty
            ? (x: cells.last.x, y: cells.last.y, byPlayer: byPlayerId)
            : snap.lastEvent;
        state = state.copyWith(
          snapshot: snap.copyWith(
            cells: newCells,
            flags: newFlags,
            questions: newQuestions,
            explodedMines: newExploded ?? snap.explodedMines,
            lastEvent: last,
          ),
        );
      case SFlagged(:final x, :final y, :final mark, :final byPlayerId):
        if (snap == null) return;
        final idx = y * snap.width + x;
        final newFlags = List<String?>.from(snap.flags);
        final newQuestions = List<String?>.from(snap.questions);
        newFlags[idx] = mark == CellMark.flag ? byPlayerId : null;
        newQuestions[idx] = mark == CellMark.question ? byPlayerId : null;
        state = state.copyWith(
          snapshot: snap.copyWith(
            flags: newFlags,
            questions: newQuestions,
            lastEvent: (x: x, y: y, byPlayer: byPlayerId),
          ),
        );
      case SGameOver(
          :final won,
          :final losingPlayerId,
          :final minePositions,
          :final stats,
          :final startedAtMs,
          :final endedAtMs,
        ):
        if (snap == null) return;
        final newCells = List<int>.from(snap.cells);
        for (final p in minePositions) {
          final idx = p[1] * snap.width + p[0];
          newCells[idx] = -1;
        }
        state = state.copyWith(
          snapshot: snap.copyWith(
            status: won ? GameStatus.won : GameStatus.lost,
            cells: newCells,
            minePositions: minePositions,
            losingPlayerId: losingPlayerId,
            stats: stats,
            startedAtMs: startedAtMs,
            endedAtMs: endedAtMs,
          ),
          connectionState: SessionConnState.ended,
        );
      case SHeartsChanged(
          :final hearts,
          :final byPlayerId,
          :final x,
          :final y,
          :final explosionCenters
        ):
        if (snap == null) return;
        state = state.copyWith(
          snapshot: snap.copyWith(
            hearts: hearts,
            heartsLostBy: [...snap.heartsLostBy, byPlayerId],
            lastExplosion: (
              x: x,
              y: y,
              centers: explosionCenters,
              id: DateTime.now().microsecondsSinceEpoch,
            ),
            lastEvent: (x: x, y: y, byPlayer: byPlayerId),
          ),
        );
      case SPlayerPatch(
          :final playerId,
          :final isReady,
          :final isOffline,
          :final name
        ):
        if (snap == null) return;
        var changed = false;
        final newPlayers = <PlayerInfo>[];
        for (final p in snap.players) {
          if (p.id != playerId) {
            newPlayers.add(p);
            continue;
          }
          changed = true;
          newPlayers.add(p.copyWith(
            isReady: isReady,
            isOffline: isOffline,
            name: name,
          ));
        }
        if (!changed) return;
        state = state.copyWith(snapshot: snap.copyWith(players: newPlayers));
      case SCursor(:final playerId, :final nx, :final ny):
        if (snap == null) return;
        if (playerId == state.localId) return;
        final newCursors =
            Map<String, ({double nx, double ny})>.from(snap.cursors);
        newCursors[playerId] = (nx: nx, ny: ny);
        state = state.copyWith(snapshot: snap.copyWith(cursors: newCursors));
      case SCursorLeave(:final playerId):
        if (snap == null) return;
        if (playerId == state.localId) return;
        if (!snap.cursors.containsKey(playerId)) return;
        final newCursors =
            Map<String, ({double nx, double ny})>.from(snap.cursors);
        newCursors.remove(playerId);
        state = state.copyWith(snapshot: snap.copyWith(cursors: newCursors));
      case SEmoji(:final playerId, :final code):
        ref.read(emojiBurstProvider.notifier).push(playerId, code);
      case SChat(:final playerId, :final name, :final text, :final ts):
        ref.read(chatProvider.notifier).receive(
              playerId: playerId,
              name: name,
              text: text,
              ts: ts,
              mine: playerId == state.localId,
            );
      case SError(:final message):
        state = state.copyWith(errorMessage: message);
      case SPong():
        // Heartbeat ack is normally filtered inside the guest transport, but
        // a stray pong over LAN would still need a no-op case so the
        // exhaustive switch keeps compiling.
        return;
      case SUnknown():
        // A message type this build doesn't recognize (newer host). Ignore.
        return;
      case SSnapshot(
          :final cells,
          :final flags,
          :final hearts,
          :final stats,
          :final heartsLostBy,
          :final rejoinToken,
        ):
        if (snap == null) return;
        if (rejoinToken != null) _rejoinToken = rejoinToken;
        final newCells = List<int>.filled(snap.width * snap.height, -2);
        final width = snap.width;
        // Sized snapshots from the host always match the lobby config we
        // were just told about; if not we conservatively skip the cell wipe.
        final newExploded = <int>{};
        if (cells.length == newCells.length) {
          for (var i = 0; i < cells.length; i++) {
            newCells[i] = cells[i];
            if (cells[i] == -1) newExploded.add(i);
          }
        }
        final newFlags = List<String?>.filled(snap.width * snap.height, null);
        for (final f in flags) {
          final idx = f.y * width + f.x;
          if (idx >= 0 && idx < newFlags.length) {
            newFlags[idx] = f.by;
          }
        }
        state = state.copyWith(
          snapshot: snap.copyWith(
            cells: newCells,
            flags: newFlags,
            hearts: hearts,
            stats: stats,
            heartsLostBy: heartsLostBy,
            explodedMines: newExploded,
          ),
          connectionState: SessionConnState.playing,
        );
      case SHostAway():
        // Host dropped its socket but the relay is holding the room open
        // inside its grace window. Keep our snapshot intact, just surface a
        // "reconnecting" badge so the UI explains why moves aren't landing.
        state = state.copyWith(
          connectionState: SessionConnState.reconnecting,
        );
      case SHostBack():
        // Host reclaimed. For the host's own UI, restore the connection
        // state based on whether a game is in progress so the
        // "reconnecting" banner clears immediately. For a guest, re-send
        // CJoin with the saved rejoin token — the host fast-paths it back
        // into the existing PlayerInfo slot and replies with a fresh
        // SSnapshot, which will tip state back to `playing` on its own.
        final restored = state.snapshot?.status == GameStatus.playing
            ? SessionConnState.playing
            : SessionConnState.lobby;
        state = state.copyWith(connectionState: restored);
        final token = _rejoinToken;
        final name = _joinName;
        final avatarSeed = _joinAvatarSeed;
        if (name != null && avatarSeed != null) {
          _guest?.send(CJoin(
            name: name,
            avatarSeed: avatarSeed,
            rejoinToken: token,
          ));
        }
    }
  }

  GameSnapshot _emptySnapshot(
    GameConfig cfg,
    String hostId,
    List<PlayerInfo> players,
    GameStatus status, {
    int? hearts,
  }) =>
      GameSnapshot(
        config: cfg,
        hostId: hostId,
        players: players,
        status: status,
        cells: List<int>.filled(cfg.width * cfg.height, -2),
        flags: List<String?>.filled(cfg.width * cfg.height, null),
        questions: List<String?>.filled(cfg.width * cfg.height, null),
        lastEvent: null,
        cursors: const {},
        minePositions: const [],
        losingPlayerId: null,
        stats: const {},
        hearts: hearts ?? cfg.initialHearts,
      );

  SessionConnState _stateFromStatus(GameStatus status) => switch (status) {
        GameStatus.waiting => SessionConnState.lobby,
        GameStatus.playing => SessionConnState.playing,
        GameStatus.won || GameStatus.lost => SessionConnState.ended,
      };
}

/// Transient stream of emoji bursts (consumed by the UI).
class EmojiBurst {
  EmojiBurst(this.playerId, this.code) : id = _rand.nextInt(1 << 31);
  static final _rand = Random();
  final int id;
  final String playerId;
  final String code;
}

final emojiBurstProvider =
    NotifierProvider<EmojiBurstNotifier, List<EmojiBurst>>(
        EmojiBurstNotifier.new);

class EmojiBurstNotifier extends Notifier<List<EmojiBurst>> {
  @override
  List<EmojiBurst> build() => const [];

  void push(String playerId, String code) {
    final burst = EmojiBurst(playerId, code);
    state = [...state, burst];
    Future.delayed(const Duration(seconds: 2), () {
      state = state.where((b) => b.id != burst.id).toList();
    });
  }
}

/// Discovery results stream for the join screen.
final discoveryProvider =
    NotifierProvider<DiscoveryNotifier, List<DiscoveredHost>>(
        DiscoveryNotifier.new);

class DiscoveryNotifier extends Notifier<List<DiscoveredHost>> {
  DiscoveryBrowser? _browser;
  StreamSubscription? _sub;

  @override
  List<DiscoveredHost> build() {
    ref.onDispose(stop);
    return const [];
  }

  Future<void> start() async {
    if (_browser != null) return;
    final b = DiscoveryBrowser();
    _browser = b;
    await b.start();
    _sub = b.hosts.listen((list) {
      state = list;
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _browser?.stop();
    _browser = null;
  }
}

/// Persists the player's preferred name (volatile for v1; kept on
/// session-level only).
final localProfileProvider =
    NotifierProvider<LocalProfileNotifier, LocalProfile>(
        LocalProfileNotifier.new);

class LocalProfile {
  const LocalProfile({required this.name, required this.avatarSeed});
  final String name;
  final String avatarSeed;
}

class LocalProfileNotifier extends Notifier<LocalProfile> {
  @override
  LocalProfile build() {
    return LocalProfile(name: 'Player', avatarSeed: shortId(6));
  }

  void setName(String name) =>
      state = LocalProfile(name: name, avatarSeed: state.avatarSeed);
}
