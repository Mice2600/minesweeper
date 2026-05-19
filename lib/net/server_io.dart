import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/ids.dart';
import '../game/difficulty.dart';
import '../game/engine.dart';
import 'messages.dart';

const _maxPlayers = 4;

class _Connection {
  _Connection(this.channel, this.playerId);
  final WebSocketChannel channel;
  final String playerId;
  PlayerInfo? info;
  StreamSubscription? sub;
}

class ServerEvent {
  const ServerEvent(this.message);
  final ServerMessage message;
}

/// Local WebSocket server. The host's *own* presence in the lobby is added via
/// [registerLocalHost]; local intents (the host clicking on its own UI) are
/// fed through [onLocalIntent].
class LanGameServer {
  LanGameServer({
    required this.hostName,
    required this.hostAvatarSeed,
    required this.config,
  });

  String hostName;
  String hostAvatarSeed;
  GameConfig config;

  late final String hostId = shortId();
  HttpServer? _httpServer;
  int _port = 0;
  int get port => _port;

  final List<_Connection> _conns = [];
  final Map<String, PlayerInfo> _players = {};

  GameEngine? _engine;
  GameEngine? get engine => _engine;

  final StreamController<ServerEvent> _eventCtrl =
      StreamController<ServerEvent>.broadcast();
  Stream<ServerEvent> get events => _eventCtrl.stream;

  Iterable<PlayerInfo> get players => _players.values;

  Future<void> start() async {
    final handler = webSocketHandler((WebSocketChannel channel, _) {
      _onConnection(channel);
    });
    final pipeline = const Pipeline().addHandler(handler);
    _httpServer =
        await shelf_io.serve(pipeline, InternetAddress.anyIPv4, 0, shared: false);
    _port = _httpServer!.port;
    // Add host to the lobby roster.
    _players[hostId] = PlayerInfo(
      id: hostId,
      name: hostName,
      avatarSeed: hostAvatarSeed,
      color: _colorFor(_players.length),
      isHost: true,
      isReady: true,
    );
    _broadcastLobby();
  }

  Future<void> stop() async {
    for (final c in _conns) {
      await c.sub?.cancel();
      await c.channel.sink.close();
    }
    _conns.clear();
    await _httpServer?.close(force: true);
    _httpServer = null;
    await _eventCtrl.close();
  }

  // ─── Connection lifecycle ───────────────────────────────────────────────────

  void _onConnection(WebSocketChannel channel) {
    if (_players.length >= _maxPlayers) {
      channel.sink.add(
          const SError(code: 'full', message: 'Lobby is full').encode());
      channel.sink.close();
      return;
    }
    final pid = shortId();
    final conn = _Connection(channel, pid);
    _conns.add(conn);
    channel.sink.add(SWelcome(yourId: pid, protocol: protocolVersion).encode());
    conn.sub = channel.stream.listen(
      (data) => _handleClientFrame(conn, data),
      onDone: () => _onDisconnect(conn),
      onError: (_) => _onDisconnect(conn),
      cancelOnError: true,
    );
  }

  void _onDisconnect(_Connection conn) {
    _conns.remove(conn);
    _players.remove(conn.playerId);
    _broadcastLobby();
  }

  // ─── Inbound from a guest ───────────────────────────────────────────────────

  void _handleClientFrame(_Connection conn, dynamic data) {
    if (data is! String) return;
    final ClientMessage msg;
    try {
      msg = ClientMessage.decode(data);
    } catch (_) {
      conn.channel.sink
          .add(const SError(code: 'badFrame', message: 'malformed').encode());
      return;
    }
    _applyClientMessage(conn.playerId, msg);
  }

  // ─── Inbound from the host's own UI ─────────────────────────────────────────

  void onLocalIntent(ClientMessage msg) {
    _applyClientMessage(hostId, msg);
  }

  // ─── Core message handling ──────────────────────────────────────────────────

  void _applyClientMessage(String playerId, ClientMessage msg) {
    switch (msg) {
      case CJoin(:final name, :final avatarSeed):
        _players[playerId] = PlayerInfo(
          id: playerId,
          name: name,
          avatarSeed: avatarSeed,
          color: _colorFor(_players.length),
        );
        _broadcastLobby();
      case CReady(:final ready):
        final p = _players[playerId];
        if (p != null) _players[playerId] = p.copyWith(isReady: ready);
        _broadcastLobby();
      case CStartGame(:final config):
        if (playerId != hostId) {
          _sendTo(playerId,
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
        _broadcastLobby();
      case CReveal(:final x, :final y):
        final e = _engine;
        if (e == null) return;
        final out = e.reveal(x, y, playerId: playerId);
        if (out.cells.isNotEmpty) {
          _broadcast(SRevealed(cells: out.cells, byPlayerId: out.byPlayerId));
        }
        if (out.heartLost) {
          _broadcast(SHeartsChanged(
            hearts: out.heartsRemaining,
            byPlayerId: playerId,
            x: out.triggerX,
            y: out.triggerY,
            explosionCenters: out.explosionCenters,
          ));
        }
        _checkGameEnd();
      case CFlag(:final x, :final y):
        final e = _engine;
        if (e == null) return;
        final out = e.flag(x, y, playerId: playerId);
        if (out != null) {
          _broadcast(SFlagged(
            x: out.x,
            y: out.y,
            flagged: out.flagged,
            byPlayerId: out.byPlayerId,
          ));
        }
      case CChord(:final x, :final y):
        final e = _engine;
        if (e == null) return;
        final out = e.chord(x, y, playerId: playerId);
        if (out.cells.isNotEmpty) {
          _broadcast(SRevealed(cells: out.cells, byPlayerId: out.byPlayerId));
        }
        if (out.heartLost) {
          _broadcast(SHeartsChanged(
            hearts: out.heartsRemaining,
            byPlayerId: playerId,
            x: out.triggerX,
            y: out.triggerY,
            explosionCenters: out.explosionCenters,
          ));
        }
        _checkGameEnd();
      case CCursor(:final nx, :final ny):
        _broadcast(SCursor(playerId: playerId, nx: nx, ny: ny),
            exclude: playerId);
      case CEmoji(:final code):
        _broadcast(SEmoji(playerId: playerId, code: code));
      case CRestart():
        if (playerId != hostId) return;
        _engine = null;
        _broadcastLobby();
      case CLeave():
        final conn = _conns.where((c) => c.playerId == playerId).firstOrNull;
        if (conn != null) {
          conn.channel.sink.close();
          _onDisconnect(conn);
        } else if (playerId == hostId) {
          // host leaving — no-op here; UI handles stopping the server.
        }
    }
  }

  void _checkGameEnd() {
    final e = _engine;
    if (e == null) return;
    if (e.status == GameStatus.won || e.status == GameStatus.lost) {
      _broadcast(SGameOver(
        won: e.status == GameStatus.won,
        losingPlayerId: e.losingPlayerId,
        minePositions: e.board.minePositions(),
        stats: e.stats,
      ));
    }
  }

  // ─── Send helpers ───────────────────────────────────────────────────────────

  void _broadcast(ServerMessage msg, {String? exclude}) {
    final encoded = msg.encode();
    for (final c in _conns) {
      if (c.playerId == exclude) continue;
      c.channel.sink.add(encoded);
    }
    _eventCtrl.add(ServerEvent(msg));
  }

  void _sendTo(String playerId, ServerMessage msg) {
    final c = _conns.where((c) => c.playerId == playerId).firstOrNull;
    c?.channel.sink.add(msg.encode());
    if (playerId == hostId) _eventCtrl.add(ServerEvent(msg));
  }

  /// Public for the host UI to call when it changes config without sending an
  /// intent (e.g. switching the difficulty in the lobby).
  void broadcastLobby() => _broadcastLobby();

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
    0xFF6750A4, // primary purple
    0xFF03A9F4, // cyan blue
    0xFFE91E63, // pink
    0xFFFFB300, // amber
    0xFF43A047, // green
    0xFFE53935, // red
  ];

  int _colorFor(int idx) => _palette[idx % _palette.length];
}

extension on Iterable<_Connection> {
  _Connection? get firstOrNull => isEmpty ? null : first;
}
