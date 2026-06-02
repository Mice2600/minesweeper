/// Real-money coin packs sold via in-app purchase.
///
/// The [CoinPack.productId]s MUST exactly match the in-app product IDs created
/// in the Google Play Console — they are the contract between the app and the
/// store. Real prices are configured per-region in Play Console; the app only
/// maps a product id to a coin amount and displays the store's localized price.
class CoinPack {
  const CoinPack({
    required this.productId,
    required this.label,
    required this.coins,
    this.badge,
  });

  /// Google Play in-app product id. Must match Play Console exactly.
  final String productId;

  /// Display name on the pack card.
  final String label;

  /// Coins granted on a successful purchase. This is the trusted amount —
  /// looked up server-side by [coinPackForId], never read from the client.
  final int coins;

  /// Optional value flag, e.g. "+20%".
  final String? badge;
}

/// The catalogue, cheapest first.
const List<CoinPack> kCoinPacks = [
  CoinPack(productId: 'coins_handful', label: 'Handful', coins: 1000),
  CoinPack(productId: 'coins_stack', label: 'Stack', coins: 5500, badge: '+10%'),
  CoinPack(productId: 'coins_chest', label: 'Chest', coins: 12000, badge: '+20%'),
  CoinPack(productId: 'coins_vault', label: 'Vault', coins: 30000, badge: '+50%'),
];

/// Product ids to query from the store.
final Set<String> kCoinProductIds = {for (final p in kCoinPacks) p.productId};

/// Looks up the pack (and therefore the trusted coin amount) for a purchased
/// product id. Returns null for an unknown id, so an unexpected purchase never
/// grants coins.
CoinPack? coinPackForId(String productId) {
  for (final p in kCoinPacks) {
    if (p.productId == productId) return p;
  }
  return null;
}
