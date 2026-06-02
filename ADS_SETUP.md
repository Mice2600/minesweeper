# AdMob Ads — setup guide (Android)

The ad **code is fully wired** and verified to build (web, Android release, tests).
It ships with Google's official **test ad units**, so you see (test) ads
immediately without an AdMob account. To earn real money you create an AdMob
account, make real ad units, and build with their ids.

**Android only.** `google_mobile_ads` has no web/Windows support, so all ad UI is
hidden there automatically.

## What's implemented

| Format | Where | Pacing |
|---|---|---|
| **Rewarded** (free coins) | Store → "Get coins" → "Watch ad" card | +250 coins, ~60 s cooldown |
| **Interstitial** | When leaving a finished match (Back to home / Play again) | every 3rd finished match, ≥90 s apart |
| **Banner** | Bottom of the Home and Store screens only (never the board) | always (menu surfaces) |

Tunables live in [lib/state/ad_gate.dart](lib/state/ad_gate.dart)
(`kRewardedCoins`, cooldown, cadence). Events `ad_reward_earned` /
`ad_interstitial_shown` flow to Firebase Analytics. A UMP **consent** prompt runs
on first launch for EEA/UK users.

---

## 1. Create an AdMob account + app

1. Go to <https://admob.google.com> and sign up (free; it's separate from Firebase).
2. **Apps → Add app → Android →** "Yes, it's published / not yet". Use the package
   name **`dev.lacon.minesweeper`**.
3. (Optional but recommended) **link AdMob to your Firebase project** so ad revenue
   shows next to your analytics: AdMob → App settings → link to Firebase.
4. Copy the **App ID** — it looks like `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`.

## 2. Create 3 ad units

In AdMob → your app → **Ad units → Add ad unit**, create:

| Ad unit | Format |
|---|---|
| Menu banner | **Banner** |
| Match interstitial | **Interstitial** |
| Free coins | **Rewarded** |

Copy each unit id — they look like `ca-app-pub-XXXX/ZZZZZZZZZZ`.

## 3. Real ids — already wired ✅

Your real ids are baked in:
- **App ID** `ca-app-pub-2898134740952284~4803368179` →
  [AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)
- **Banner / Interstitial / Rewarded** unit ids →
  [lib/ads/ad_ids.dart](lib/ads/ad_ids.dart)

**Debug builds (`flutter run`) automatically use Google TEST ad units**, so you can
develop safely. **Release builds use your real units.** No build flags needed:

```sh
flutter build appbundle --release
```

(You can still override any unit id with `--dart-define=ADMOB_BANNER=...` if needed.)

## 4. Add your test device (avoid policy strikes)

**Never click your own *real* ads** — it can get your AdMob account banned. While
testing real ad units, register your device as a test device (logcat prints your
device's test id on first ad load; add it via
`MobileAds.instance.updateRequestConfiguration(...)`), or keep using the bundled
test ids until launch.

## 5. Update Play Data Safety

Because ads collect the **advertising ID**, update the Play Console **Data safety**
form: declare collection of *Device or other IDs* for *Advertising or marketing*
(and *Analytics*). The hosted privacy policy ([privacy/index.html](privacy/index.html))
already describes AdMob + the advertising id.

---

## Testing on a device

1. `flutter run` on an Android device/emulator (with Google Play services).
2. **Banner**: a test banner appears at the bottom of Home/Store.
3. **Rewarded**: Store → "Get coins" → "Watch ad" → a test rewarded ad → balance
   **+250** and a 60 s cooldown engages (tapping again shows "More free coins in Ns").
4. **Interstitial**: finish **3 matches**, then tap "Back to home" / "Play again" on
   the result screen → a test interstitial shows (min 90 s apart).
5. Confirm `ad_reward_earned` / `ad_interstitial_shown` in Firebase DebugView.

## Notes
- Real ads only serve after AdMob reviews/approves the app (can take a few hours to
  a day). Until then real ad units may return "no fill" — test ids always fill.
- minSdk is already 23 (AdMob's minimum).
- The advertising-id permission is added automatically by the `google_mobile_ads`
  plugin's manifest.
