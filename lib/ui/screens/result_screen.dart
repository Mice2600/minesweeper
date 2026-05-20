import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/engine.dart';
import '../../net/messages.dart';
import '../../state/session.dart';
import '../widgets/avatar.dart';
import '../widgets/stats_charts.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionProvider);
    final snap = s.snapshot;
    final cs = Theme.of(context).colorScheme;
    if (snap == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final won = snap.status == GameStatus.won;
    final loser = snap.playerById(snap.losingPlayerId);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(won: won, loser: loser, durationMs: snap.durationMs),
                  const SizedBox(height: 24),
                  _ChartCard(
                    title: 'Share of board uncovered',
                    child: RevealShareDonut(snap: snap),
                  ),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: 'Per-player totals',
                    child: PerPlayerBars(snap: snap),
                  ),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: 'Reveals over time',
                    child: CumulativeRevealsLine(snap: snap),
                  ),
                  const SizedBox(height: 24),
                  Text('Players',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  ..._sortedPlayers(snap).map(
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
                  const SizedBox(height: 24),
                  if (s.isHost)
                    FilledButton.icon(
                      onPressed: () {
                        ref.read(sessionProvider.notifier).sendRestart();
                        context.go('/host');
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Play again'),
                    )
                  else
                    Text(
                      'Waiting for host…',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await ref.read(sessionProvider.notifier).leave();
                      if (!context.mounted) return;
                      context.go('/');
                    },
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<PlayerInfo> _sortedPlayers(GameSnapshot snap) {
    final players = [...snap.players];
    players.sort((a, b) {
      final ar = snap.stats[a.id]?.cellsRevealed ?? 0;
      final br = snap.stats[b.id]?.cellsRevealed ?? 0;
      return br.compareTo(ar);
    });
    return players;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.won,
    required this.loser,
    required this.durationMs,
  });

  final bool won;
  final PlayerInfo? loser;
  final int durationMs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(
          won ? Icons.celebration_rounded : Icons.dangerous_rounded,
          size: 88,
          color: won ? Colors.green : cs.error,
        )
            .animate()
            .scale(
              begin: const Offset(0.5, 0.5),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(),
        const SizedBox(height: 8),
        Text(
          won ? 'You won!' : 'Boom!',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .displaySmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (!won && loser != null) ...[
          const SizedBox(height: 2),
          Text(
            '${loser!.name} hit a mine',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
        if (durationMs > 0) ...[
          const SizedBox(height: 4),
          Text(
            'Duration · ${formatMmSs(durationMs)}',
            textAlign: TextAlign.center,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

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
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
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
                      Icon(Icons.dangerous_rounded,
                          size: 16, color: cs.error),
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
              _Stat(
                label: 'Best click',
                value: '${stats.largestCascade}',
              ),
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
