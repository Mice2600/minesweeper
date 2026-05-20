import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'messages.dart';
import 'transport.dart';

/// LAN [GuestTransport]: one direct WebSocket to the host's `ws://ip:port`.
class LanGuestTransport implements GuestTransport {
  LanGuestTransport(this.uri);

  final Uri uri;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _ctrl = StreamController<ServerMessage>.broadcast();

  /// Heartbeat cadence matches [RelayGuestTransport] so the same session-layer
  /// reconnect loop applies uniformly to LAN drops.
  static const _pingInterval = Duration(seconds: 8);
  static const _deadTimeout = Duration(seconds: 22);
  Timer? _heartbeat;
  DateTime _lastFrameAt = DateTime.now();

  @override
  Stream<ServerMessage> get events => _ctrl.stream;

  @override
  Future<void> connect() async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    _channel = channel;
    _lastFrameAt = DateTime.now();
    _sub = channel.stream.listen(
      (data) {
        if (data is! String) return;
        _lastFrameAt = DateTime.now();
        try {
          final msg = ServerMessage.decode(data);
          if (msg is SPong) return; // heartbeat ack — swallow
          _ctrl.add(msg);
        } catch (_) {
          // ignore malformed
        }
      },
      onDone: () {
        _heartbeat?.cancel();
        _heartbeat = null;
        if (!_ctrl.isClosed) _ctrl.close();
      },
      onError: (e, st) {
        _heartbeat?.cancel();
        _heartbeat = null;
        if (!_ctrl.isClosed) _ctrl.addError(e, st);
      },
      cancelOnError: false,
    );
    _startHeartbeat();
  }

  @override
  void send(ClientMessage msg) {
    _channel?.sink.add(msg.encode());
  }

  @override
  Future<void> close() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
    if (!_ctrl.isClosed) await _ctrl.close();
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_pingInterval, (_) {
      if (DateTime.now().difference(_lastFrameAt) > _deadTimeout) {
        _heartbeat?.cancel();
        _heartbeat = null;
        try {
          _channel?.sink.close(ws_status.goingAway, 'heartbeat-timeout');
        } catch (_) {}
        return;
      }
      send(const CPing());
    });
  }
}
