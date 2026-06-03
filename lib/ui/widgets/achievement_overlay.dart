import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../audio/sfx.dart';
import '../../game/engine.dart';
import '../../state/achievements.dart';
import '../../state/session.dart';

/// Global, always-mounted overlay (wired into `MaterialApp.builder`). Two jobs:
///
/// 1. Watch the session for a finished game and evaluate achievements **once**
///    (the notifier dedupes by `endedAtMs`, so a re-fire is harmless). One
///    persistent listener for the whole app means a toast triggered on the
///    game screen survives the auto-navigation to `/result`.
/// 2. Render the queued "achievement unlocked" toasts, stacked at the top.
///
/// Lives as a child of a [Stack] in the app shell, so its root must be a
/// [Positioned]/inert widget that never blocks input to the screen below.
class AchievementOverlay extends ConsumerWidget {
  const AchievementOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fire achievement evaluation when a match ends.
    ref.listen<({GameStatus? status, int endedAtMs, String localId})>(
      sessionProvider.select((s) => (
            status: s.snapshot?.status,
            endedAtMs: s.snapshot?.endedAtMs ?? 0,
            localId: s.localId,
          )),
      (prev, next) {
        if (next.status != GameStatus.won && next.status != GameStatus.lost) {
          return;
        }
        final snap = ref.read(sessionProvider).snapshot;
        if (snap == null) return;
        ref
            .read(achievementsProvider.notifier)
            .recordGameEnd(snap, next.localId);
      },
    );

    // Subtle ding whenever a new toast appears.
    ref.listen<int>(
      achievementsProvider.select((s) => s.pending.length),
      (prev, next) {
        if (next > (prev ?? 0)) ref.read(soundProvider).play(SfxKind.chat);
      },
    );

    final pending = ref.watch(achievementsProvider.select((s) => s.pending));
    if (pending.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: 8,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ToastCard(
                  key: ValueKey(t.id),
                  toast: t,
                  onTap: () => ref
                      .read(achievementsProvider.notifier)
                      .dismissToast(t.id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({super.key, required this.toast, required this.onTap});

  final AchievementToast toast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: g.panel,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: AppPalette.amber.withValues(alpha: 0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: g.panelShadow,
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppPalette.amber.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(toast.icon, size: 20, color: AppPalette.amber),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ACHIEVEMENT UNLOCKED',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    toast.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.fredoka(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 240.ms)
        .slideY(begin: -0.3, end: 0, curve: Curves.easeOutCubic);
  }
}
