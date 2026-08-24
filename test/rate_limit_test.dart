import 'package:flutter_test/flutter_test.dart';
import 'package:minesweeper/core/rate_limit.dart';

void main() {
  // A fixed origin so these never depend on wall-clock timing.
  final t0 = DateTime.utc(2026, 1, 1);

  group('TokenBucket', () {
    test('allows a full burst up to capacity, then blocks', () {
      final b = TokenBucket(capacity: 5, refillPerSecond: 1);
      for (var i = 0; i < 5; i++) {
        expect(b.tryConsume(now: t0), isTrue, reason: 'burst message $i');
      }
      expect(b.tryConsume(now: t0), isFalse);
    });

    test('refills continuously, so a pause restores budget', () {
      final b = TokenBucket(capacity: 5, refillPerSecond: 2);
      for (var i = 0; i < 5; i++) {
        b.tryConsume(now: t0);
      }
      expect(b.tryConsume(now: t0), isFalse);
      // 1s at 2/s = 2 more tokens.
      expect(b.tryConsume(now: t0.add(const Duration(seconds: 1))), isTrue);
      expect(b.tryConsume(now: t0.add(const Duration(seconds: 1))), isTrue);
      expect(b.tryConsume(now: t0.add(const Duration(seconds: 1))), isFalse);
    });

    test('refill never exceeds capacity', () {
      final b = TokenBucket(capacity: 3, refillPerSecond: 10);
      // An hour of idling must not bank an hour's worth of tokens.
      final later = t0.add(const Duration(hours: 1));
      for (var i = 0; i < 3; i++) {
        expect(b.tryConsume(now: later), isTrue);
      }
      expect(b.tryConsume(now: later), isFalse);
    });
  });

  group('PlayerRateLimits', () {
    test('sustained legitimate play is not throttled', () {
      // The failure mode that matters: limits so tight they clip real play.
      // 20 board actions over 2s is faster than a human can chord.
      final limits = PlayerRateLimits();
      var allowed = 0;
      for (var i = 0; i < 20; i++) {
        final now = t0.add(Duration(milliseconds: i * 100));
        if (limits.board.tryConsume(now: now)) allowed++;
      }
      expect(allowed, 20);
    });

    test('a flood is cut off well before it is fanned out', () {
      final limits = PlayerRateLimits();
      var allowed = 0;
      // 500 chat lines in the same instant — a scripted client.
      for (var i = 0; i < 500; i++) {
        if (limits.chat.tryConsume(now: t0)) allowed++;
      }
      expect(allowed, lessThanOrEqualTo(5));
    });

    test('each kind has an independent budget', () {
      final limits = PlayerRateLimits();
      for (var i = 0; i < 50; i++) {
        limits.chat.tryConsume(now: t0);
      }
      // Exhausting chat must not silence the board.
      expect(limits.board.tryConsume(now: t0), isTrue);
    });
  });
}
