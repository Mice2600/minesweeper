import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
import '../widgets/connection_overlay.dart';
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
  DateTime? _startedAt;
  DateTime? _lastCursor;
  int _lastCursorQx = -1;
  int _lastCursorQy = -1;

  bool _wakelockEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncWakelock(ref.read(sessionProvider).snapshot?.status);
    });
  }

  @override
  void dispose() {
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
      }
      if (prevStatus != nextStatus) _syncWakelock(nextStatus);
    });

    // Start the timer on the first uncovered cell, not on game-start: the
    // host engine doesn't lock in mine placement (and therefore the run's
    // "real" start time) until the first reveal, so matching the UI clock to
    // that moment keeps host display and authoritative `durationMs` aligned.
    // Mutate the fields directly (no setState) — the periodic ticker will
    // pick the new value up on its next fire.
    final status = snap?.status;
    final firstRevealLanded =
        snap != null && snap.cells.any((c) => c != -2);
    if (status == GameStatus.playing &&
        firstRevealLanded &&
        _startedAt == null) {
      _startedAt = DateTime.now();
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

    final gameEnded = snap.status == GameStatus.won ||
        snap.status == GameStatus.lost;

    return Scaffold(
      floatingActionButton: gameEnded
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/result'),
              icon: const Icon(Icons.bar_chart_rounded),
              label: const Text('See results'),
            )
          : null,
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
            _ElapsedStatBubble(startedAt: _startedAt),
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
        child: Stack(
          children: [
            Column(
          children: [
            _ConnectionBanner(state: s.connectionState),
            if (snap.config.mode == GameMode.hearts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: HeartsBar(
                  current: snap.hearts,
                  total: snap.initialHearts,
                  heartsLostBy: snap.heartsLostBy,
                  players: snap.players,
                ),
              ),
            _PlayersBar(players: snap.players, localId: s.localId),
            const SizedBox(height: 6),
            Expanded(
              child: ScreenShake(
                triggerId: snap.lastExplosion?.id ?? 0,
                magnitude: _shakeMagnitude(snap.lastExplosion?.centers.length ?? 0),
                child: Builder(
                  builder: (ctx) {
                    const cellSize = 40.0;
                    final boardW = cellSize * snap.width;
                    final boardH = cellSize * snap.height;

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
                        _BoardCamera(
                          boardW: boardW,
                          boardH: boardH,
                          child: board,
                        ),
                        const Positioned.fill(child: EmojiOverlay()),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (gameEnded)
              _GameOverHint(won: snap.status == GameStatus.won),
            Padding(
              padding: const EdgeInsets.all(12),
              child: EmojiBar(
                onSend: (e) =>
                    ref.read(sessionProvider.notifier).sendEmoji(e),
              ),
            ),
          ],
            ),
            Positioned.fill(
              child: ConnectionOverlay(
                state: s.connectionState,
                onLeave: () async {
                  await ref.read(sessionProvider.notifier).leave();
                  if (!context.mounted) return;
                  context.go('/');
                },
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
    // Quantize to 0..1000 (3 decimal places of resolution). Drops ~30% of the
    // JSON payload and lets us dedupe frames that haven't actually moved.
    final qx = (nx.clamp(0.0, 1.0) * 1000).round();
    final qy = (ny.clamp(0.0, 1.0) * 1000).round();
    if (qx == _lastCursorQx && qy == _lastCursorQy) return;

    final now = DateTime.now();
    // 100 ms (~10 Hz). Smoothness comes from client-side interpolation in
    // [BoardView]; sending more often just floods the relay without visible
    // gain.
    if (_lastCursor != null &&
        now.difference(_lastCursor!).inMilliseconds < 100) {
      return;
    }
    _lastCursor = now;
    _lastCursorQx = qx;
    _lastCursorQy = qy;
    ref.read(sessionProvider.notifier).sendCursor(qx / 1000, qy / 1000);
  }

}

String _format(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$m:$s';
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

/// Placeholder. The previous thin banner has been superseded by
/// [ConnectionOverlay] which dims/blurs the whole board for the same states.
/// Kept as a zero-size widget so the existing layout slot stays untouched.
class _ConnectionBanner extends StatelessWidget {
  const _ConnectionBanner({required this.state});
  final SessionConnState state;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _GameOverHint extends StatelessWidget {
  const _GameOverHint({required this.won});
  final bool won;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = won ? cs.primary : cs.error;
    final text = won
        ? 'All clear! Look around, then see results.'
        : 'Mine hit. Look around, then see results.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            won ? Icons.celebration_rounded : Icons.warning_amber_rounded,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Owns its own 200 ms timer and rebuilds only the timer bubble — so a clock
/// tick doesn't drag the whole BoardView (1000+ cells) through a rebuild.
class _ElapsedStatBubble extends StatefulWidget {
  const _ElapsedStatBubble({required this.startedAt});
  final DateTime? startedAt;

  @override
  State<_ElapsedStatBubble> createState() => _ElapsedStatBubbleState();
}

class _ElapsedStatBubbleState extends State<_ElapsedStatBubble> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.startedAt != null) {
      _elapsed = DateTime.now().difference(widget.startedAt!);
      _ensureTicker();
    }
  }

  @override
  void didUpdateWidget(_ElapsedStatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.startedAt == oldWidget.startedAt) return;
    if (widget.startedAt == null) {
      // Game ended: freeze the last elapsed value, stop ticking.
      _ticker?.cancel();
      _ticker = null;
    } else {
      _elapsed = DateTime.now().difference(widget.startedAt!);
      _ensureTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _ensureTicker() {
    if (_ticker != null) return;
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      final start = widget.startedAt;
      if (start == null) return;
      setState(() => _elapsed = DateTime.now().difference(start));
    });
  }

  @override
  Widget build(BuildContext context) {
    return _StatBubble(
      icon: Icons.timer_outlined,
      value: _format(_elapsed),
    );
  }
}

class _BoardCamera extends StatefulWidget {
  const _BoardCamera({
    required this.boardW,
    required this.boardH,
    required this.child,
  });

  final double boardW;
  final double boardH;
  final Widget child;

  @override
  State<_BoardCamera> createState() => _BoardCameraState();
}

class _BoardCameraState extends State<_BoardCamera>
    with SingleTickerProviderStateMixin {
  static const double _minScale = 0.1;
  static const double _maxScale = 8.0;

  final TransformationController _controller = TransformationController();
  late final AnimationController _zoomAnim;
  Matrix4 _zoomBegin = Matrix4.identity();
  Matrix4 _zoomEnd = Matrix4.identity();
  double _centeredW = -1;
  double _centeredH = -1;
  bool _centerScheduled = false;

  @override
  void initState() {
    super.initState();
    _zoomAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    )..addListener(_onZoomTick);
  }

  @override
  void didUpdateWidget(_BoardCamera oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.boardW != widget.boardW ||
        oldWidget.boardH != widget.boardH) {
      // Board dimensions changed (new game / different difficulty): re-center
      // on the next frame once we know the viewport size.
      _centerScheduled = false;
    }
  }

  @override
  void dispose() {
    _zoomAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onZoomTick() {
    final t = Curves.easeOut.transform(_zoomAnim.value);
    _controller.value = Matrix4Tween(begin: _zoomBegin, end: _zoomEnd)
        .transform(t);
  }

  void _centerIfBoardChanged(double viewportW, double viewportH) {
    if (_centeredW == widget.boardW && _centeredH == widget.boardH) return;
    _centeredW = widget.boardW;
    _centeredH = widget.boardH;
    final tx = (viewportW - widget.boardW) / 2;
    final ty = (viewportH - widget.boardH) / 2;
    _controller.value = Matrix4.translationValues(tx, ty, 0);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta.dy;
    if (delta == 0) return;

    // If a zoom is already in flight, compose from its target so consecutive
    // ticks chain smoothly instead of fighting the previous animation.
    final base = _zoomAnim.isAnimating ? _zoomEnd : _controller.value;
    final currentScale = base.getMaxScaleOnAxis();

    final scaleChange = math.exp(-delta / 350);
    final targetScale =
        (currentScale * scaleChange).clamp(_minScale, _maxScale);
    if (targetScale == currentScale) return;
    final actualChange = targetScale / currentScale;

    // Zoom around the screen point under the cursor. Matrix4's chained
    // `translate`/`scale` post-multiply, so to apply T(F)·S(s)·T(-F) AFTER
    // `base` (the screen-space pivot) we build the zoom on identity and
    // pre-multiply with `base` via `.multiplied(base)`.
    final focal = event.localPosition;
    final zoom = Matrix4.identity()
      ..translate(focal.dx, focal.dy)
      ..scale(actualChange)
      ..translate(-focal.dx, -focal.dy);
    final newMatrix = zoom.multiplied(base);

    _zoomBegin = Matrix4.copy(_controller.value);
    _zoomEnd = newMatrix;
    _zoomAnim.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, bc) {
        if (!_centerScheduled) {
          _centerScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _centerIfBoardChanged(bc.maxWidth, bc.maxHeight);
          });
        }
        return Listener(
          onPointerSignal: _onPointerSignal,
          child: InteractiveViewer(
            transformationController: _controller,
            boundaryMargin: const EdgeInsets.all(double.infinity),
            minScale: _minScale,
            maxScale: _maxScale,
            // Disable InteractiveViewer's own scroll-wheel zoom; the outer
            // Listener handles it with a smooth animation.
            scaleFactor: 1e9,
            constrained: false,
            child: SizedBox(
              width: widget.boardW,
              height: widget.boardH,
              child: RepaintBoundary(child: widget.child),
            ),
          ),
        );
      },
    );
  }
}
