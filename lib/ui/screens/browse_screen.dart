import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show
        Clipboard,
        FilteringTextInputFormatter,
        LengthLimitingTextInputFormatter,
        TextInputFormatter;
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
  final _codeCtrl = TextEditingController();

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
    _codeCtrl.dispose();
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Join online with a code',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _codeCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. Q7K9M',
                  prefixIcon: const Icon(Icons.vpn_key_rounded),
                  suffixIcon: IconButton(
                    tooltip: 'Paste',
                    icon: const Icon(Icons.content_paste_rounded),
                    onPressed: _pasteCode,
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.go,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z]')),
                  LengthLimitingTextInputFormatter(5),
                  _UppercaseFormatter(),
                ],
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 20,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                ),
                onSubmitted: (_) => _connectOnline(),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _connectOnline,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Join with code'),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              if (!kIsWeb) ...[
                Row(
                  children: [
                    Text('Nearby games on Wi-Fi',
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
                if (hosts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'Searching…',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: hosts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                          onTap: () => _connectLan(h.wsUri.toString()),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                const Divider(),
              ],
              const SizedBox(height: 8),
              Text('Enter Wi-Fi address',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _manualCtrl,
                decoration: const InputDecoration(
                  hintText: 'ws://192.168.1.10:8080',
                  prefixIcon: Icon(Icons.link_rounded),
                ),
                style: const TextStyle(fontFamily: 'monospace'),
                onSubmitted: _connectLan,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _connectLan(_manualCtrl.text.trim()),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Connect to Wi-Fi host'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _connectLan(String url) {
    if (url.isEmpty) return;
    final normalized = url.startsWith('ws://') || url.startsWith('wss://')
        ? url
        : 'ws://$url';
    context.push('/join?url=${Uri.encodeQueryComponent(normalized)}');
  }

  void _connectOnline() {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    context.push('/join?code=${Uri.encodeQueryComponent(code)}');
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    final cleaned = text.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    if (cleaned.isEmpty) return;
    final trimmed = cleaned.length > 5 ? cleaned.substring(0, 5) : cleaned;
    _codeCtrl.text = trimmed;
    _codeCtrl.selection =
        TextSelection.collapsed(offset: trimmed.length);
  }
}

class _UppercaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
