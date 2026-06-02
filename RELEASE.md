# Release Guide — Minesweeper Co-op

Everything needed to publish the app, plus the copy/answers you'll paste into the
store consoles. The code-side release blockers are already done (signing, app ID,
relay URL, privacy screen). What's left here is mostly browser/account work.

---

## 0. Critical: back up your signing key 🔐

Release builds are signed with an **upload keystore**. If you lose it you can
**never update the app on Google Play again** — you'd have to publish a brand-new
listing. Back these up somewhere safe (password manager + offline copy):

- Keystore file: `android/upload-keystore.jks`
- Password / alias: in `android/key.properties` (alias `upload`)

Both are **gitignored** — they are NOT in version control. If you move to a new
machine, copy both files over and you can keep shipping updates.

Certificate fingerprint (SHA-256):
`D1:BD:23:F1:1A:40:2E:3A:2A:AF:76:3B:3C:FC:70:DF:F9:B9:14:60:5F:46:21:11:61:64:75:0C:83:BA:6D:BF`

---

## 1. Build commands

Online play now works **by default** (the production relay URL is baked in), so the
`--dart-define` flag is optional — only use it to point at a different relay.

```sh
# Android App Bundle (what you upload to Google Play)
flutter build appbundle --release
#  → build/app/outputs/bundle/release/app-release.aab

# Android APK (for direct install / sideload testing)
flutter build apk --release
#  → build/app/outputs/flutter-apk/app-release.apk

# Windows
flutter build windows --release

# Web
flutter build web --release
```

> The signed AAB/APK is produced automatically because `android/key.properties`
> exists. On a machine without it, the build falls back to debug signing.

---

## 2. Privacy policy — deploy to Cloudflare Pages

The policy file is at `privacy/index.html`. Host it and get a public URL:

1. Go to **Cloudflare Dashboard → Workers & Pages → Create → Pages**.
2. Easiest path: **"Upload assets"** (direct upload). Name the project e.g.
   `minesweeper-coop`, then drag in the **`privacy/` folder** (or zip its contents).
   - Or connect your Git repo and set the build output directory to `privacy`.
3. Deploy. You'll get a URL like `https://minesweeper-coop.pages.dev/`.
   The policy will be at `https://minesweeper-coop.pages.dev/` (index.html is served
   at the root of the project).
4. **Update the in-app link**: edit `kPrivacyPolicyUrl` in
   `lib/ui/screens/about_screen.dart` to the real URL, then rebuild.
5. Use that same URL in the Play Console "Privacy policy" field (step 4).

---

## 3. Google Play Console setup (one-time)

1. Create a developer account at <https://play.google.com/console> ($25 one-time fee).
2. **Create app** → name "Minesweeper Co-op", free, game.
3. Upload the **AAB** (`app-release.aab`) to a **Closed testing** track first — get
   it working with a small tester list before Production.
4. Complete the required forms (copy below):
   - **Store listing** (titles, descriptions, graphics)
   - **Data safety** (answers below)
   - **Content rating** questionnaire (IARC)
   - **Privacy policy** URL (from step 2)
   - **App category**: Game → Puzzle / Board.

You also need graphics you'll have to create:
- App icon 512×512 (you have `assets/icon/icon.png` — export at 512).
- **Feature graphic 1024×500** (required).
- **At least 2 phone screenshots** (capture from a device/emulator).

---

## 4. Store listing copy (draft — edit to taste)

**App name (30 char max):**
> Minesweeper Co-op

**Short description (80 char max):**
> Team up and sweep the board together — online or on local Wi-Fi.

**Full description:**
> Minesweeper, but together. Minesweeper Co-op is a cooperative twist on the
> classic: you and your friends work the same board as one team, with shared
> reveals, flags, live cursors, emoji reactions, and chat.
>
> • Play online with a short room code — no account needed.
> • Or host over local Wi-Fi with zero internet required.
> • Classic mode and a team Hearts mode where the squad shares lives and one
>   wrong tap sets off a chain reaction.
> • Pick a difficulty, customize your avatar, and unlock cosmetic board skins.
> • Up to 8 players per game.
>
> No sign-up, no ads (today), just quick co-op puzzling with friends.

---

## 5. Data safety form answers (based on actual data flows)

The app has no accounts and no analytics/ad SDKs today. Answer the Play "Data
safety" section as follows:

- **Does your app collect or share user data?**
  - *Personal info / Name (display name) and Photos (avatar):* **Collected** (user
    provides), and **Shared** in the sense it is transmitted to other players in
    the same game room. It is **not** collected by you/your servers and not used
    for tracking. Purpose: **App functionality** (multiplayer). Not required —
    user-chosen.
  - *Messages (in-game chat):* transmitted to other players in the room for app
    functionality; not stored by you.
  - *Device or other IDs / location / contacts / financial:* **Not collected.**
- **Is data encrypted in transit?** The online relay uses secure WebSockets
  (`wss://`). Local Wi-Fi (LAN) play uses an unencrypted local-network connection
  (`ws://`) confined to your network — disclose this honestly if asked.
- **Can users request data deletion?** All data is on-device; uninstalling removes
  it. No server-side account to delete.

> ⚠️ The moment you add ads (e.g. AdMob), this changes: you'll need to declare
> collection of **Device or other IDs** (advertising ID) and update
> `privacy/index.html`. The privacy file already contains a forward-looking
> advertising clause to make that transition easy.

---

## 6. Windows (optional, later)

- **Microsoft Store:** register at Partner Center (~$19 one-time), package the
  `flutter build windows --release` output as MSIX (the `msix` pub package can
  automate this). Or distribute the built folder / an installer directly.

---

## 7. Pre-submit checklist

- [ ] Keystore + password backed up off-machine.
- [ ] `privacy/` deployed to Cloudflare Pages; URL recorded.
- [ ] `kPrivacyPolicyUrl` updated in `about_screen.dart` and app rebuilt.
- [ ] `flutter analyze` clean, `flutter test` green.
- [ ] AAB built and uploaded to a **Closed testing** track.
- [ ] Listing copy, feature graphic, ≥2 screenshots uploaded.
- [ ] Data safety + content rating forms completed.
- [ ] Tested the closed-test build on a real device (online + LAN play work).
- [ ] (Recommended) Firebase Analytics connected — see [FIREBASE_SETUP.md](FIREBASE_SETUP.md).
      The code is wired; it's a no-op until you run `flutterfire configure`.

---

## Deferred (next phases, not blocking release)
- Ads / monetization (the `addCoins()` hook in `lib/state/store.dart` is ready for
  a rewarded-ad source).
- iOS support (no `ios/` target yet).
- Integration tests for the transport/session layers.
