import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_ids.dart';

/// App-wide ads facade (mirrors the `Analytics` / `Ads` singleton style).
///
/// AdMob runs on **Android only** here — `google_mobile_ads` has no web/Windows
/// support, so on those platforms [available] stays false and every method is a
/// silent no-op. Nothing in the UI references the SDK directly.
class Ads {
  Ads._();
  static final Ads instance = Ads._();

  /// Only Android can show ads in this project.
  static final bool _supported =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  bool _ready = false;

  /// True once the SDK is initialized and ads may be shown.
  bool get available => _ready;

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  /// Initializes the consent flow then the Mobile Ads SDK, and preloads one
  /// interstitial + one rewarded ad. Never throws — on any failure ads stay off.
  Future<void> init() async {
    if (!_supported) return;
    try {
      await _gatherConsent();
      await MobileAds.instance.initialize();
      _ready = true;
      _loadInterstitial();
      _loadRewarded();
      if (kDebugMode) debugPrint('[ads] Mobile Ads initialized');
    } catch (e) {
      _ready = false;
      if (kDebugMode) debugPrint('[ads] init failed: $e');
    }
  }

  /// Requests UMP consent info and shows the consent form if required (EEA/UK).
  /// Failures are non-fatal — ad serving proceeds in non-personalized mode.
  Future<void> _gatherConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {}
        if (!completer.isCompleted) completer.complete();
      },
      (FormError error) {
        if (kDebugMode) debugPrint('[ads] consent error: ${error.message}');
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  // ─── Interstitial ───────────────────────────────────────────────────────────

  void _loadInterstitial() {
    if (!_ready) return;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Shows the preloaded interstitial if one is ready, then preloads the next.
  /// Returns true if an ad was shown.
  Future<bool> showInterstitial() async {
    final ad = _interstitial;
    if (!_ready || ad == null) return false;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadInterstitial();
      },
    );
    await ad.show();
    return true;
  }

  // ─── Rewarded ───────────────────────────────────────────────────────────────

  void _loadRewarded() {
    if (!_ready) return;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (_) => _rewarded = null,
      ),
    );
  }

  /// Whether a rewarded ad is loaded and ready to show right now.
  bool get rewardedReady => _ready && _rewarded != null;

  /// Shows a rewarded ad; calls [onReward] when the user earns the reward, then
  /// preloads the next. Returns true if an ad was shown.
  Future<bool> showRewarded({required VoidCallback onReward}) async {
    final ad = _rewarded;
    if (!_ready || ad == null) return false;
    _rewarded = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewarded();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadRewarded();
      },
    );
    await ad.show(onUserEarnedReward: (_, __) => onReward());
    return true;
  }

  // ─── Banner ─────────────────────────────────────────────────────────────────

  /// Creates and starts loading a standard banner for menu screens, or returns
  /// null when ads are unavailable. The caller owns disposing it (see
  /// [MenuBanner]); [onLoaded]/[onFailed] report the load result.
  BannerAd? createMenuBanner({
    required VoidCallback onLoaded,
    required VoidCallback onFailed,
  }) {
    if (!_ready) return null;
    final ad = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) => onLoaded(),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          onFailed();
        },
      ),
    );
    ad.load();
    return ad;
  }
}
