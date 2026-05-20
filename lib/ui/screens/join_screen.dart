import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/session.dart';
import '../widgets/player_chip.dart';

class JoinScreen extends ConsumerStatefulWidget {
  const JoinScreen({super.key, this.lanUrl, this.roomCode});

  /// LAN: full `ws://ip:port` URL.
  final String? lanUrl;

  /// Online: 5-char relay room code.
  final String? roomCode;

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  Future<void> _connect() async {
    final p = ref.read(localProfileProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final code = widget.roomCode;
    final url = widget.lanUrl;
    try {
      if (code != null && code.isNotEmpty) {
        await notifier.joinHost(
          mode: JoinMode.online,
          roomCode: code,
          name: p.name,
          avatarSeed: p.avatarSeed,
        );
      } else if (url != null && url.isNotEmpty) {
        await notifier.joinHost(
          mode: JoinMode.lan,
          lanUri: Uri.parse(url),
          name: p.name,
          avatarSeed: p.avatarSeed,
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);

    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next.connectionState == SessionConnState.playing) {
        context.go('/game');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Joining'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await ref.read(sessionProvider.notifier).leave();
            if (!context.mounted) return;
            context.go('/');
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _buildBody(s),
        ),
      ),
    );
  }

  Widget _buildBody(SessionState s) {
    if (s.connectionState == SessionConnState.connecting) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Connecting…'),
          ],
        ),
      );
    }
    if (s.errorMessage != null && s.snapshot == null) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: cs.error, size: 48),
            const SizedBox(height: 12),
            Text(s.errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go('/browse'),
              child: const Text('Back'),
            ),
          ],
        ),
      );
    }
    final players = s.snapshot?.players ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Waiting for host to start…',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Text('Players (${players.length}/4)',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: players
              .map((p) => PlayerChip(
                    player: p,
                    subtitle: p.id == s.localId ? 'You' : null,
                  ))
              .toList(),
        ),
        const Spacer(),
        const Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
