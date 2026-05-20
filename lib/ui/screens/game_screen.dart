import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../audio/sfx.dart';
import '../../game/difficulty.dart';
import '../../game/engine.dart';
import '../../state/session.dart';
import '../widgets/avatar.dart';
import '../widgets/board_view.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/emoji_overlay.dart';
import '../widgets/hearts_bar.dart';
import '../widgets/screen_shake.dart';

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

  bool _wakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_startedAt != null) {
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncWakelock(ref.read(sessionProvider).snapshot?.status);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Always release on teardown, regardless of the cached flag, so we don't
    // strand the device with the screen pinned on if state got out of sync.
    WakelockPlus.disable();
    _wakelockEnabled = false;
    super.dispose();
  }

  /// Keeps the display on while a game is actively being played so neither
  /// the host nor a guest gets dropped by the OS putting the device to sleep.
  /// Releases the lock once the round is over or the player leaves.
  void _syncWakelock(GameStatus? status) {
    final shouldHold = status == GameStatus.playing;
    if (shouldHold == _wakelockEnabled) return;
    _wakelockEnabled = shouldHold;
    if (shouldHold) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final snap = s.snapshot;

    // Navigate to result when game ends.
    ref.listen<SessionState>(sessionProvider, (prev, next) {
      final prevStatus = prev?.snapshot?.status;
      final nextStatus = next.snapshot?.status;
      final prevHearts = prev?.snapshot?.hearts ?? -1;
      final nextHearts = next.snapshot?.hearts ?? -1;
      // Heart-loss explosion sound + haptic kick (Hearts mode).
      if (prev?.snapshot != null &&
          nextHearts >= 0 &&
          nextHearts < prevHearts) {
        ref.read(soundProvider).play(SfxKind.mine);
        final chainLen = next.snapshot?.lastExplosion?.centers.length ?? 1;
        HapticFeedback.heavyImpact();
        // Extra kicks for long chains so the device feels the chain.
        for (var k = 1; k < chainLen && k < 4; k++) {
          Future.delayed(Duration(milliseconds: 80 * k), () {
            HapticFeedback.mediumImpact();
          });
        }
      }
      if (prevStatus != nextStatus &&
          (nextStatus == GameStatus.won ||
              nextStatus == GameStatus.lost)) {
        ref.read(soundProvider).play(
              nextStatus == GameStatus.won ? SfxKind.win : SfxKind.mine,
            );
        Future.delayed(const Duration(milliseconds: 900), () {
          if (!context.mounted) return;
          context.go('/result');
        });
      }
      if (prevStatus != nextStatus) _syncWakelock(nextStatus);
    });

    // Drive the timer off the current status rather than transitions: if we
    // entered the screen with the game already running (common on guests),
    // the transition was missed but the status is correct, so we still start.
    // Mutate the fields directly (no setState) — the periodic ticker will
    // pick the new value up on its next fire.
    final status = snap?.status;
    if (status == GameStatus.playing && _startedAt == null) {
      _startedAt = DateTime.now();
      _elapsed = Duration.zero;
    } else if (status != GameStatus.playing && _startedAt != null) {
      _startedAt = null;
    }

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
            _ConnectionBanner(state: s.connectionState),
            if (snap.config.mode == GameMode.hearts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: HeartsBar(
                  current: snap.hearts,
                  total: snap.initialHearts,
                ),
              ),
            _PlayersBar(players: snap.players, localId: s.localId),
            const SizedBox(height: 6),
            Expanded(
              child: ScreenShake(
                triggerId: snap.lastExplosion?.id ?? 0,
                magnitude: _shakeMagnitude(snap.lastExplosion?.centers.length ?? 0),
                child: LayoutBuilder(
                  builder: (ctx, bc) {
                    const pad = 8.0;
                    final maxW = math.max(0.0, bc.maxWidth - pad * 2);
                    final maxH = math.max(0.0, bc.maxHeight - pad * 2);
                    final fit =
                        math.min(maxW / snap.width, maxH / snap.height);
                    // Use the natural fit when the board is small/balanced
                    // enough. Force a tappable minimum on dense boards even
                    // if that overflows width — InteractiveViewer pans.
                    final cellSize = math
                        .max(fit, 22.0)
                        .clamp(22.0, 64.0)
                        .floorToDouble();
                    final boardW = cellSize * snap.width;
                    final boardH = cellSize * snap.height;
                    final overflows = boardW > maxW || boardH > maxH;

                    final board = BoardView(
                      snapshot: snap,
                      cellSize: cellSize,
                      interactive: snap.status == GameStatus.playing ||
                          snap.status == GameStatus.waiting,
                      onReveal: (x, y) {
                        HapticFeedback.selectionClick();
                        ref.read(soundProvider).play(SfxKind.reveal);
                        ref.read(sessionProvider.notifier).sendReveal(x, y);
                      },
                      onFlag: (x, y) {
                        HapticFeedback.mediumImpact();
                        ref.read(soundProvider).play(SfxKind.flag);
                        ref.read(sessionProvider.notifier).sendFlag(x, y);
                      },
                      onChord: (x, y) {
                        ref.read(soundProvider).play(SfxKind.chord);
                        ref.read(sessionProvider.notifier).sendChord(x, y);
                      },
                      onCursor: _throttledCursor,
                      onCursorLeave: () =>
                          ref.read(sessionProvider.notifier).clearCursor(),
                    );

                    return Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(pad),
                          child: overflows
                              ? InteractiveViewer(
                                  minScale: 1.0,
                                  maxScale: 4.0,
                                  boundaryMargin: EdgeInsets.zero,
                                  constrained: false,
                                  child: SizedBox(
                                    width: boardW,
                                    height: boardH,
                                    child: board,
                                  ),
                                )
                              : Align(
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: boardW,
                                    height: boardH,
                                    child: InteractiveViewer(
                                      minScale: 1.0,
                                      maxScale: 4.0,
                                      boundaryMargin: EdgeInsets.zero,
                                      child: board,
                                    ),
                                  ),
                                ),
                        ),
                        const Positioned.fill(child: EmojiOverlay()),
                      ],
                    );
                  },
                ),
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

  double _shakeMagnitude(int chainLength) {
    if (chainLength <= 0) return 0;
    // Base 6px for one mine, +3.5px per extra mine in the chain, capped at 28.
    return (6 + (chainLength - 1) * 3.5).clamp(0, 28).toDouble();
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
          final offline = p.isOffline == true;
          return Opacity(
            opacity: offline ? 0.55 : 1.0,
            child: Container(
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
                  if (offline) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 14,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                  const SizedBox(width: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Thin bar that shows above the players list whenever the local connection
/// is not in a healthy steady state. Stays out of the way during normal play.
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.state});
  final SessionConnState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, bg, fg, icon) = switch (state) {
      SessionConnState.reconnecting => (
          'Reconnecting…',
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
          Icons.wifi_protected_setup_rounded,
        ),
      SessionConnState.disconnected => (
          'Disconnected from host',
          cs.errorContainer,
          cs.onErrorContainer,
          Icons.wifi_off_rounded,
        ),
      _ => (null, null, null, null),
    };
    if (label == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state == SessionConnState.reconnecting) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(fg),
              ),
            ),
            const SizedBox(width: 8),
          ] else if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
