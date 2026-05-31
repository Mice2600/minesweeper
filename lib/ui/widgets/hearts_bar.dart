import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../net/messages.dart';
import 'avatar.dart';

/// Displays N hearts; the first (current..total) are filled and red, the
/// remaining are outlined and dim. The most recently lost heart shakes briefly.
///
/// Each broken heart shows a small avatar badge in the bottom-right corner
/// identifying which player lost it. [heartsLostBy] is in chronological order
/// (index 0 = first heart lost); its length must equal `total - current`.
class HeartsBar extends StatelessWidget {
  const HeartsBar({
    super.key,
    required this.current,
    required this.total,
    this.heartsLostBy = const [],
    this.players = const [],
  });

  final int current;
  final int total;
  final List<String> heartsLostBy;
  final List<PlayerInfo> players;

  PlayerInfo? _playerById(String id) {
    for (final p in players) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Heart at bar-index [i] corresponds to a "lost" slot when `i >= current`.
  /// We render the most-recently lost heart at index `current` (the one that
  /// shakes), so newer losses are leftmost within the broken-hearts cluster.
  PlayerInfo? _lostBy(int i) {
    if (i < current) return null;
    final lostIndex = total - 1 - i;
    if (lostIndex < 0 || lostIndex >= heartsLostBy.length) return null;
    return _playerById(heartsLostBy[lostIndex]);
  }

  @override
  Widget build(BuildContext context) {
    if (total <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < total; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Heart(
              key: ValueKey('h$i'),
              filled: i < current,
              isLastLost: i == current,
              lostBy: _lostBy(i),
            ),
          ),
      ],
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({
    super.key,
    required this.filled,
    required this.isLastLost,
    required this.lostBy,
  });
  final bool filled;
  final bool isLastLost;
  final PlayerInfo? lostBy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tint = lostBy != null ? Color(lostBy!.color) : null;
    final color = filled
        ? const Color(0xFFE53935)
        : (tint ?? cs.outlineVariant);
    final icon = Icon(
      filled ? Icons.favorite_rounded : Icons.heart_broken_rounded,
      color: color,
      size: 36,
    );

    Widget content = icon;
    if (!filled && lostBy != null) {
      content = SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: Center(child: icon)),
            Positioned(
              right: 0,
              bottom: 0,
              child: _AttributionBadge(player: lostBy!),
            ),
          ],
        ),
      );
    }

    if (isLastLost && !filled) {
      // Shake on heart loss. (No tint overlay — it would mask the player
      // color the icon is already painted in.)
      return content
          .animate(key: ValueKey(isLastLost))
          .shake(
            duration: 600.ms,
            hz: 6,
            curve: Curves.easeOut,
            offset: const Offset(2, 0),
          );
    }
    return content;
  }
}

class _AttributionBadge extends StatelessWidget {
  const _AttributionBadge({required this.player});
  final PlayerInfo player;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: cs.surface, width: 1.5),
      ),
      child: Avatar(
        seed: player.avatarSeed,
        label: player.name,
        size: 18,
        color: Color(player.color),
      ),
    );
  }
}
