import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../state/session.dart';
import '../widgets/chat_button.dart';
import '../widgets/chat_overlay.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/emoji_overlay.dart';
import '../widgets/match_summary.dart';
import '../widgets/player_actions.dart';
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
    // Keep the screen awake while connecting / waiting in the lobby, so a guest
    // isn't dropped by the OS sleeping before the host starts the round. The
    // game screen re-holds the lock once play begins.
    WakelockPlus.enable();
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    super.dispose();
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
          avatarData: p.avatarData,
        );
      } else if (url != null && url.isNotEmpty) {
        await notifier.joinHost(
          mode: JoinMode.lan,
          lanUri: Uri.parse(url),
          name: p.name,
          avatarSeed: p.avatarSeed,
          avatarData: p.avatarData,
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
        actions: const [ChatButton()],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildBody(s),
                ),
              ),
            ),
            // Lets waiting players see each other's reactions before the
            // game starts.
            const Positioned.fill(child: IgnorePointer(child: EmojiOverlay())),
            const ChatOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(SessionState s) {
    if (s.connectionState == SessionConnState.connecting) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 18),
            Text(
              'Connecting…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Knocking on the host’s door',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      );
    }
    // Being removed by the host is terminal and needs its own copy — the
    // generic error card would imply a network fault and invite a retry that
    // the host is guaranteed to refuse.
    if (s.connectionState == SessionConnState.kicked) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_remove_rounded, color: cs.error, size: 48),
            const SizedBox(height: 12),
            Text(
              'Removed from the game',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '${s.errorMessage ?? 'The host removed you from this game.'}\n\n'
              'You can still host or join other games.',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                await ref.read(sessionProvider.notifier).leave();
                if (!mounted) return;
                context.go('/');
              },
              child: const Text('Back to menu'),
            ),
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
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, color: cs.primary, size: 22),
            const SizedBox(width: 8),
            Text("You're in!",
                style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 4),
        Text('Hang tight while the host sets up the board.',
            style: TextStyle(color: cs.onSurfaceVariant)),
        const SizedBox(height: 18),
        // Live view of what the host is choosing — updates as they change it.
        MatchSummary(config: s.config),
        const SizedBox(height: 18),
        Text('Players (${players.length}/4)',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: players
              .map((p) => GestureDetector(
                    onTap: () => showPlayerActions(context, player: p),
                    child: PlayerChip(
                      player: p,
                      subtitle: p.id == s.localId ? 'You' : null,
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 14, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Tap a player to block or report them.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ),
        const Spacer(),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: EmojiBar(
              onSend: (e) =>
                  ref.read(sessionProvider.notifier).sendEmoji(e),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: cs.primary),
              ),
              const SizedBox(width: 10),
              Text(
                'Waiting for host to start…',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
