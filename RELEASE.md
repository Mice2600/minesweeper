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

## 2. Privacy policy — ⚠️ REDEPLOY REQUIRED

Already live at <https://minesweeper-coop.lacon.workers.dev/> and already linked
from the app (`kPrivacyPolicyUrl` in `lib/ui/screens/about_screen.dart`).

**But `privacy/index.html` has changed** — it now covers in-app purchases, the
moderation/report/block tools, and data retention. The hosted copy is a separate
deployment that does *not* update from this repo, so **re-upload it before you
submit**. Play compares the linked policy against the declared data practices;
a stale policy that omits IAP is a rejection.

<details>
<summary>First-time hosting instructions (if you ever need to redo it)</summary>

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

</details>

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
> Play safely: chat and names are filtered automatically, you can block or
> report any player, and whoever hosts a game can remove them from it.
>
> No sign-up required. Contains ads and optional in-app purchases (coin packs
> and a tip jar) — coins only buy cosmetic board skins and never affect play.

> ⚠️ Do **not** claim "no ads" anywhere in the listing — the app ships AdMob
> banners, interstitials, and rewarded video. A listing that contradicts the
> binary is a misrepresentation strike.

**Also required on the listing:**
- Tick **"Contains ads"**.
- Declare **in-app purchases** with the price range (~$0.99–$17.99).
- Category: Game → Puzzle / Board.

---

## 5. Data safety form answers (based on actual data flows)

The app has no accounts, but it **does** ship AdMob, Firebase Analytics, and
Play Billing. Answer the Play "Data safety" section as follows:

- **Does your app collect or share user data?** → **Yes.**
  - *Personal info / Name (display name)* — **Collected** and **Shared** (it is
    transmitted to the other players in the room). Purpose: **App
    functionality**. Optional, user-chosen. Not used for tracking.
  - *Photos / Videos (avatar photo)* — **Collected** and **Shared** with the
    other players in the room. Purpose: **App functionality**. Optional.
  - *Messages (in-game chat)* — **Collected** and **Shared** with the other
    players in the room. Purpose: **App functionality**. Not stored by you.
  - *Device or other IDs (advertising ID)* — **Collected** and **Shared** with
    Google AdMob. Purposes: **Advertising or marketing** and **Analytics**.
    This is *required*, not optional. ← this is the entry the pre-monetization
    version of this guide got wrong.
  - *App activity (app interactions)* — **Collected** via Google Analytics for
    Firebase. Purpose: **Analytics**.
  - *Purchase history* — handled entirely by Google Play Billing. Declare it if
    the form asks; the app itself never sees or stores payment data.
  - *Location / contacts / financial info / files* — **Not collected.**
- **Is data encrypted in transit?** **Yes** for online play (the relay uses
  `wss://`) and for ads/analytics. Local Wi-Fi (LAN) play uses an unencrypted
  `ws://` socket confined to your own network — disclose this honestly; the
  privacy policy already states it.
- **Can users request data deletion?** All app data is on-device; uninstalling
  removes it. There is no server-side account to delete. Advertising-ID resets
  are handled in Android system settings.

## 5b. User-generated content — required declarations

The app carries UGC (chat, display names, avatar photos) between strangers over
online rooms, so Play's UGC policy applies. What ships, and where reviewers can
see it:

| Requirement | Implementation |
|---|---|
| Content filtering | [lib/core/moderation.dart](lib/core/moderation.dart) — leetspeak/accent-folding profanity filter applied by the **host** to every display name and chat line before broadcast |
| In-app reporting | Tap any player (lobby slot, in-game player bar, chat avatar, or long-press a chat message) → **Report** with a reason picker. Files to the host, keeps a local copy under **About → Safety**, and offers an email escalation to the developer |
| In-app blocking | Same menu → **Block**. Hides that player's messages, reactions, cursor, and profile photo. Persists across sessions by name; managed under **About → Safety** |
| Removal by moderator | The host sees **Remove from game** on the same menu. The kicked player is disconnected and their rejoin token is refused for the life of the room |

In the Play Console:

- **Content rating (IARC) questionnaire:** answer **Yes** to "Users can interact
  or exchange content", **Yes** to "users can share images/photos", and **No**
  to sharing location. Expect a **Teen / 13+** rating as a result.
- **Target audience & content:** target **13+** (not children). Do not opt into
  the Designed for Families programme — the app shows non-family-certified ads.
- **App content → Ads:** declare ads present.
- Keep a screenshot of the report/block flow handy; UGC apps are sometimes
  asked to demonstrate the moderation tools during review.

---

## 6. Windows (optional, later)

- **Microsoft Store:** register at Partner Center (~$19 one-time), package the
  `flutter build windows --release` output as MSIX (the `msix` pub package can
  automate this). Or distribute the built folder / an installer directly.

---

## 7. Pre-submit checklist

- [ ] Keystore + password backed up off-machine.
- [ ] **`privacy/index.html` re-uploaded** — it changed (IAP + moderation +
      retention sections). URL stays <https://minesweeper-coop.lacon.workers.dev/>.
- [x] `kPrivacyPolicyUrl` set in `about_screen.dart`.
- [x] `flutter analyze` clean, `flutter test` green.
- [x] UGC safety tools shipped (filter / report / block / kick) — see §5b.
- [ ] AAB built and uploaded to a **Closed testing** track.
- [ ] Listing copy (§4 — **no "no ads" claim**), feature graphic 1024×500,
      ≥2 phone screenshots, 512×512 icon uploaded.
- [ ] Data safety form completed per §5 — including **advertising ID**.
- [ ] Content rating + target audience completed per §5b (13+, users interact).
- [ ] "Contains ads" ticked; in-app products declared.
- [ ] Tested the closed-test build on a real device (online + LAN play, plus
      report / block / kick end-to-end with two devices).
- [ ] Relay redeployed (`cd relay && npm run deploy`) so kicked guests report
      `left` back to the host. Optional — the host removes them locally either
      way — but it keeps the relay's view of the room accurate.

---

## Deferred (next phases, not blocking release)
- iOS support (no `ios/` target yet).
- Integration tests for the transport/session layers.
- Scoping `usesCleartextTraffic` to private IP ranges with a network security
  config (currently app-wide, needed for LAN `ws://`).
