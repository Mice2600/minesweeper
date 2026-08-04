import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../state/session.dart';

/// Full-screen overlay shown over the game board while the host link is
/// unhealthy — either reconnecting after a drop, or fully disconnected.
///
/// Replaces the in-flow [_ConnectionBanner] for those states so the player
/// can't keep tapping cells that no one will hear. Animates in/out with a
/// fade so the transition feels intentional.
class ConnectionOverlay extends StatelessWidget {
  const ConnectionOverlay({
    super.key,
    required this.state,
    required this.onLeave,
    this.message,
  });

  final SessionConnState state;
  final VoidCallback onLeave;

  /// Explanation to show instead of the generic copy. Carries the host's
  /// reason when [state] is [SessionConnState.kicked].
  final String? message;

  bool get _visible =>
      state == SessionConnState.reconnecting ||
      state == SessionConnState.disconnected ||
      state == SessionConnState.kicked;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        opacity: _visible ? 1 : 0,
        child: _visible
            ? _OverlayContent(
                state: state, onLeave: onLeave, message: message)
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _OverlayContent extends StatelessWidget {
  const _OverlayContent({
    required this.state,
    required this.onLeave,
    this.message,
  });
  final SessionConnState state;
  final VoidCallback onLeave;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Both are terminal — no reconnect spinner, one way out.
    final isLost = state == SessionConnState.disconnected ||
        state == SessionConnState.kicked;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dim + blur the board behind. The blur is cheap on desktop and
        // beefy mobile; degrades gracefully to just the dim on slow GPUs.
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(color: Colors.black.withValues(alpha: 0.45)),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: _Card(
                state: state,
                onLeave: onLeave,
                isLost: isLost,
                cs: cs,
                message: message,
              )
                  .animate(key: ValueKey(state))
                  .fadeIn(duration: 240.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.92, 0.92),
                    end: const Offset(1, 1),
                    duration: 280.ms,
                    curve: Curves.easeOutBack,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.state,
    required this.onLeave,
    required this.isLost,
    required this.cs,
    this.message,
  });
  final SessionConnState state;
  final VoidCallback onLeave;
  final bool isLost;
  final ColorScheme cs;
  final String? message;

  bool get _kicked => state == SessionConnState.kicked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isLost ? cs.error : cs.primary.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isLost ? cs.error : cs.primary).withValues(alpha: 0.25),
            blurRadius: 32,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RadarIcon(isLost: isLost, kicked: _kicked, cs: cs),
          const SizedBox(height: 22),
          Text(
            _kicked
                ? 'Removed from the game'
                : (isLost ? 'Disconnected' : 'Host went away'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isLost ? cs.error : cs.onSurface,
                  letterSpacing: 0.2,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            _kicked
                ? '${message ?? 'The host removed you from this game.'}\n\n'
                    'You can still host or join other games.'
                : (isLost
                    ? "Couldn't get back to the host.\nThe room may be closed."
                    : "We're holding your spot — the room is still alive.\nReconnecting…"),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 22),
          if (isLost)
            _PrimaryButton(
              icon: Icons.logout_rounded,
              label: _kicked ? 'Back to menu' : 'Leave game',
              cs: cs,
              tone: cs.error,
              onPressed: onLeave,
            )
          else ...[
            _ProgressShimmer(cs: cs),
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: onLeave,
              icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
              label: Text(
                'Leave anyway',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Concentric rings + center dot that pulse outward. Looks like a radar/sonar
/// sweep — fits the "we're listening for the host" idea.
class _RadarIcon extends StatelessWidget {
  const _RadarIcon({
    required this.isLost,
    required this.cs,
    this.kicked = false,
  });
  final bool isLost;
  final bool kicked;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    final accent = isLost ? cs.error : cs.primary;
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            _Ping(
              accent: accent,
              delayMs: i * 600,
              paused: isLost,
            ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.18),
              border: Border.all(color: accent, width: 2),
            ),
            child: Icon(
              kicked
                  ? Icons.person_remove_rounded
                  : (isLost
                      ? Icons.cloud_off_rounded
                      : Icons.satellite_alt_rounded),
              color: accent,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}

class _Ping extends StatelessWidget {
  const _Ping({
    required this.accent,
    required this.delayMs,
    required this.paused,
  });
  final Color accent;
  final int delayMs;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final ring = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent, width: 2),
      ),
    );
    if (paused) {
      return Opacity(opacity: 0.25, child: ring);
    }
    return ring
        .animate(
          onPlay: (c) => c.repeat(),
          delay: Duration(milliseconds: delayMs),
        )
        .scaleXY(begin: 0.35, end: 1.0, duration: 1800.ms, curve: Curves.easeOut)
        .fadeOut(duration: 1800.ms, curve: Curves.easeOut);
  }
}

/// Indeterminate progress that "sweeps" left-to-right. Custom because we want
/// it to feel matched to the radar theme rather than the generic Material
/// LinearProgressIndicator.
class _ProgressShimmer extends StatelessWidget {
  const _ProgressShimmer({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: 6,
        width: double.infinity,
        child: Stack(
          children: [
            Container(color: cs.surfaceContainerHighest),
            FractionallySizedBox(
              widthFactor: 0.35,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0),
                      cs.primary,
                      cs.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .slideX(
                  begin: -1.5,
                  end: 2.5,
                  duration: 1400.ms,
                  curve: Curves.easeInOut,
                ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.cs,
    required this.tone,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final ColorScheme cs;
  final Color tone;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: tone,
          foregroundColor: cs.onError,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
