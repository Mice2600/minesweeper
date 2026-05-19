class DiscoveredHost {
  const DiscoveredHost({
    required this.name,
    required this.host,
    required this.port,
  });
  final String name;
  final String host;
  final int port;

  Uri get wsUri => Uri.parse('ws://$host:$port');
}

/// Web stub — no mDNS support in browsers.
class DiscoveryAdvertiser {
  DiscoveryAdvertiser({required this.serviceName, required this.port});
  final String serviceName;
  final int port;

  Future<void> start() async {
    // Silently no-op on web.
  }

  Future<void> stop() async {}
}

class DiscoveryBrowser {
  Stream<List<DiscoveredHost>> get hosts =>
      const Stream<List<DiscoveredHost>>.empty();

  Future<void> start() async {}
  Future<void> stop() async {}
}
