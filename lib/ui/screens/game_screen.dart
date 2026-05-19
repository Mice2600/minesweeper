import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../audio/sfx.dart';
import '../../game/engine.dart';
import '../../state/session.dart';
import '../widgets/avatar.dart';
import '../widgets/board_view.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/emoji_overlay.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  DateTime? _startedAt;
  DateTime? _lastCursor;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_startedAt != null) {
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final snap = s.snapshot;

    // Navigate to result when game ends.
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      final prevStatus = prev?.snapshot?.status;
      final nextStatus = next.snapshot?.status;
      if (prevStatus != nextStatus &&
          (nextStatus == GameStatus.won ||
              nextStatus == GameStatus.lost)) {
        ref.read(soundProvider).play(
              nextStatus == GameStatus.won ? SfxKind.win : SfxKind.mine,
            );
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!context.mounted) return;
          context.go('/result');
        });
      }
      if (nextStatus == GameStatus.playing && _startedAt == null) {
        _startedAt = DateTime.now();
      }
    });

    if (snap == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final flagsRemaining = snap.minePositions.isNotEmpty
        ? 0
        : (snap.config.mines - snap.flagsPlaced());

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            await ref.read(sessionProvider.notifier).leave();
            if (!context.mounted) return;
            context.go('/');
          },
        ),
        title: Row(
          children: [
            _StatBubble(icon: Icons.flag_rounded, value: '$flagsRemaining'),
            const SizedBox(width: 8),
            _StatBubble(
              icon: Icons.timer_outlined,
              value: _format(_elapsed),
            ),
            const SizedBox(width: 8),
            _StatBubble(
                icon: Icons.grid_4x4_rounded,
                value: '${snap.width}×${snap.height}'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: ref.watch(mutedProvider) ? 'Unmute' : 'Mute',
            onPressed: () => ref.read(mutedProvider.notifier).toggle(),
            icon: Icon(
              ref.watch(mutedProvider)
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _PlayersBar(players: snap.players, localId: s.localId),
            const SizedBox(height: 6),
            Expanded(
              child: Stack(
                children: [
                  InteractiveViewer(
                    minScale: 0.6,
                    maxScale: 3.0,
                    boundaryMargin: const EdgeInsets.all(40),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: BoardView(
                        snapshot: snap,
                        interactive:
                            snap.status == GameStatus.playing ||
                                snap.status == GameStatus.waiting,
                        onReveal: (x, y) {
                          HapticFeedback.selectionClick();
                          ref.read(soundProvider).play(SfxKind.reveal);
                          ref
                              .read(sessionProvider.notifier)
                              .sendReveal(x, y);
                        },
                        onFlag: (x, y) {
                          HapticFeedback.mediumImpact();
                          ref.read(soundProvider).play(SfxKind.flag);
                          ref
                              .read(sessionProvider.notifier)
                              .sendFlag(x, y);
                        },
                        onChord: (x, y) {
                          ref.read(soundProvider).play(SfxKind.chord);
                          ref
                              .read(sessionProvider.notifier)
                              .sendChord(x, y);
                        },
                        onCursor: _throttledCursor,
                      ),
                    ),
                  ),
                  const Positioned.fill(child: EmojiOverlay()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: EmojiBar(
                onSend: (e) =>
                    ref.read(sessionProvider.notifier).sendEmoji(e),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _throttledCursor(double nx, double ny) {
    final now = DateTime.now();
    if (_lastCursor != null &&
        now.difference(_lastCursor!).inMilliseconds < 60) {
      return;
    }
    _lastCursor = now;
    ref.read(sessionProvider.notifier).sendCursor(nx, ny);
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _StatBubble extends StatelessWidget {
  const _StatBubble({required this.icon, required this.value});
  final IconData icon;
  final String value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayersBar extends StatelessWidget {
  const _PlayersBar({required this.players, required this.localId});
  final List<dynamic> players;
  final String localId;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: players.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final p = players[i];
          final isMe = p.id == localId;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Color(p.color).withValues(alpha: isMe ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Color(p.color)
                    .withValues(alpha: isMe ? 0.7 : 0.3),
                width: isMe ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Avatar(
                  seed: p.avatarSeed,
                  label: p.name,
                  size: 30,
                  color: Color(p.color),
                ),
                const SizedBox(width: 8),
                Text(
                  isMe ? '${p.name} (you)' : p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}
