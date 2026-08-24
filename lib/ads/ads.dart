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

  final Completer<void> _initDone = Completer<void>();

  /// Completes when [init] has finished — successfully or not, so awaiting it
  /// never hangs. [init] runs after `runApp` (see main.dart), so a widget that
  /// creates an ad on mount would otherwise race it and silently get nothing;
  /// await this first and then check [available].
  Future<void> get whenReady => _initDone.future;

  void _completeInit() {
    if (!_initDone.isCompleted) _initDone.complete();
  }

  InterstitialAd? _interstitial;
  RewardedAd? _rewarded;

  /// Initializes the consent flow then the Mobile Ads SDK, and preloads one
  /// interstitial + one rewarded ad. Never throws — on any failure ads stay off.
  Future<void> init() async {
    if (!_supported) {
      _completeInit();
      return;
    }
    try {
      await _gatherConsent();
      await _applyRequestConfiguration();
      await MobileAds.instance.initialize();
      _ready = true;
      _loadInterstitial();
      _loadRewarded();
      if (kDebugMode) debugPrint('[ads] Mobile Ads initialized');
    } catch (e) {
      _ready = false;
      if (kDebugMode) debugPrint('[ads] init failed: $e');
    } finally {
      _completeInit();
    }
  }

  /// Constrains what ads may be served, to match what the store listing claims.
  ///
  /// The app is rated Teen (13+) — chat and shared photos between strangers put
  /// it there — so ad content is capped at the same rating. Without this the
  /// SDK may serve content above the rating the app declares, which is a policy
  /// problem regardless of whether anyone complains.
  ///
  /// `tagForChildDirectedTreatment: no` states the app is not child-directed.
  /// That has to stay consistent with the Play Console: the app targets 13+ and
  /// is deliberately not enrolled in Designed for Families.
  Future<void> _applyRequestConfiguration() =>
      MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(
          maxAdContentRating: MaxAdContentRating.t,
          tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
        ),
      );

  /// UMP treats this device as being in the EEA, so the consent form and the
  /// privacy-options entry point can be exercised from anywhere. Pass the
  /// device's *hashed* id — the UMP SDK prints it to logcat on first run:
  ///
  /// ```sh
  /// flutter run --dart-define=UMP_TEST_DEVICE=33BE2250B43518CCDA7DE426D04EE231
  /// ```
  ///
  /// Inert unless the define is passed, so shipped builds get the real
  /// geography. Deliberately *not* gated on [kDebugMode]: UMP only honours a
  /// forced geography for the specific hashed device id listed here, and some
  /// devices (Xiaomi/HyperOS) refuse to install debuggable APKs at all — so a
  /// debug-only hook would make the consent flow untestable on exactly the
  /// hardware you have. Without this there is no way to see that flow outside
  /// the EEA/UK, which makes it the one part of the ads path that silently
  /// goes untested.
  static const String _umpTestDevice =
      String.fromEnvironment('UMP_TEST_DEVICE');

  ConsentRequestParameters _consentParams() {
    if (_umpTestDevice.isNotEmpty) {
      return ConsentRequestParameters(
        consentDebugSettings: ConsentDebugSettings(
          debugGeography: DebugGeography.debugGeographyEea,
          testIdentifiers: [_umpTestDevice],
        ),
      );
    }
    return ConsentRequestParameters();
  }

  /// Requests UMP consent info and shows the consent form if required (EEA/UK).
  /// Failures are non-fatal — ad serving proceeds in non-personalized mode.
  Future<void> _gatherConsent() async {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      _consentParams(),
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

  // ─── Privacy options ────────────────────────────────────────────────────────

  /// Whether this user needs a persistent way to revisit their ad-consent
  /// choice — true in the EEA/UK, false almost everywhere else.
  ///
  /// Collecting consent once is only half of what UMP expects; a user who has
  /// consented must be able to change their mind later. The About screen shows
  /// its privacy-options row only when this is true, so users outside the EEA
  /// don't get a control that opens nothing.
  Future<bool> privacyOptionsRequired() async {
    if (!_supported) return false;
    try {
      final status =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus();
      return status == PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Re-opens the consent form so the user can change their choice. Returns
  /// false if the form couldn't be shown. Never throws.
  Future<bool> showPrivacyOptions() async {
    if (!_supported) return false;
    final completer = Completer<bool>();
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {
        if (kDebugMode && error != null) {
          debugPrint('[ads] privacy options error: ${error.message}');
        }
        if (!completer.isCompleted) completer.complete(error == null);
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[ads] privacy options failed: $e');
      if (!completer.isCompleted) completer.complete(false);
    }
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
