import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/theme.dart';
import '../../audio/sfx.dart';
import '../../game/difficulty.dart';
import '../../game/engine.dart';
import '../../net/messages.dart';
import '../../state/moderation.dart';
import '../../state/session.dart';
import '../../state/skin.dart';
import '../widgets/avatar.dart';
import '../widgets/board_view.dart';
import '../widgets/chat_button.dart';
import '../widgets/chat_overlay.dart';
import '../widgets/connection_overlay.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/emoji_overlay.dart';
import '../widgets/hearts_bar.dart';
import '../widgets/moderation_listener.dart';
import '../widgets/player_actions.dart';
import '../widgets/how_to_play.dart';
import '../widgets/particles.dart';
import '../widgets/screen_shake.dart';
import '../widgets/skin_picker.dart';

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

      // Guest only: the host restarted the round, so the finished board drops
      // back to `waiting`. Leave the stale game-over board and wait in the
      // lobby view — the join screen forwards us into the new game once the
      // host starts it.
      if (!next.isHost &&
          (prevStatus == GameStatus.won || prevStatus == GameStatus.lost) &&
          nextStatus == GameStatus.waiting) {
        context.go('/join');
      }
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

    final won = snap.status == GameStatus.won;

    final skin = ref.watch(boardSkinProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            await ref.read(sessionProvider.notifier).leave();
            if (!context.mounted) return;
            context.go('/');
          },
        ),
        actions: [
          const ChatButton(),
          IconButton(
            tooltip: 'Board skin',
            onPressed: () => showSkinPicker(context, ref),
            icon: const Icon(Icons.palette_outlined),
          ),
          IconButton(
            tooltip: 'How to play',
            onPressed: () => showHowToPlay(context),
            icon: const Icon(Icons.help_outline_rounded),
          ),
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
            _HudBar(
              flagsRemaining: flagsRemaining,
              startedAt: _startedAt,
              boardLabel: '${snap.width}×${snap.height}',
            ),
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
                      skin: skin,
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
            if (!gameEnded && !firstRevealLanded) const _CoachHint(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: gameEnded
                  // Side-by-side so the results CTA is always visible and
                  // never floats over the emoji bar (notably in landscape).
                  ? Row(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: EmojiBar(
                              onSend: (e) => ref
                                  .read(sessionProvider.notifier)
                                  .sendEmoji(e),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _SeeResultsButton(
                          won: won,
                          onTap: () => context.go('/result'),
                        ),
                      ],
                    )
                  : EmojiBar(
                      onSend: (e) =>
                          ref.read(sessionProvider.notifier).sendEmoji(e),
                    ),
            ),
          ],
            ),
            if (gameEnded && won)
              const Positioned.fill(child: IgnorePointer(child: Confetti())),
            Positioned.fill(
              child: ConnectionOverlay(
                state: s.connectionState,
                message: s.errorMessage,
                onLeave: () async {
                  await ref.read(sessionProvider.notifier).leave();
                  if (!context.mounted) return;
                  context.go('/');
                },
              ),
            ),
            const ChatOverlay(),
            // Surfaces incoming player reports to the host mid-match.
            const ModerationListener(),
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

/// Full-width in-game HUD: mine counter, a prominent timer, and the board
/// size. Lives in the body (not the cramped app bar) so the stats — the timer
/// especially — are big and legible in both portrait and landscape.
class _HudBar extends StatelessWidget {
  const _HudBar({
    required this.flagsRemaining,
    required this.startedAt,
    required this.boardLabel,
  });
  final int flagsRemaining;
  final DateTime? startedAt;
  final String boardLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StatBubble(
            icon: Icons.flag_rounded,
            value: '$flagsRemaining',
            tint: cs.secondary,
          ),
          const SizedBox(width: 10),
          // The hero stat — big and accented.
          _ElapsedStatBubble(startedAt: startedAt, big: true),
          const SizedBox(width: 10),
          _StatBubble(icon: Icons.grid_4x4_rounded, value: boardLabel),
        ],
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  const _StatBubble({
    required this.icon,
    required this.value,
    this.tint,
    this.big = false,
  });
  final IconData icon;
  final String value;
  final Color? tint;
  final bool big;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final accent = tint ?? cs.onSurfaceVariant;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: big ? 16 : 11, vertical: big ? 9 : 7),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(big ? 16 : 13),
        border: Border.all(
          color: big ? accent.withValues(alpha: 0.55) : g.panelBorder,
          width: big ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: g.panelShadow,
              blurRadius: big ? 12 : 8,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: big ? 22 : 16, color: accent),
          SizedBox(width: big ? 9 : 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w800,
              fontSize: big ? 26 : 15,
              height: 1.0,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// The prominent end-of-round CTA. Sits inline next to the emoji bar so it is
/// always visible and never floats over it.
class _SeeResultsButton extends StatelessWidget {
  const _SeeResultsButton({required this.won, required this.onTap});
  final bool won;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = won ? AppPalette.leaf : cs.secondary;
    final fg = won ? Colors.white : cs.onSecondary;
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: fg,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      icon: const Icon(Icons.emoji_events_rounded, size: 20),
      label: Text(won ? 'See your win' : 'See results'),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 1, end: 1.04, duration: 900.ms, curve: Curves.easeInOut);
  }
}

/// A gentle first-timer nudge shown until the first square is dug. Tells a new
/// player exactly what to do without a wall of text.
class _CoachHint extends StatelessWidget {
  const _CoachHint();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: g.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Tap any square to start digging · long-press to flag',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 300.ms)
          .then()
          .scaleXY(begin: 1, end: 1.02, duration: 1100.ms, curve: Curves.easeInOut),
    );
  }
}

/// Horizontal roster shown above the board. Each chip is also the in-game
/// entry point to the safety menu — tapping one opens block / report / remove
/// for that player, so moderation is reachable mid-match and not only from the
/// lobby.
class _PlayersBar extends ConsumerWidget {
  const _PlayersBar({required this.players, required this.localId});
  final List<PlayerInfo> players;
  final String localId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = ref.watch(blockedPlayersProvider);
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
          final offline = p.isOffline;
          final isBlocked = blocked.isBlocked(id: p.id, name: p.name);
          return Opacity(
            opacity: offline ? 0.55 : 1.0,
            child: GestureDetector(
              onTap: () => showPlayerActions(context, player: p),
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
                      avatarData: isBlocked ? null : p.avatarData,
                      size: 30,
                      color: Color(p.color),
                    ),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        isMe ? '${p.name} (you)' : p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isBlocked) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.block_rounded,
                        size: 14,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ],
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

/// Owns its own 200 ms timer and rebuilds only the timer bubble — so a clock
/// tick doesn't drag the whole BoardView (1000+ cells) through a rebuild.
class _ElapsedStatBubble extends StatefulWidget {
  const _ElapsedStatBubble({required this.startedAt, this.big = false});
  final DateTime? startedAt;
  final bool big;

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
      tint: Theme.of(context).colorScheme.tertiary,
      big: widget.big,
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
      ..translateByDouble(focal.dx, focal.dy, 0, 1)
      ..scaleByDouble(actualChange, actualChange, actualChange, 1)
      ..translateByDouble(-focal.dx, -focal.dy, 0, 1);
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
