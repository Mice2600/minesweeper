import 'package:flutter/material.dart';

import '../../net/messages.dart';
import 'avatar.dart';

class PlayerChip extends StatelessWidget {
  const PlayerChip({
    super.key,
    required this.player,
    this.subtitle,
    this.trailing,
    this.dense = false,
  });

  final PlayerInfo player;
  final String? subtitle;
  final Widget? trailing;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final color = Color(player.color);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: dense ? 10 : 14, vertical: dense ? 8 : 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(dense ? 14 : 18),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Avatar(
            seed: player.avatarSeed,
            label: player.name,
            avatarData: player.avatarData,
            size: dense ? 28 : 36,
            color: color,
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    player.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: dense ? 13 : 15,
                    ),
                  ),
                  if (player.isHost) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.shield_rounded, size: 14, color: color),
                  ],
                ],
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            trailing!,
          ],
        ],
      ),
    );
  }
}
