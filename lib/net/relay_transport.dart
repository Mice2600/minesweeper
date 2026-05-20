import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'messages.dart';
import 'relay_config.dart';
import 'transport.dart';

/// Thrown by [RelayHostTransport.start] / [RelayGuestTransport.connect] when
/// the relay rejects the connection (room not found, full, etc.) or it drops
/// before the handshake completes. UI shows [userMessage] verbatim.
class RelayJoinException implements Exception {
  const RelayJoinException(this.code, this.userMessage);
  final String code;
  final String userMessage;

  @override
  String toString() => userMessage;
}

/// Online [HostTransport]: opens a single WebSocket to the relay's `/create`
/// endpoint. The relay generates the room code (received in the first control
/// frame) and forwards messages to and from guests, identifying each by an
/// id the relay assigns. The session layer treats these ids exactly like LAN
/// guest ids.
class RelayHostTransport implements HostTransport {
  RelayHostTransport({String? baseUrl}) : baseUrl = baseUrl ?? relayBaseUrl;

  final String baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _ctrl = StreamController<HostTransportEvent>.broadcast();
  final Completer<HostJoinInfo> _started = Completer<HostJoinInfo>();

  /// Liveness watchdog. Guests ping every ~8s; if the relay socket goes
  /// silent for [_deadTimeout] while at least one guest is present, treat the
  /// socket as half-open and force-close so the host session surfaces a
  /// transport error to the UI.
  static const _watchdogInterval = Duration(seconds: 10);
  static const _deadTimeout = Duration(seconds: 30);
  Timer? _watchdog;
  DateTime _lastFrameAt = DateTime.now();
  int _connectedGuests = 0;

  // ─── Reclaim bookkeeping ─────────────────────────────────────────────────
  // After /create succeeds, we cache the assigned [code] and [hostToken] so
  // a dropped socket can hit /reclaim and reattach as host without losing
  // the room or kicking guests. `_stopped` distinguishes user-initiated
  // shutdown from network drops.
  String? _roomCode;
  String? _hostToken;
  bool _stopped = false;
  Timer? _reclaimTimer;
  int _reclaimAttempt = 0;
  static const _reclaimBackoffSecs = <int>[1, 2, 4, 8, 8, 8];

  @override
  Stream<HostTransportEvent> get events => _ctrl.stream;

  @override
  Future<HostJoinInfo> start() async {
    if (!relayIsConfigured) {
      throw const RelayJoinException(
        'not-configured',
        'Online play needs a relay URL. Rebuild with '
            '--dart-define=RELAY_URL=wss://your-relay.workers.dev',
      );
    }
    final uri = Uri.parse('$baseUrl/create');
    final channel = WebSocketChannel.connect(uri);
    try {
      await channel.ready.timeout(const Duration(seconds: 8));
    } catch (e) {
      try {
        await channel.sink.close();
      } catch (_) {}
      if (!_started.isCompleted) {
        _started.completeError(RelayJoinException(
          'unreachable',
          "Couldn't reach the relay at $baseUrl",
        ));
      }
      rethrow;
    }
    _channel = channel;
    _lastFrameAt = DateTime.now();
    _sub = channel.stream.listen(
      _onFrame,
      onDone: _onClose,
      onError: (e, st) {
        if (!_ctrl.isClosed) {
          _ctrl.add(HostTransportError('socket', e.toString()));
        }
        _onClose();
      },
      cancelOnError: false,
    );
    _startWatchdog();
    return _started.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        try {
          channel.sink.close();
        } catch (_) {}
        throw const RelayJoinException(
          'timeout',
          'Relay accepted the connection but never assigned a room code',
        );
      },
    );
  }

  @override
  Future<void> stop() async {
    _stopped = true;
    _watchdog?.cancel();
    _watchdog = null;
    _reclaimTimer?.cancel();
    _reclaimTimer = null;
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close(ws_status.normalClosure);
    } catch (_) {}
    _channel = null;
    if (!_ctrl.isClosed) await _ctrl.close();
    if (!_started.isCompleted) {
      _started.completeError(StateError('relay host stopped before created'));
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer.periodic(_watchdogInterval, (_) {
      // Only police idleness when guests should be sending heartbeats.
      if (_connectedGuests == 0) return;
      if (DateTime.now().difference(_lastFrameAt) > _deadTimeout) {
        _watchdog?.cancel();
        _watchdog = null;
        if (!_ctrl.isClosed) {
          _ctrl.add(const HostTransportError(
            'half-open',
            'Relay socket went silent — closing and reconnecting',
          ));
        }
        try {
          _channel?.sink.close(ws_status.goingAway, 'host-watchdog');
        } catch (_) {}
      }
    });
  }

  @override
  void sendToGuest(String playerId, ServerMessage msg) {
    _sendFrame({'kind': 'to-guest', 'to': playerId, 'msg': msg.encode()});
  }

  @override
  void broadcast(ServerMessage msg, {String? excludePlayerId}) {
    if (excludePlayerId == null) {
      _sendFrame({'kind': 'to-all', 'msg': msg.encode()});
      return;
    }
    // The relay's "to-all" can't exclude — fall back to per-guest sends.
    // The session layer only excludes the original sender; this is rare
    // (only cursor frames), so the per-target send overhead is fine.
    // We don't have the guest list here, so we let the relay do the broadcast
    // and the excluded guest's own client filters it locally. This matches
    // existing LAN behavior where SCursor sent with exclude=self is also
    // filtered client-side in [SessionNotifier._handleServerMessage].
    _sendFrame({'kind': 'to-all', 'msg': msg.encode()});
  }

  void _sendFrame(Map<String, Object?> frame) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode(frame));
    } catch (_) {}
  }

  void _onFrame(dynamic data) {
    if (data is! String) return;
    _lastFrameAt = DateTime.now();
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (j['kind']) {
      case 'control':
        final op = j['op'] as String?;
        if (op == 'created') {
          final code = j['code'] as String?;
          final token = j['hostToken'] as String?;
          if (code != null) _roomCode = code;
          if (token != null) _hostToken = token;
          if (code != null && !_started.isCompleted) {
            _started.complete(
              HostJoinInfo(kind: HostJoinKind.online, roomCode: code),
            );
          }
        } else if (op == 'reclaimed') {
          final code = j['code'] as String?;
          final token = j['hostToken'] as String?;
          if (code != null) _roomCode = code;
          if (token != null) _hostToken = token;
          // No GuestConnected emit here — the relay follows up with one
          // `joined` control frame per surviving guest.
        } else if (op == 'joined') {
          final id = j['id'] as String?;
          if (id != null) {
            _connectedGuests++;
            _ctrl.add(GuestConnected(id));
          }
        } else if (op == 'left') {
          final id = j['id'] as String?;
          if (id != null) {
            if (_connectedGuests > 0) _connectedGuests--;
            _ctrl.add(GuestDisconnected(id));
          }
        } else if (op == 'error') {
          final code = j['code'] as String? ?? 'error';
          final message = j['message'] as String? ?? 'Relay error';
          if (!_started.isCompleted) {
            _started.completeError(RelayJoinException(code, message));
          }
          _ctrl.add(HostTransportError(code, message));
        }
      case 'from-guest':
        final from = j['from'] as String?;
        final raw = j['msg'] as String?;
        if (from == null || raw == null) return;
        try {
          final msg = ClientMessage.decode(raw);
          _ctrl.add(GuestMessage(from, msg));
        } catch (_) {
          // malformed — ignore
        }
    }
  }

  void _onClose() {
    _watchdog?.cancel();
    _watchdog = null;
    if (!_started.isCompleted) {
      _started.completeError(const RelayJoinException(
        'closed',
        'Relay closed the connection before the room was created',
      ));
      return;
    }
    if (_stopped) return; // user-initiated tear-down, no reclaim
    if (_roomCode == null || _hostToken == null) {
      if (!_ctrl.isClosed) {
        _ctrl.add(const HostTransportError(
            'closed', 'Relay connection closed'));
      }
      return;
    }
    // Detach the dead channel + subscription so a follow-up reclaim attempt
    // builds clean state.
    _sub?.cancel();
    _sub = null;
    _channel = null;
    _scheduleReclaim();
  }

  void _scheduleReclaim() {
    if (_stopped) return;
    if (_reclaimAttempt >= _reclaimBackoffSecs.length) {
      _reclaimAttempt = 0;
      if (!_ctrl.isClosed) {
        _ctrl.add(const HostTransportError(
          'lost',
          'Could not reclaim relay room — please restart the game.',
        ));
      }
      return;
    }
    // Surface the in-flight reclaim once so the host UI can show its banner.
    // The session translates this code into an SHostAway for its switch.
    if (_reclaimAttempt == 0 && !_ctrl.isClosed) {
      _ctrl.add(const HostTransportError(
        'reclaiming',
        'Reconnecting to relay…',
      ));
    }
    final delaySecs = _reclaimBackoffSecs[_reclaimAttempt];
    _reclaimAttempt++;
    _reclaimTimer?.cancel();
    _reclaimTimer = Timer(Duration(seconds: delaySecs), _attemptReclaim);
  }

  Future<void> _attemptReclaim() async {
    _reclaimTimer = null;
    if (_stopped) return;
    final code = _roomCode;
    final token = _hostToken;
    if (code == null || token == null) return;

    final uri = Uri.parse('$baseUrl/reclaim/$code?token=$token');
    final channel = WebSocketChannel.connect(uri);
    try {
      await channel.ready.timeout(const Duration(seconds: 8));
    } catch (_) {
      try {
        await channel.sink.close();
      } catch (_) {}
      _scheduleReclaim();
      return;
    }
    if (_stopped) {
      try {
        await channel.sink.close();
      } catch (_) {}
      return;
    }
    // Re-bind the transport to the new channel. Reset per-connection state
    // so the watchdog and guest counter recompute from incoming frames.
    _channel = channel;
    _lastFrameAt = DateTime.now();
    _connectedGuests = 0;
    _reclaimAttempt = 0;
    _sub = channel.stream.listen(
      _onFrame,
      onDone: _onClose,
      onError: (e, st) {
        if (!_ctrl.isClosed) {
          _ctrl.add(HostTransportError('socket', e.toString()));
        }
        _onClose();
      },
      cancelOnError: false,
    );
    _startWatchdog();
    if (!_ctrl.isClosed) {
      _ctrl.add(const HostTransportError('reclaimed', 'Relay reconnected'));
    }
  }
}

/// Online [GuestTransport]: WebSocket to the relay's `/join/<code>` endpoint.
/// The relay tells us our `id` in the first control frame and forwards host
/// messages as opaque payloads we then decode as [ServerMessage].
class RelayGuestTransport implements GuestTransport {
  RelayGuestTransport({required this.roomCode, String? baseUrl})
      : baseUrl = baseUrl ?? relayBaseUrl;

  final String roomCode;
  final String baseUrl;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _ctrl = StreamController<ServerMessage>.broadcast();
  String? _myId;
  final Completer<void> _connected = Completer<void>();

  /// Heartbeat cadence: ping every [_pingInterval], force-close if no frame of
  /// any kind has arrived in [_deadTimeout]. Tuned so a half-open TCP socket
  /// is detected well before the typical user notices.
  static const _pingInterval = Duration(seconds: 8);
  static const _deadTimeout = Duration(seconds: 22);
  Timer? _heartbeat;
  DateTime _lastFrameAt = DateTime.now();

  @override
  Stream<ServerMessage> get events => _ctrl.stream;

  @override
  Future<void> connect() async {
    if (!relayIsConfigured) {
      throw const RelayJoinException(
        'not-configured',
        'Online play needs a relay URL. Rebuild with '
            '--dart-define=RELAY_URL=wss://your-relay.workers.dev',
      );
    }
    final uri = Uri.parse('$baseUrl/join/$roomCode');
    final channel = WebSocketChannel.connect(uri);
    try {
      await channel.ready.timeout(const Duration(seconds: 8));
    } catch (e) {
      try {
        await channel.sink.close();
      } catch (_) {}
      if (!_connected.isCompleted) {
        _connected.completeError(RelayJoinException(
          'unreachable',
          "Couldn't reach the relay at $baseUrl",
        ));
      }
      rethrow;
    }
    _channel = channel;
    _lastFrameAt = DateTime.now();
    _sub = channel.stream.listen(
      _onFrame,
      onDone: () {
        _heartbeat?.cancel();
        _heartbeat = null;
        if (!_connected.isCompleted) {
          _connected.completeError(
              const RelayJoinException('closed', 'Connection closed'));
        }
        if (!_ctrl.isClosed) _ctrl.close();
      },
      onError: (e, st) {
        _heartbeat?.cancel();
        _heartbeat = null;
        if (!_connected.isCompleted) _connected.completeError(e, st);
        if (!_ctrl.isClosed) _ctrl.addError(e, st);
      },
      cancelOnError: false,
    );
    _startHeartbeat();
    return _connected.future.timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        try {
          channel.sink.close();
        } catch (_) {}
        throw const RelayJoinException(
          'timeout',
          'Relay never confirmed the room — check the code',
        );
      },
    );
  }

  @override
  void send(ClientMessage msg) {
    final ch = _channel;
    if (ch == null) return;
    try {
      ch.sink.add(jsonEncode({'kind': 'to-host', 'msg': msg.encode()}));
    } catch (_) {}
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
    if (!_connected.isCompleted) {
      _connected.completeError(StateError('guest closed before joined'));
    }
  }

  void _startHeartbeat() {
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_pingInterval, (_) {
      if (DateTime.now().difference(_lastFrameAt) > _deadTimeout) {
        // Half-open socket: server-side router still ACKs TCP but no app
        // frames are getting through. Force-close so the session layer kicks
        // off its reconnect loop.
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

  void _onFrame(dynamic data) {
    if (data is! String) return;
    _lastFrameAt = DateTime.now();
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(data) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    switch (j['kind']) {
      case 'control':
        final op = j['op'] as String?;
        if (op == 'joined') {
          _myId = j['id'] as String?;
          // The host will follow up with SWelcome over the relay; we don't
          // need to fabricate one here. Mark connect future complete.
          if (!_connected.isCompleted) _connected.complete();
        } else if (op == 'host-left') {
          if (!_ctrl.isClosed) {
            _ctrl.add(const SError(
                code: 'host-left', message: 'Host disconnected'));
            _ctrl.close();
          }
        } else if (op == 'host-away') {
          // Relay's host-grace window: host dropped, room still alive.
          if (!_ctrl.isClosed) _ctrl.add(const SHostAway());
        } else if (op == 'host-back') {
          // Host reclaimed within the grace window — session re-sends CJoin
          // so we get a fresh SSnapshot.
          if (!_ctrl.isClosed) _ctrl.add(const SHostBack());
        } else if (op == 'error') {
          final code = j['code'] as String? ?? 'error';
          final message = j['message'] as String? ?? 'Relay error';
          if (!_connected.isCompleted) {
            _connected.completeError(RelayJoinException(code, message));
          }
          if (!_ctrl.isClosed) {
            _ctrl.add(SError(code: code, message: message));
          }
        }
      case 'from-host':
        final raw = j['msg'] as String?;
        if (raw == null) return;
        try {
          final msg = ServerMessage.decode(raw);
          if (msg is SPong) return; // heartbeat ack — never surface upward
          _ctrl.add(msg);
        } catch (_) {
          // malformed — ignore
        }
    }
  }

  /// Relay-assigned id for this guest. Available after [connect] completes.
  String? get myId => _myId;
}
