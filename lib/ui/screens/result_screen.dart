import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../game/engine.dart';
import '../../state/session.dart';
import '../widgets/avatar.dart';

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
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    won
                        ? Icons.celebration_rounded
                        : Icons.dangerous_rounded,
                    size: 96,
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
                    const SizedBox(height: 4),
                    Text(
                      '${loser.name} hit a mine',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('Scoreboard',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ..._scoreboard(snap),
                  const SizedBox(height: 32),
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

  List<Widget> _scoreboard(GameSnapshot snap) {
    final players = [...snap.players];
    players.sort((a, b) {
      final ar = snap.stats[a.id]?.cellsRevealed ?? 0;
      final br = snap.stats[b.id]?.cellsRevealed ?? 0;
      return br.compareTo(ar);
    });
    return players.map((p) {
      final stat = snap.stats[p.id];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Avatar(
                seed: p.avatarSeed,
                label: p.name,
                size: 32,
                color: Color(p.color)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(p.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text(
              '${stat?.cellsRevealed ?? 0} revealed · ${stat?.flagsPlaced ?? 0} flags',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }).toList();
  }
}
