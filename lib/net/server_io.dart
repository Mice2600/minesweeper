import 'dart:async';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/ids.dart';
import 'messages.dart';
import 'transport.dart';

const _maxLanConnections = 7;

class _LanConn {
  _LanConn(this.channel, this.playerId);
  final WebSocketChannel channel;
  final String playerId;
  StreamSubscription? sub;
}

/// LAN [HostTransport]: embedded `shelf` WebSocket server bound to all IPv4
/// interfaces on an OS-assigned port. Discovery is handled separately via
/// mDNS — see [DiscoveryAdvertiser].
class LanHostTransport implements HostTransport {
  LanHostTransport();

  HttpServer? _httpServer;
  int _port = 0;
  int get port => _port;

  final List<_LanConn> _conns = [];

  final StreamController<HostTransportEvent> _eventCtrl =
      StreamController<HostTransportEvent>.broadcast();

  @override
  Stream<HostTransportEvent> get events => _eventCtrl.stream;

  @override
  Future<HostJoinInfo> start() async {
    final handler = webSocketHandler((WebSocketChannel channel, _) {
      _onConnection(channel);
    });
    final pipeline = const Pipeline().addHandler(handler);
    _httpServer = await shelf_io.serve(
      pipeline,
      InternetAddress.anyIPv4,
      0,
      shared: false,
    );
    _port = _httpServer!.port;
    return HostJoinInfo(kind: HostJoinKind.lan, lanPort: _port);
  }

  @override
  Future<void> stop() async {
    for (final c in _conns) {
      await c.sub?.cancel();
      try {
        await c.channel.sink.close();
      } catch (_) {}
    }
    _conns.clear();
    await _httpServer?.close(force: true);
    _httpServer = null;
    if (!_eventCtrl.isClosed) await _eventCtrl.close();
  }

  @override
  void sendToGuest(String playerId, ServerMessage msg) {
    final c = _connFor(playerId);
    if (c == null) return;
    _safeSend(c, msg.encode());
  }

  @override
  void broadcast(ServerMessage msg, {String? excludePlayerId}) {
    final encoded = msg.encode();
    for (final c in _conns) {
      if (c.playerId == excludePlayerId) continue;
      _safeSend(c, encoded);
    }
  }

  @override
  void disconnectGuest(String playerId) {
    final c = _connFor(playerId);
    if (c == null) return;
    // Drop the socket. `_onClose` runs from the stream's onDone and emits the
    // usual GuestDisconnected, so HostSession's departure path is unchanged.
    try {
      c.channel.sink.close(1000, 'kicked');
    } catch (_) {}
  }

  // ─── Internals ─────────────────────────────────────────────────────────────

  void _onConnection(WebSocketChannel channel) {
    if (_conns.length >= _maxLanConnections) {
      try {
        channel.sink.add(
            const SError(code: 'full', message: 'Lobby is full').encode());
        channel.sink.close();
      } catch (_) {}
      return;
    }
    final pid = shortId();
    final conn = _LanConn(channel, pid);
    _conns.add(conn);
    _eventCtrl.add(GuestConnected(pid));
    conn.sub = channel.stream.listen(
      (data) => _onFrame(conn, data),
      onDone: () => _onClose(conn),
      onError: (_) => _onClose(conn),
      cancelOnError: true,
    );
  }

  void _onFrame(_LanConn conn, dynamic data) {
    if (data is! String) return;
    try {
      final msg = ClientMessage.decode(data);
      _eventCtrl.add(GuestMessage(conn.playerId, msg));
    } catch (_) {
      _safeSend(
        conn,
        const SError(code: 'badFrame', message: 'malformed').encode(),
      );
    }
  }

  void _onClose(_LanConn conn) {
    if (!_conns.remove(conn)) return;
    _eventCtrl.add(GuestDisconnected(conn.playerId));
  }

  _LanConn? _connFor(String playerId) {
    for (final c in _conns) {
      if (c.playerId == playerId) return c;
    }
    return null;
  }

  void _safeSend(_LanConn conn, String encoded) {
    try {
      conn.channel.sink.add(encoded);
    } catch (_) {
      // socket likely closed; the close handler will drain it
    }
  }
}
