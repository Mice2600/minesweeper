# Firebase Analytics — setup guide

✅ **Setup is complete.** The app is connected to the Firebase project
**`minesweeper-co-op`** for **Android + Web** (Windows has no Firebase SDK — it
stays a clean no-op there). Analytics code, events, and screen tracking are wired
through the swappable `Analytics` facade in `lib/analytics/analytics.dart`, and a
release build with Firebase configured compiles successfully.

The only thing left for you is to **confirm events are flowing** (step 5 below).
Steps 1–4 are kept as a record of what was done / how to redo it on a new machine.

---

## What's already done

- ✅ Firebase project `minesweeper-co-op` created and CLIs logged in.
- ✅ `flutterfire configure --platforms=android,web --android-package-name=dev.lacon.minesweeper`
  run — registered the Android app `dev.lacon.minesweeper` and a web app.
- ✅ Generated `lib/firebase_options.dart`, `android/app/google-services.json`, and
  added the Google Services Gradle plugin (`settings.gradle.kts`, `app/build.gradle.kts`).
- ✅ `lib/analytics/analytics.dart` `init()` now uses
  `DefaultFirebaseOptions.currentPlatform`.

> ✅ `google-services.json` and `firebase_options.dart` contain project keys that
> are **not secret** (they ship inside the app), so they're safe to commit. They
> are intentionally **not** covered by the keystore `.gitignore` rules.

## Redoing this on another machine (reference)

1. `npm install -g firebase-tools && firebase login`
2. `dart pub global activate flutterfire_cli` (add `%LOCALAPPDATA%\Pub\Cache\bin` to PATH)
3. From the project root:
   `flutterfire configure --project=minesweeper-co-op --platforms=android,web --android-package-name=dev.lacon.minesweeper --yes`

## 5. Verify it's working

```sh
flutter run            # on an Android device/emulator

# In another terminal, enable real-time DebugView for this app:
adb shell setprop debug.firebase.analytics.app dev.lacon.minesweeper
```

Then in the Firebase console → **Analytics → DebugView**, play a match and watch
for these events:

| Event | When |
|---|---|
| `screen_view` | every navigation (automatic) |
| `host_started` / `join_started` | starting/joining a game (param: `mode`) |
| `match_started` | a board begins (mode, size, mines, hearts, is_host) |
| `match_ended` | win/loss (won, mode, duration_ms) |
| `skin_purchased` | unlocking a skin (skin_id, price) |
| `first_open`, `session_start`, … | automatic Firebase events |

Standard dashboards (DAU/MAU, retention, funnels) populate within ~24h.

---

## Adding more events later

Add a typed method to `Analytics` in `lib/analytics/analytics.dart` and call
`Analytics.instance.yourEvent(...)` anywhere — no `BuildContext` needed. To switch
providers entirely (PostHog, Aptabase), you only reimplement that one class.

## Note for when you add ads

Firebase Analytics links directly to **AdMob** — once you create an AdMob account,
link it to this same Firebase project to see ad revenue alongside these events. At
that point also update `privacy/index.html` (it already has a forward-looking ads
clause) and the Play **Data safety** form to declare the advertising ID.
