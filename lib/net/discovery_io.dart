import 'dart:async';

import 'package:nsd/nsd.dart' as nsd;

const _serviceType = '_minesweeper._tcp';

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

class DiscoveryAdvertiser {
  DiscoveryAdvertiser({required this.serviceName, required this.port});

  final String serviceName;
  final int port;
  nsd.Registration? _registration;

  Future<void> start() async {
    try {
      _registration = await nsd.register(
        nsd.Service(name: serviceName, type: _serviceType, port: port),
      );
    } catch (_) {
      // mDNS not available on this platform — fall back to manual entry only.
    }
  }

  Future<void> stop() async {
    final r = _registration;
    if (r != null) {
      try {
        await nsd.unregister(r);
      } catch (_) {}
      _registration = null;
    }
  }
}

class DiscoveryBrowser {
  nsd.Discovery? _discovery;
  final Map<String, DiscoveredHost> _hosts = {};
  final _ctrl = StreamController<List<DiscoveredHost>>.broadcast();

  Stream<List<DiscoveredHost>> get hosts => _ctrl.stream;

  Future<void> start() async {
    try {
      _discovery = await nsd.startDiscovery(
        _serviceType,
        ipLookupType: nsd.IpLookupType.v4,
      );
      _discovery!.addServiceListener((service, status) {
        final host = service.addresses?.firstOrNull?.address ?? service.host;
        if (host == null || service.port == null) return;
        final key = '${service.name}|$host|${service.port}';
        if (status == nsd.ServiceStatus.found) {
          _hosts[key] = DiscoveredHost(
            name: service.name ?? 'Host',
            host: host,
            port: service.port!,
          );
        } else if (status == nsd.ServiceStatus.lost) {
          _hosts.remove(key);
        }
        _ctrl.add(_hosts.values.toList());
      });
      _ctrl.add(_hosts.values.toList());
    } catch (_) {
      _ctrl.add(const []);
    }
  }

  Future<void> stop() async {
    final d = _discovery;
    if (d != null) {
      try {
        await nsd.stopDiscovery(d);
      } catch (_) {}
      _discovery = null;
    }
    if (!_ctrl.isClosed) await _ctrl.close();
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
