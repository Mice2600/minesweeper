import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../firebase_options.dart';

/// App-wide analytics facade — the single seam the rest of the app talks to.
///
/// Backed by Firebase Analytics when the app has been configured for the
/// current platform (i.e. `flutterfire configure` was run / google-services.json
/// is present). If Firebase isn't configured, every call is a silent no-op, so
/// the app builds and runs fine before/without analytics setup.
///
/// Nothing in the game/UI code references Firebase directly — to switch
/// providers (PostHog, Aptabase, …) you only reimplement this class.
class Analytics {
  Analytics._();

  /// Global singleton. Use `Analytics.instance.matchStarted(...)` etc.
  static final Analytics instance = Analytics._();

  FirebaseAnalytics? _fa;

  bool get isActive => _fa != null;

  /// A navigator observer that auto-logs `screen_view` on route changes, or
  /// `null` when analytics is inactive. Pass into `GoRouter(observers: [...])`.
  NavigatorObserver? get navigatorObserver =>
      _fa == null ? null : FirebaseAnalyticsObserver(analytics: _fa!);

  /// Initialises Firebase if it's configured for this platform. Never throws —
  /// on any failure analytics simply stays off. Call once from `main()` before
  /// `runApp`.
  Future<void> init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _fa = FirebaseAnalytics.instance;
      if (kDebugMode) debugPrint('[analytics] Firebase Analytics active');
    } catch (e) {
      _fa = null;
      if (kDebugMode) {
        debugPrint('[analytics] disabled (Firebase not configured): $e');
      }
    }
  }

  void _log(String name, [Map<String, Object>? params]) {
    if (kDebugMode) debugPrint('[analytics] event: $name ${params ?? ''}');
    final fa = _fa;
    if (fa == null) return;
    // Fire-and-forget; analytics must never break or block gameplay.
    fa.logEvent(name: name, parameters: params).catchError((_) {});
  }

  // ─── Typed events ──────────────────────────────────────────────────────────

  /// A host session was started (LAN or online). Also covers solo play, which
  /// runs through the LAN host path.
  void hostStarted({required String mode}) =>
      _log('host_started', {'mode': mode});

  /// The local player began joining someone else's game.
  void joinStarted({required String mode}) =>
      _log('join_started', {'mode': mode});

  /// A match started on this device (host or guest).
  void matchStarted({
    required String mode,
    required int width,
    required int height,
    required int mines,
    required int hearts,
    required bool isHost,
  }) =>
      _log('match_started', {
        'mode': mode,
        'width': width,
        'height': height,
        'mines': mines,
        'hearts': hearts,
        'is_host': isHost ? 1 : 0,
      });

  /// A match ended on this device. [durationMs] is wall-clock match length.
  void matchEnded({
    required bool won,
    required String mode,
    required int durationMs,
  }) =>
      _log('match_ended', {
        'won': won ? 1 : 0,
        'mode': mode,
        'duration_ms': durationMs,
      });

  /// The local player earned an achievement for the first time. [id] is the
  /// stable achievement key (e.g. `win_hard`).
  void achievementUnlocked({required String id}) =>
      _log('achievement_unlocked', {'achievement_id': id});

  /// The local player unlocked a cosmetic board skin with in-game coins.
  void skinPurchased({required String skinId, required int price}) =>
      _log('skin_purchased', {'skin_id': skinId, 'price': price});

  /// A real-money coin pack was purchased via in-app billing.
  void coinPackPurchased({required String productId, required int coins}) =>
      _log('coin_pack_purchased', {'product_id': productId, 'coins': coins});

  /// A developer tip (donation) was purchased via in-app billing.
  void tipPurchased({required String productId}) =>
      _log('tip_purchased', {'product_id': productId});

  /// The player completed a rewarded ad and earned coins.
  void adRewardEarned({required int coins}) =>
      _log('ad_reward_earned', {'coins': coins});

  /// An interstitial ad was shown (e.g. on leaving a finished match).
  void adInterstitialShown() => _log('ad_interstitial_shown');
}
