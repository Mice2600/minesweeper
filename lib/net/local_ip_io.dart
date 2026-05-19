import 'dart:io';

Future<List<String>> getLocalIPv4Addresses() async {
  final out = <String>[];
  try {
    final ifaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    for (final iface in ifaces) {
      for (final addr in iface.addresses) {
        out.add(addr.address);
      }
    }
  } catch (_) {}
  return out;
}
