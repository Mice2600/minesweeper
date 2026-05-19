import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/session.dart';

class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key});

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _manualCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(discoveryProvider.notifier).start();
      });
    }
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hosts = ref.watch(discoveryProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join a game'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(discoveryProvider.notifier).stop();
            context.go('/');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!kIsWeb) ...[
                Row(
                  children: [
                    Text('Nearby games',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: hosts.isEmpty
                      ? Center(
                          child: Text(
                            'Searching…',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        )
                      : ListView.separated(
                          itemCount: hosts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final h = hosts[i];
                            return Card(
                              child: ListTile(
                                leading:
                                    const Icon(Icons.wifi_tethering_rounded),
                                title: Text(h.name),
                                subtitle: Text('${h.host}:${h.port}'),
                                trailing:
                                    const Icon(Icons.arrow_forward_ios_rounded),
                                onTap: () => _connect(h.wsUri.toString()),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                const Divider(),
              ] else
                const SizedBox.shrink(),
              const SizedBox(height: 8),
              Text('Enter address',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _manualCtrl,
                decoration: const InputDecoration(
                  hintText: 'ws://192.168.1.10:8080',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                style: const TextStyle(fontFamily: 'monospace'),
                onSubmitted: _connect,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => _connect(_manualCtrl.text.trim()),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Connect'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _connect(String url) {
    if (url.isEmpty) return;
    final normalized = url.startsWith('ws://') || url.startsWith('wss://')
        ? url
        : 'ws://$url';
    context.push('/join?url=${Uri.encodeQueryComponent(normalized)}');
  }
}
