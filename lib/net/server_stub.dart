import '../game/difficulty.dart';
import 'messages.dart';

/// Web stub — hosting is not supported in the browser.
class LanGameServer {
  LanGameServer({
    required this.hostName,
    required this.hostAvatarSeed,
    required this.config,
  });

  String hostName;
  String hostAvatarSeed;
  GameConfig config;

  Stream<ServerEvent> get events =>
      const Stream<ServerEvent>.empty();

  String get hostId => '';
  int get port => 0;
  Iterable<PlayerInfo> get players => const [];

  Future<void> start() async {
    throw UnsupportedError('Hosting is not supported on web.');
  }

  Future<void> stop() async {}

  void onLocalIntent(ClientMessage _) {}
  void setConfig(GameConfig _) {}
  void startGame() {}
  void restart() {}
  void broadcastLobby() {}
}

/// Event emitted by the server for the host UI to react to (e.g. show its own
/// pieces of the game). The host's own intents go through [LanGameServer.onLocalIntent].
class ServerEvent {
  const ServerEvent(this.message);
  final ServerMessage message;
}
