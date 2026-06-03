import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../state/achievements.dart';

/// Browse every achievement and its locked/unlocked state. Personal & local —
/// reflects the unlocks earned on this device. No rewards are attached.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(achievementsProvider);
    final unlockedCount =
        kAchievements.where((a) => st.unlocked.contains(a.id)).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Achievements',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _ProgressHeader(
                  unlocked: unlockedCount,
                  total: kAchievements.length,
                ),
                const SizedBox(height: 14),
                for (final a in kAchievements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AchievementCard(
                      achievement: a,
                      unlocked: st.unlocked.contains(a.id),
                      stats: st.stats,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.unlocked, required this.total});

  final int unlocked;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final fraction = total == 0 ? 0.0 : unlocked / total;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: g.panelBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: g.panelShadow,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppPalette.amber.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.emoji_events_rounded,
                size: 26, color: AppPalette.amber),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$unlocked of $total unlocked',
                  style: GoogleFonts.fredoka(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor:
                        const AlwaysStoppedAnimation(AppPalette.amber),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.achievement,
    required this.unlocked,
    required this.stats,
  });

  final Achievement achievement;
  final bool unlocked;
  final AchievementStats stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final accent = unlocked ? AppPalette.amber : cs.onSurfaceVariant;
    final progress = unlocked ? null : achievement.progress?.call(stats);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: unlocked ? g.panel : g.panel.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? AppPalette.amber.withValues(alpha: 0.4)
              : g.panelBorder,
          width: 1.4,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: g.panelShadow,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: unlocked ? 0.16 : 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              unlocked ? achievement.icon : Icons.lock_rounded,
              size: 24,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: GoogleFonts.fredoka(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: unlocked ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  achievement.description,
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    progress,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (unlocked)
            const Icon(Icons.check_circle_rounded,
                size: 20, color: AppPalette.leaf),
        ],
      ),
    );
  }
}
