import 'messages.dart';
import 'transport.dart';

/// Web stub — hosting via the embedded socket server is not supported in the
/// browser. The relay-based [HostTransport] is the cross-platform path.
class LanHostTransport implements HostTransport {
  LanHostTransport();

  int get port => 0;

  @override
  Stream<HostTransportEvent> get events =>
      const Stream<HostTransportEvent>.empty();

  @override
  Future<HostJoinInfo> start() async {
    throw UnsupportedError('LAN hosting is not supported on web.');
  }

  @override
  Future<void> stop() async {}

  @override
  void sendToGuest(String _, ServerMessage __) {}

  @override
  void broadcast(ServerMessage _, {String? excludePlayerId}) {}

  @override
  void disconnectGuest(String _) {}
}
