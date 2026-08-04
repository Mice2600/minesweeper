import 'messages.dart';

/// Information returned by [HostTransport.start] so the host UI can show
/// either a `ws://ip:port` URL (LAN) or a short room code (online).
class HostJoinInfo {
  const HostJoinInfo({required this.kind, this.lanPort, this.roomCode});
  final HostJoinKind kind;
  final int? lanPort;
  final String? roomCode;
}

enum HostJoinKind { lan, online }

sealed class HostTransportEvent {
  const HostTransportEvent();
}

class GuestConnected extends HostTransportEvent {
  const GuestConnected(this.playerId);
  final String playerId;
}

class GuestMessage extends HostTransportEvent {
  const GuestMessage(this.playerId, this.message);
  final String playerId;
  final ClientMessage message;
}

class GuestDisconnected extends HostTransportEvent {
  const GuestDisconnected(this.playerId);
  final String playerId;
}

class HostTransportError extends HostTransportEvent {
  const HostTransportError(this.code, this.message);
  final String code;
  final String message;
}

/// Transport seam between the relay/LAN socket layer and [HostSession]. The
/// transport is purely a pipe — it does not know about `GameEngine`, lobby
/// state, or message contents beyond decoding the protocol envelope.
abstract class HostTransport {
  Future<HostJoinInfo> start();
  Stream<HostTransportEvent> get events;
  void sendToGuest(String playerId, ServerMessage msg);
  void broadcast(ServerMessage msg, {String? excludePlayerId});

  /// Force-closes one guest's connection. Used by the host's kick flow, which
  /// sends [SKicked] first and then calls this. Implementations must be a
  /// no-op for an unknown [playerId]. A normal [GuestDisconnected] event
  /// follows, so the session's usual departure path still runs.
  void disconnectGuest(String playerId);

  Future<void> stop();
}

/// Guest-side equivalent. Owns one outbound connection and surfaces decoded
/// [ServerMessage]s to the session.
abstract class GuestTransport {
  Future<void> connect();
  Stream<ServerMessage> get events;
  void send(ClientMessage msg);
  Future<void> close();
}
