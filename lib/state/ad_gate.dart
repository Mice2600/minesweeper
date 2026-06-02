import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/prefs.dart';

/// Tunables for ad pacing.
const int kRewardedCoins = 250;
const Duration _kRewardedCooldown = Duration(seconds: 60);
const int _kInterstitialEveryNMatches = 3;
const Duration _kInterstitialMinGap = Duration(seconds: 90);

const String _kLastRewardedMs = 'ads.lastRewardedMs';
const String _kLastInterstitialMs = 'ads.lastInterstitialMs';
const String _kMatchesSinceInterstitial = 'ads.matchesSinceInterstitial';

/// Persisted pacing counters for ad frequency capping.
class AdGateState {
  const AdGateState({
    required this.lastRewardedMs,
    required this.lastInterstitialMs,
    required this.matchesSinceInterstitial,
  });

  final int lastRewardedMs;
  final int lastInterstitialMs;
  final int matchesSinceInterstitial;

  AdGateState copyWith({
    int? lastRewardedMs,
    int? lastInterstitialMs,
    int? matchesSinceInterstitial,
  }) =>
      AdGateState(
        lastRewardedMs: lastRewardedMs ?? this.lastRewardedMs,
        lastInterstitialMs: lastInterstitialMs ?? this.lastInterstitialMs,
        matchesSinceInterstitial:
            matchesSinceInterstitial ?? this.matchesSinceInterstitial,
      );
}

/// Decides when rewarded/interstitial ads may be shown and remembers the pacing
/// across restarts. Pure timing/logic — actually showing ads is [Ads]'s job.
final adGateProvider =
    NotifierProvider<AdGateNotifier, AdGateState>(AdGateNotifier.new);

class AdGateNotifier extends Notifier<AdGateState> {
  @override
  AdGateState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return AdGateState(
      lastRewardedMs: prefs.getInt(_kLastRewardedMs) ?? 0,
      lastInterstitialMs: prefs.getInt(_kLastInterstitialMs) ?? 0,
      matchesSinceInterstitial:
          prefs.getInt(_kMatchesSinceInterstitial) ?? 0,
    );
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// True once the rewarded cooldown has elapsed.
  bool rewardedReady() =>
      _now - state.lastRewardedMs >= _kRewardedCooldown.inMilliseconds;

  /// Seconds left on the rewarded cooldown (0 when ready).
  int rewardedCooldownRemaining() {
    final left = _kRewardedCooldown.inMilliseconds -
        (_now - state.lastRewardedMs);
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  void recordRewarded() {
    state = state.copyWith(lastRewardedMs: _now);
    _persist();
  }

  /// Count a finished match toward the interstitial cadence.
  void registerFinishedMatch() {
    state = state.copyWith(
        matchesSinceInterstitial: state.matchesSinceInterstitial + 1);
    _persist();
  }

  /// True when enough matches have elapsed and the min gap has passed.
  bool interstitialDue() =>
      state.matchesSinceInterstitial >= _kInterstitialEveryNMatches &&
      _now - state.lastInterstitialMs >= _kInterstitialMinGap.inMilliseconds;

  void recordInterstitial() {
    state = state.copyWith(
      lastInterstitialMs: _now,
      matchesSinceInterstitial: 0,
    );
    _persist();
  }

  void _persist() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt(_kLastRewardedMs, state.lastRewardedMs);
    prefs.setInt(_kLastInterstitialMs, state.lastInterstitialMs);
    prefs.setInt(_kMatchesSinceInterstitial, state.matchesSinceInterstitial);
  }
}
