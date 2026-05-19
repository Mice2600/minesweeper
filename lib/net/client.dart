import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

import 'messages.dart';

class LanGameClient {
  LanGameClient._(this._channel);

  final WebSocketChannel _channel;
  final _msgCtrl = StreamController<ServerMessage>.broadcast();
  StreamSubscription? _sub;
  String? _yourId;

  String? get yourId => _yourId;
  Stream<ServerMessage> get messages => _msgCtrl.stream;

  static Future<LanGameClient> connect(Uri uri) async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;
    final c = LanGameClient._(channel);
    c._listen();
    return c;
  }

  void _listen() {
    _sub = _channel.stream.listen(
      (data) {
        if (data is! String) return;
        try {
          final msg = ServerMessage.decode(data);
          if (msg is SWelcome) _yourId = msg.yourId;
          _msgCtrl.add(msg);
        } catch (_) {
          // ignore malformed
        }
      },
      onDone: () {
        _msgCtrl.close();
      },
      onError: (e, st) {
        _msgCtrl.addError(e, st);
      },
      cancelOnError: false,
    );
  }

  void send(ClientMessage msg) {
    _channel.sink.add(msg.encode());
  }

  Future<void> close() async {
    await _sub?.cancel();
    await _channel.sink.close(ws_status.normalClosure);
    if (!_msgCtrl.isClosed) await _msgCtrl.close();
  }
}
