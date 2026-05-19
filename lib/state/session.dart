import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ids.dart';
import '../game/difficulty.dart';
import '../game/engine.dart';
import '../net/client.dart';
import '../net/discovery.dart';
import '../net/local_ip.dart';
import '../net/messages.dart';
import '../net/server.dart';

/// All UI-facing game state derived from server messages.
class GameSnapshot {
  GameSnapshot({
    required this.config,
    required this.hostId,
    required this.players,
    required this.status,
    required this.cells,
    required this.flags,
    required this.lastEvent,
    required this.cursors,
    required this.minePositions,
    required this.losingPlayerId,
    required this.stats,
    required this.hearts,
    this.lastExplosion,
  });

  final GameConfig config;
  final String hostId;
  final List<PlayerInfo> players;
  final GameStatus status;

  /// width * height entries: -2 hidden, -1 mine, 0..8 number.
  final List<int> cells;

  /// width * height entries: playerId of flag, or null.
  final List<String?> flags;

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

  /// Most recent chain-explosion event for animation.
  final ({int x, int y, List<List<int>> centers, int id})? lastExplosion;

  GameMode get mode => config.mode;
  int get initialHearts => config.initialHearts;

  int get width => config.width;
  int get height => config.height;

  int cellAt(int x, int y) => cells[y * width + x];
  String? flagAt(int x, int y) => flags[y * width + x];

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
    ({int x, int y, String byPlayer})? lastEvent,
    bool clearLastEvent = false,
    Map<String, ({double nx, double ny})>? cursors,
    List<List<int>>? minePositions,
    String? losingPlayerId,
    Map<String, PlayerStats>? stats,
    int? hearts,
    ({int x, int y, List<List<int>> centers, int id})? lastExplosion,
    bool clearLastExplosion = false,
  }) =>
      GameSnapshot(
        config: config ?? this.config,
        hostId: hostId ?? this.hostId,
        players: players ?? this.players,
        status: status ?? this.status,
        cells: cells ?? this.cells,
        flags: flags ?? this.flags,
        lastEvent: clearLastEvent ? null : (lastEvent ?? this.lastEvent),
        cursors: cursors ?? this.cursors,
        minePositions: minePositions ?? this.minePositions,
        losingPlayerId: losingPlayerId ?? this.losingPlayerId,
        stats: stats ?? this.stats,
        hearts: hearts ?? this.hearts,
        lastExplosion:
            clearLastExplosion ? null : (lastExplosion ?? this.lastExplosion),
      );
}

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
      );

  final GameConfig config;
  final bool isHost;
  final String localId;
  final GameSnapshot? snapshot;
  final SessionConnState connectionState;
  final String? errorMessage;

  /// For host: URLs derived from local IPs (for QR / manual entry).
  final List<String> hostUrls;
  final int hostPort;

  SessionState copyWith({
    GameConfig? config,
    bool? isHost,
    String? localId,
    GameSnapshot? snapshot,
    SessionConnState? connectionState,
    String? errorMessage,
    List<String>? hostUrls,
    int? hostPort,
    bool clearSnapshot = false,
    bool clearError = false,
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
      );
}

enum SessionConnState { idle, connecting, lobby, playing, ended, disconnected }

final sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

class SessionNotifier extends Notifier<SessionState> {
  LanGameServer? _server;
  LanGameClient? _client;
  DiscoveryAdvertiser? _advertiser;
  StreamSubscription? _msgSub;
  StreamSubscription? _serverEventSub;

  @override
  SessionState build() {
    ref.onDispose(() async {
      await _msgSub?.cancel();
      await _serverEventSub?.cancel();
      await _client?.close();
      await _advertiser?.stop();
      await _server?.stop();
    });
    return SessionState.idle();
  }

  // ─── Hosting ───────────────────────────────────────────────────────────────

  Future<void> startHost({
    required String name,
    required String avatarSeed,
    Difficulty difficulty = Difficulty.easy,
  }) async {
    state = state.copyWith(
      isHost: true,
      connectionState: SessionConnState.connecting,
      clearError: true,
    );

    final cfg = GameConfig.fromDifficulty(difficulty);
    final server = LanGameServer(
      hostName: name,
      hostAvatarSeed: avatarSeed,
      config: cfg,
    );
    try {
      await server.start();
    } catch (e) {
      state = state.copyWith(
        connectionState: SessionConnState.idle,
        errorMessage: 'Failed to start host: $e',
      );
      return;
    }
    _server = server;

    final urls = <String>[];
    final ips = await getLocalIPv4Addresses();
    for (final ip in ips) {
      urls.add('ws://$ip:${server.port}');
    }

    _advertiser = DiscoveryAdvertiser(
      serviceName: 'Minesweeper-${name.isEmpty ? 'Host' : name}',
      port: server.port,
    );
    unawaited(_advertiser!.start());

    state = state.copyWith(
      localId: server.hostId,
      config: cfg,
      hostUrls: urls,
      hostPort: server.port,
      connectionState: SessionConnState.lobby,
    );

    _serverEventSub =
        server.events.listen((e) => _handleServerMessage(e.message));
    // The initial broadcast inside server.start() happened before we
    // subscribed; re-broadcast now so this client receives its own lobby.
    server.broadcastLobby();
  }

  void hostStartGame() {
    final s = _server;
    if (s == null) return;
    s.onLocalIntent(CStartGame(config: state.config));
  }

  void setDifficulty(Difficulty d) => setConfig(GameConfig.fromDifficulty(d));

  void setConfig(GameConfig cfg) {
    state = state.copyWith(config: cfg);
    final s = _server;
    if (s != null) {
      s.config = cfg;
      s.broadcastLobby();
    }
  }

  // ─── Joining ───────────────────────────────────────────────────────────────

  Future<void> joinHost({
    required Uri uri,
    required String name,
    required String avatarSeed,
  }) async {
    state = state.copyWith(
      isHost: false,
      connectionState: SessionConnState.connecting,
      clearError: true,
    );
    try {
      final c = await LanGameClient.connect(uri);
      _client = c;
      c.send(CJoin(name: name, avatarSeed: avatarSeed));
      _msgSub = c.messages.listen(_handleServerMessage,
          onError: (e) {
            state = state.copyWith(
              connectionState: SessionConnState.disconnected,
              errorMessage: 'Connection error: $e',
            );
          },
          onDone: () {
            state = state.copyWith(
              connectionState: SessionConnState.disconnected,
            );
          });
    } catch (e) {
      state = state.copyWith(
        connectionState: SessionConnState.idle,
        errorMessage: 'Failed to connect: $e',
      );
    }
  }

  // ─── Common: send intents ──────────────────────────────────────────────────

  void sendReveal(int x, int y) => _send(CReveal(x: x, y: y));
  void sendFlag(int x, int y) => _send(CFlag(x: x, y: y));
  void sendChord(int x, int y) => _send(CChord(x: x, y: y));
  void sendCursor(double nx, double ny) => _send(CCursor(nx: nx, ny: ny));
  void sendEmoji(String code) => _send(CEmoji(code: code));
  void sendReady(bool ready) => _send(CReady(ready: ready));
  void sendRestart() => _send(const CRestart());

  void _send(ClientMessage msg) {
    final s = _server;
    if (s != null) {
      s.onLocalIntent(msg);
      return;
    }
    _client?.send(msg);
  }

  // ─── Outbound disconnect ───────────────────────────────────────────────────

  Future<void> leave() async {
    await _msgSub?.cancel();
    _msgSub = null;
    await _serverEventSub?.cancel();
    _serverEventSub = null;
    await _client?.close();
    _client = null;
    await _advertiser?.stop();
    _advertiser = null;
    await _server?.stop();
    _server = null;
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
        final empty = _emptySnapshot(config, hostId, players, status,
            hearts: hearts > 0 ? hearts : config.initialHearts);
        // Preserve existing reveals/flags if game is in progress.
        if (snap != null &&
            snap.config.width == config.width &&
            snap.config.height == config.height &&
            status == GameStatus.playing) {
          state = state.copyWith(
            config: config,
            snapshot: snap.copyWith(
              config: config,
              hostId: hostId,
              players: players,
              status: status,
              hearts: hearts,
            ),
            connectionState: _stateFromStatus(status),
          );
        } else {
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
        for (final r in cells) {
          final idx = r.y * snap.width + r.x;
          newCells[idx] = r.value;
          newFlags[idx] = null;
        }
        final last = cells.isNotEmpty
            ? (x: cells.last.x, y: cells.last.y, byPlayer: byPlayerId)
            : snap.lastEvent;
        state = state.copyWith(
          snapshot: _withCellsAndFlags(snap, newCells, newFlags, last),
        );
      case SFlagged(:final x, :final y, :final flagged, :final byPlayerId):
        if (snap == null) return;
        final newFlags = List<String?>.from(snap.flags);
        newFlags[y * snap.width + x] = flagged ? byPlayerId : null;
        state = state.copyWith(
          snapshot: _withCellsAndFlags(
            snap,
            snap.cells,
            newFlags,
            (x: x, y: y, byPlayer: byPlayerId),
          ),
        );
      case SGameOver(
          :final won,
          :final losingPlayerId,
          :final minePositions,
          :final stats
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
            lastExplosion: (
              x: x,
              y: y,
              centers: explosionCenters,
              id: DateTime.now().microsecondsSinceEpoch,
            ),
            lastEvent: (x: x, y: y, byPlayer: byPlayerId),
          ),
        );
      case SCursor(:final playerId, :final nx, :final ny):
        if (snap == null) return;
        if (playerId == state.localId) return;
        final newCursors =
            Map<String, ({double nx, double ny})>.from(snap.cursors);
        newCursors[playerId] = (nx: nx, ny: ny);
        state = state.copyWith(snapshot: snap.copyWith(cursors: newCursors));
      case SEmoji(:final playerId, :final code):
        ref.read(emojiBurstProvider.notifier).push(playerId, code);
      case SError(:final message):
        state = state.copyWith(errorMessage: message);
    }
  }

  GameSnapshot _withCellsAndFlags(
    GameSnapshot snap,
    List<int> cells,
    List<String?> flags,
    ({int x, int y, String byPlayer})? last,
  ) =>
      snap.copyWith(cells: cells, flags: flags, lastEvent: last);

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
