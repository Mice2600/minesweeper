import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../game/difficulty.dart';
import '../../game/engine.dart';
import '../../net/messages.dart';
import '../../state/session.dart';
import '../widgets/avatar.dart';
import '../widgets/particles.dart';
import '../widgets/pressable.dart';
import '../widgets/stats_charts.dart';

/// The payoff. Win = a celebration (confetti, victor spotlight, trophy);
/// loss = a weighty "BOOM" with the culprit called out. The story leads —
/// outcome, MVP, duration — and the charts are tucked behind a "Match stats"
/// disclosure so they never headline.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);

    // A guest must not get stranded on the end-game screen when the host
    // restarts: dropping back to `lobby` (host hit "Play again") returns them
    // to the waiting view, and `playing` (host started the new round) takes
    // them straight into the game. The host drives its own navigation from the
    // "Play again" button, so it opts out here.
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next.isHost) return;
      if (prev?.connectionState == next.connectionState) return;
      switch (next.connectionState) {
        case SessionConnState.playing:
          context.go('/game');
        case SessionConnState.lobby:
          context.go('/join');
        default:
          break;
      }
    });

    final snap = s.snapshot;
    if (snap == null) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final cs = Theme.of(context).colorScheme;
    final won = snap.status == GameStatus.won;
    final accent = won ? AppPalette.leaf : cs.error;
    final players = _sortedByReveals(snap);
    final mvp = players.isNotEmpty &&
            (snap.stats[players.first.id]?.cellsRevealed ?? 0) > 0
        ? players.first
        : null;
    final loser = snap.playerById(snap.losingPlayerId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(won: won, loser: loser, accent: accent),
                      const SizedBox(height: 18),
                      _ResultBanner(
                        won: won,
                        snap: snap,
                        mvp: mvp,
                        accent: accent,
                      )
                          .animate()
                          .fadeIn(delay: 360.ms, duration: 420.ms)
                          .slideY(begin: 0.18, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 14),
                      _AwardsRow(snap: snap, players: players)
                          .animate()
                          .fadeIn(delay: 560.ms, duration: 380.ms)
                          .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 18),
                      _StatsSection(snap: snap)
                          .animate()
                          .fadeIn(delay: 720.ms, duration: 380.ms),
                      const SizedBox(height: 22),
                      _Cta(isHost: s.isHost)
                          .animate()
                          .fadeIn(delay: 880.ms, duration: 420.ms)
                          .slideY(begin: 0.25, end: 0, curve: Curves.easeOutBack),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (won)
            const Positioned.fill(
              child: IgnorePointer(child: Confetti()),
            ),
        ],
      ),
    );
  }

}

/// Players sorted descending by cells revealed (used for MVP and the stats
/// breakdown). Single source of truth so the two consumers can't drift.
List<PlayerInfo> _sortedByReveals(GameSnapshot snap) {
  final players = [...snap.players];
  players.sort((a, b) {
    final ar = snap.stats[a.id]?.cellsRevealed ?? 0;
    final br = snap.stats[b.id]?.cellsRevealed ?? 0;
    return br.compareTo(ar);
  });
  return players;
}

// ───────────────────────────────────────── Hero ────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.won, required this.loser, required this.accent});
  final bool won;
  final PlayerInfo? loser;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final badge = _Badge(won: won, accent: accent);
    final title = Text(
      won ? 'VICTORY!' : 'BOOM!',
      textAlign: TextAlign.center,
      style: GoogleFonts.fredoka(
        fontSize: 60,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: 1,
        color: accent,
        shadows: [
          Shadow(color: accent.withValues(alpha: 0.35), blurRadius: 24),
        ],
      ),
    );

    return Column(
      children: [
        const SizedBox(height: 8),
        badge,
        const SizedBox(height: 14),
        won
            ? title
                .animate()
                .fadeIn(delay: 220.ms, duration: 360.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOutBack)
            : title
                .animate()
                .scale(
                  begin: const Offset(1.7, 1.7),
                  end: const Offset(1, 1),
                  duration: 360.ms,
                  curve: Curves.easeOutBack,
                )
                .fadeIn(duration: 200.ms)
                .then()
                .shake(hz: 5, duration: 420.ms, offset: const Offset(3, 0)),
        const SizedBox(height: 6),
        Text(
          won
              ? 'The field is clear — nice teamwork.'
              : loser != null
                  ? '${loser!.name} stepped on a mine.'
                  : 'A mine went off.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ).animate().fadeIn(delay: won ? 420.ms : 520.ms, duration: 360.ms),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.won, required this.accent});
  final bool won;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 108,
      height: 108,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            accent.withValues(alpha: 0.30),
            accent.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: 0.6), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.4),
            blurRadius: 36,
            spreadRadius: 2,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        won ? Icons.emoji_events_rounded : Icons.dangerous_rounded,
        size: 58,
        color: accent,
      ),
    );

    if (won) {
      return badge
          .animate()
          .scale(
            begin: const Offset(0.3, 0.3),
            end: const Offset(1, 1),
            duration: 600.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 200.ms)
          .then()
          .shimmer(duration: 1400.ms, color: Colors.white.withValues(alpha: 0.5));
    }
    return badge
        .animate()
        .scale(
          begin: const Offset(1.5, 1.5),
          end: const Offset(1, 1),
          duration: 320.ms,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: 160.ms);
  }
}

// ───────────────────────────────────── Result banner ───────────────────────

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.won,
    required this.snap,
    required this.mvp,
    required this.accent,
  });
  final bool won;
  final GameSnapshot snap;
  final PlayerInfo? mvp;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final mode = snap.config.mode;

    return Container(
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: g.panelShadow, blurRadius: 24, offset: const Offset(0, 12)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Ribbon header.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
            decoration: BoxDecoration(
              // Opaque stops so the white ribbon text keeps its contrast
              // regardless of the panel/background showing through.
              gradient: LinearGradient(
                colors: [accent, Color.lerp(accent, Colors.black, 0.18)!],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  won ? Icons.verified_rounded : Icons.local_fire_department_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(
                  won ? 'FIELD CLEARED' : 'MINE DETONATED',
                  style: GoogleFonts.fredoka(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                if (mvp != null) _MvpSpotlight(player: mvp!, snap: snap, accent: accent),
                if (mvp != null) const SizedBox(height: 16),
                Row(
                  children: [
                    _Fact(
                      icon: Icons.timer_outlined,
                      label: 'Time',
                      value: snap.durationMs > 0
                          ? formatMmSs(snap.durationMs)
                          : '—',
                    ),
                    _FactDivider(),
                    _Fact(
                      icon: Icons.grid_on_rounded,
                      label: 'Board',
                      value: '${snap.width}×${snap.height}',
                    ),
                    _FactDivider(),
                    _Fact(
                      icon: Icons.dangerous_outlined,
                      label: 'Mines',
                      value: '${snap.config.mines}',
                    ),
                    _FactDivider(),
                    _Fact(
                      icon: mode == GameMode.hearts
                          ? Icons.favorite_rounded
                          : Icons.bolt_rounded,
                      label: 'Mode',
                      value: mode == GameMode.hearts
                          ? '${snap.initialHearts}♥'
                          : 'Classic',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MvpSpotlight extends StatelessWidget {
  const _MvpSpotlight({
    required this.player,
    required this.snap,
    required this.accent,
  });
  final PlayerInfo player;
  final GameSnapshot snap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Color(player.color);
    final cells = snap.stats[player.id]?.cellsRevealed ?? 0;
    final solo = snap.players.length <= 1;
    return Row(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Avatar(seed: player.avatarSeed, label: player.name, size: 52, color: color),
            Positioned(
              top: -10,
              right: -6,
              child: Transform.rotate(
                angle: 0.3,
                child: Icon(Icons.workspace_premium_rounded,
                    size: 26, color: AppPalette.amber),
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                solo ? 'CLEARED BY' : 'TOP DIGGER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                player.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.fredoka(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$cells',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: accent,
                height: 1.0,
              ),
            ),
            Text(
              'cells dug',
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(height: 4),
          // Scale down rather than ellipsize so "Classic" / "120:00" / "60×40"
          // stay fully readable even in a ~50dp column on a small phone.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.jetBrainsMono(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: cs.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      height: 34,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: cs.outlineVariant.withValues(alpha: 0.6),
    );
  }
}

// ───────────────────────────────────── Awards ──────────────────────────────

class _AwardsRow extends StatelessWidget {
  const _AwardsRow({required this.snap, required this.players});
  final GameSnapshot snap;
  final List<PlayerInfo> players;

  @override
  Widget build(BuildContext context) {
    final awards = <_Award>[];

    PlayerInfo? best(int Function(PlayerStats) metric) {
      PlayerInfo? winner;
      var bestVal = 0;
      for (final p in players) {
        final v = metric(snap.stats[p.id] ?? PlayerStats());
        if (v > bestVal) {
          bestVal = v;
          winner = p;
        }
      }
      return winner;
    }

    final defuser = best((s) => s.correctFlags);
    if (defuser != null) {
      awards.add(_Award(
        icon: Icons.flag_rounded,
        label: 'Defuser',
        sub: '${snap.stats[defuser.id]!.correctFlags} flags',
        player: defuser,
      ));
    }
    final digger = best((s) => s.largestCascade);
    if (digger != null && (snap.stats[digger.id]?.largestCascade ?? 0) >= 3) {
      awards.add(_Award(
        icon: Icons.open_in_full_rounded,
        label: 'Big Dig',
        sub: '${snap.stats[digger.id]!.largestCascade} in one tap',
        player: digger,
      ));
    }
    final chorder = best((s) => s.chordMoves);
    if (chorder != null && (snap.stats[chorder.id]?.chordMoves ?? 0) >= 3) {
      awards.add(_Award(
        icon: Icons.touch_app_rounded,
        label: 'Chord Master',
        sub: '${snap.stats[chorder.id]!.chordMoves} chords',
        player: chorder,
      ));
    }

    if (awards.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: awards,
    );
  }
}

class _Award extends StatelessWidget {
  const _Award({
    required this.icon,
    required this.label,
    required this.sub,
    required this.player,
  });
  final IconData icon;
  final String label;
  final String sub;
  final PlayerInfo player;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final color = Color(player.color);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 8),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.4),
        boxShadow: [
          BoxShadow(color: g.panelShadow, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.fredoka(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              Text(
                '${player.name} · $sub',
                style: TextStyle(fontSize: 10.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────── Stats (secondary) ─────────────────────

class _StatsSection extends StatefulWidget {
  const _StatsSection({required this.snap});
  final GameSnapshot snap;
  @override
  State<_StatsSection> createState() => _StatsSectionState();
}

class _StatsSectionState extends State<_StatsSection> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final snap = widget.snap;

    return Container(
      decoration: BoxDecoration(
        color: g.panel.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: g.panelBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          PressableScale(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.insights_rounded, size: 20, color: cs.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    'Match stats',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  Text(
                    _open ? 'Hide' : 'Show',
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ChartCard(
                    title: 'Share of board uncovered',
                    child: RevealShareDonut(snap: snap),
                  ),
                  const SizedBox(height: 12),
                  _ChartCard(
                    title: 'Per-player totals',
                    child: PerPlayerBars(snap: snap),
                  ),
                  const SizedBox(height: 12),
                  _ChartCard(
                    title: 'Reveals over time',
                    child: CumulativeRevealsLine(snap: snap),
                  ),
                  const SizedBox(height: 16),
                  ..._sortedByReveals(snap).map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PlayerDetailCard(
                        player: p,
                        stats: snap.stats[p.id] ?? PlayerStats(),
                        durationMs: snap.durationMs,
                        isLoser: snap.losingPlayerId == p.id,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeOut,
          ),
        ],
      ),
    );
  }

}

// ─────────────────────────────────────── CTA ───────────────────────────────

class _Cta extends ConsumerWidget {
  const _Cta({required this.isHost});
  final bool isHost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isHost)
          SizedBox(
            height: 58,
            child: FilledButton.icon(
              onPressed: () {
                ref.read(sessionProvider.notifier).sendRestart();
                context.go('/host');
              },
              style: FilledButton.styleFrom(
                textStyle: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              icon: const Icon(Icons.replay_rounded, size: 24),
              label: const Text('Play again'),
            ),
          )
        else
          const _WaitingForHost(),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () async {
            await ref.read(sessionProvider.notifier).leave();
            if (!context.mounted) return;
            context.go('/');
          },
          icon: Icon(Icons.home_rounded, size: 18, color: cs.onSurfaceVariant),
          label: const Text('Back to home'),
        ),
      ],
    );
  }
}

class _WaitingForHost extends StatelessWidget {
  const _WaitingForHost();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: g.panelBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .fadeIn(delay: (i * 200).ms, duration: 400.ms)
                  .scaleXY(begin: 0.6, end: 1.0, duration: 400.ms),
            ),
          const SizedBox(width: 10),
          Text(
            'Waiting for the host to start a rematch…',
            style: TextStyle(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────── Reused detail cards ───────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _PlayerDetailCard extends StatelessWidget {
  const _PlayerDetailCard({
    required this.player,
    required this.stats,
    required this.durationMs,
    required this.isLoser,
  });

  final PlayerInfo player;
  final PlayerStats stats;
  final int durationMs;
  final bool isLoser;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Color(player.color);
    final totalFlags = stats.correctFlags + stats.incorrectFlags;
    final accuracy =
        totalFlags == 0 ? null : (stats.correctFlags / totalFlags) * 100;
    final cpm = durationMs > 0
        ? (stats.clicks / (durationMs / 60000)).toStringAsFixed(1)
        : '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(
                seed: player.avatarSeed,
                label: player.name,
                size: 36,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    if (player.isHost) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.shield_rounded, size: 14, color: color),
                    ],
                    if (isLoser) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.dangerous_rounded, size: 16, color: cs.error),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _Stat(label: 'Cells', value: '${stats.cellsRevealed}'),
              _Stat(
                label: 'Flags',
                value:
                    '${stats.correctFlags}/${stats.correctFlags + stats.incorrectFlags}',
                sub: accuracy == null
                    ? null
                    : '${accuracy.toStringAsFixed(0)}%',
              ),
              _Stat(
                label: 'Mines hit',
                value: '${stats.minesHit}',
                tint: stats.minesHit > 0 ? cs.error : null,
              ),
              _Stat(label: 'Chords', value: '${stats.chordMoves}'),
              _Stat(label: 'Best click', value: '${stats.largestCascade}'),
              _Stat(label: 'CPM', value: cpm),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.sub,
    this.tint,
  });

  final String label;
  final String value;
  final String? sub;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            color: cs.onSurfaceVariant,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: tint ?? cs.onSurface,
              ),
            ),
            if (sub != null) ...[
              const SizedBox(width: 4),
              Text(
                sub!,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
