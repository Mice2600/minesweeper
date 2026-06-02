import 'package:flutter/foundation.dart';

/// AdMob ad unit ids.
///
/// **Debug builds always use Google's test ids** so you never rack up invalid
/// impressions on your real account while developing (`flutter run` = safe).
/// **Release builds use the real ids** below. You can still override any id at
/// build time with `--dart-define=ADMOB_BANNER=...` etc.
///
/// The AdMob **App ID** is configured separately in AndroidManifest.xml.

// Google-published test ad units (sample ads only; safe to click).
const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
const String _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

// Real ad units (used in release). Overridable via --dart-define.
const String _realBanner = String.fromEnvironment(
  'ADMOB_BANNER',
  defaultValue: 'ca-app-pub-2898134740952284/4860728402',
);
const String _realInterstitial = String.fromEnvironment(
  'ADMOB_INTERSTITIAL',
  defaultValue: 'ca-app-pub-2898134740952284/2145415242',
);
const String _realRewarded = String.fromEnvironment(
  'ADMOB_REWARDED',
  defaultValue: 'ca-app-pub-2898134740952284/3986934350',
);

String _pick(String real, String test) =>
    (!kDebugMode && real.isNotEmpty) ? real : test;

String get bannerAdUnitId => _pick(_realBanner, _testBanner);
String get interstitialAdUnitId => _pick(_realInterstitial, _testInterstitial);
String get rewardedAdUnitId => _pick(_realRewarded, _testRewarded);
