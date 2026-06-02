# In-App Purchases — setup guide (coin packs)

The IAP **code is fully wired**: a billing service ([lib/state/iap.dart](lib/state/iap.dart)),
the coin-pack catalogue ([lib/app/coin_packs.dart](lib/app/coin_packs.dart)), the
"Get coins" UI in the Store, and coin granting through the existing
`addCoins()` hook. Until the products exist in Play Console and the app is on a
test track, the "Get coins" section simply stays hidden (billing reports
unavailable) — the app builds and runs normally.

**Android only.** `in_app_purchase` has no web/Windows support, so the coin
section is hidden there by design. Spending coins on skins works everywhere.

---

## The product catalogue (code ↔ Play Console contract)

The product IDs below **must match Play Console exactly**. You set the real prices
in Play Console; the app displays whatever localized price the store returns.
All of these are **consumable** managed products.

**Coin packs** — defined in [lib/app/coin_packs.dart](lib/app/coin_packs.dart):

| Product ID (exact) | Pack | Coins granted | Suggested price |
|---|---|---|---|
| `coins_handful` | Handful | 1,000 | ~$0.99 |
| `coins_stack` | Stack | 5,500 (+10%) | ~$3.99 |
| `coins_chest` | Chest | 12,000 (+20%) | ~$7.99 |
| `coins_vault` | Vault | 30,000 (+50%) | ~$17.99 |

**Developer tips** (donation jar; grant nothing in-game) — defined in
[lib/app/tips.dart](lib/app/tips.dart):

| Product ID (exact) | Tip | Suggested price |
|---|---|---|
| `tip_small` | Small tip ☕ | ~$0.99 |
| `tip_medium` | Medium tip 🍰 | ~$2.99 |
| `tip_large` | Large tip 🎁 | ~$4.99 |

(Board skins cost 500–3,000 coins, so the packs feel generous. To change
amounts/IDs, edit `kCoinPacks` / `kTips` — but never change an ID after it's live.)

---

## 1. Create the products in Play Console

> You must have uploaded at least one signed AAB to a track first (Play won't let
> you create products until the app has an uploaded build with the billing
> permission — already added to the manifest).

1. Play Console → your app → **Monetize → Products → In-app products**.
2. **Create product** for each row above:
   - **Product ID** = the exact ID from the tables (e.g. `coins_handful`,
     `tip_small`).
   - Name / description (e.g. "Handful of Coins", "Small tip").
   - **Set a price**, then **Activate** the product.
3. Create **all seven** (4 coin packs + 3 tips). They must be **Active**.

## 2. Set up license testers (so test buys don't charge you)

1. Play Console → **Setup → License testing**.
2. Add the Google account(s) you'll test with.
3. These accounts get a test payment flow (no real charge) on internal/closed
   test builds.

## 3. Upload + test

1. `flutter build appbundle --release` → upload the AAB to **Internal testing**
   (fastest) or Closed testing.
2. Join the test track with a license-tester account, install from the Play link
   (must be the **Play-installed** build — sideloaded APKs can't do billing).
3. Open the in-app **Store**: the "Get coins" row now shows the four packs with
   real localized prices. The main menu shows a subtle **"♥ Support"** link that
   opens the tip jar.
4. Buy a coin pack → the Play purchase sheet (test card) → coin balance jumps by
   the pack amount + a "thank you" SnackBar. Buy a tip → "Thank you so much! 💜".
5. Confirm `coin_pack_purchased` / `tip_purchased` in **Firebase → Analytics →
   DebugView**.

---

## Donation = in-app tip jar (no external account needed)

The subtle "♥ Support" link on the main menu opens a **Play Billing tip jar**
(`tip_small` / `tip_medium` / `tip_large`). This was chosen because it pays out
through the **same Google Play wire transfer to your Uzbekistan bank** as the coin
sales — no Ko-fi/PayPal/Stripe (none of which support Uzbekistan payouts). Tips
grant nothing in-game. The link is hidden on web/Windows (billing is Android-only).

---

## How granting works (why it's safe)

On a successful purchase, [iap.dart](lib/state/iap.dart) looks up the coin amount
from `coinPackForId(productID)` — the **server-trusted** table — never from any
client-supplied value, then calls `addCoins()`. Purchases are always acknowledged
via `completePurchase()`, so Google won't auto-refund after 3 days. Coins are a
local cosmetic currency, so no receipt-validation backend is needed.

## Troubleshooting

- **"Get coins" not showing on a test device:** the product isn't Active, the IDs
  don't match, the build wasn't installed from Play, or the account isn't a
  license tester. Give Play ~a few hours after creating products.
- **Prices show "—":** products didn't load — same causes as above.
