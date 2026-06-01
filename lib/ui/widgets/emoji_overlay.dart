import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/session.dart';
import 'emoji_bar.dart' show emojiFontFallback;

class EmojiOverlay extends ConsumerWidget {
  const EmojiOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bursts = ref.watch(emojiBurstProvider);
    final snap = ref.watch(sessionProvider).snapshot;
    if (bursts.isEmpty || snap == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: [
          for (final b in bursts)
            _BurstWidget(
              key: ValueKey(b.id),
              emoji: b.code,
              playerName: snap.playerById(b.playerId)?.name ?? '',
            ),
        ],
      ),
    );
  }
}

class _BurstWidget extends StatelessWidget {
  const _BurstWidget({super.key, required this.emoji, required this.playerName});
  final String emoji;
  final String playerName;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 56,
                fontFamilyFallback: emojiFontFallback,
              ),
            ),
            Text(playerName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        )
            .animate()
            .fadeIn(duration: 150.ms)
            .moveY(begin: 40, end: -40, duration: 1500.ms, curve: Curves.easeOut)
            .fadeOut(delay: 1100.ms, duration: 400.ms),
      ),
    );
  }
}
