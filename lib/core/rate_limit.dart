/// Per-player flood control for the host.
///
/// The host re-broadcasts most of what a guest sends to every other player, so
/// one client can turn a single socket into an 8x amplifier. Nothing in the
/// transport or the session throttled that, which made chat/emoji/cursor spam
/// free to send and expensive to receive.
///
/// A token bucket rather than a fixed window: bursts are normal here (a fast
/// chorder, a cursor drag) and a fixed window would clip them at the boundary.
/// Tokens refill continuously, so a player who has been quiet can still act
/// immediately, and only sustained flooding runs the bucket dry.
///
/// Over-budget messages are dropped silently by the caller — never answered
/// with an error, because an error reply is itself an amplification vector.
library;

class TokenBucket {
  TokenBucket({required this.capacity, required this.refillPerSecond})
      : _tokens = capacity.toDouble();

  /// Maximum burst, in messages.
  final int capacity;

  /// Sustained rate, in messages per second.
  final double refillPerSecond;

  double _tokens;
  DateTime? _last;

  /// Takes one token if available. Returns false when the caller should drop
  /// the message. [now] is injectable so tests don't depend on wall clock.
  bool tryConsume({DateTime? now}) {
    final t = now ?? DateTime.now();
    final last = _last;
    if (last != null) {
      final elapsed = t.difference(last).inMicroseconds / 1e6;
      if (elapsed > 0) {
        _tokens = (_tokens + elapsed * refillPerSecond)
            .clamp(0.0, capacity.toDouble());
      }
    }
    _last = t;
    if (_tokens < 1.0) return false;
    _tokens -= 1.0;
    return true;
  }
}

/// The per-player budget for each rate-limited message kind.
///
/// Limits are deliberately well above real play: chording as fast as a thumb
/// allows, or dragging a cursor, must never be throttled — the only thing these
/// stop is a modified client sending in a loop.
class PlayerRateLimits {
  PlayerRateLimits()
      : chat = TokenBucket(capacity: 5, refillPerSecond: 1),
        emoji = TokenBucket(capacity: 8, refillPerSecond: 2),
        cursor = TokenBucket(capacity: 40, refillPerSecond: 30),
        board = TokenBucket(capacity: 30, refillPerSecond: 20);

  /// Chat lines: bursty by nature, but a human tops out around one a second.
  final TokenBucket chat;

  /// Emoji reactions: allowed to be spammier than chat, they're cheaper.
  final TokenBucket emoji;

  /// Cursor updates: guests already send ~30/s while dragging, so this is
  /// sized to pass legitimate movement untouched.
  final TokenBucket cursor;

  /// Reveal / flag / chord. Fast chording is a real skill expression; this is
  /// set high enough that only automation trips it.
  final TokenBucket board;
}
