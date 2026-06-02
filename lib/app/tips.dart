/// Optional "tip the developer" products, sold via in-app purchase. Unlike coin
/// packs, a tip grants nothing in-game — it's a pure thank-you.
///
/// The [TipTier.productId]s MUST match the in-app product IDs in Google Play
/// Console exactly. Real prices are set in Play Console.
class TipTier {
  const TipTier({
    required this.productId,
    required this.label,
    required this.emoji,
  });

  /// Google Play in-app product id. Must match Play Console exactly.
  final String productId;

  /// Display name on the tip option.
  final String label;

  /// Decorative emoji for the option.
  final String emoji;
}

/// Tip options, cheapest first. Suggested prices: ~$0.99 / $2.99 / $4.99.
const List<TipTier> kTips = [
  TipTier(productId: 'tip_small', label: 'Small tip', emoji: '☕'),
  TipTier(productId: 'tip_medium', label: 'Medium tip', emoji: '🍰'),
  TipTier(productId: 'tip_large', label: 'Large tip', emoji: '🎁'),
];

/// Product ids to query from the store.
final Set<String> kTipProductIds = {for (final t in kTips) t.productId};

/// Whether a purchased product id is a developer tip (vs. a coin pack).
bool isTipProduct(String productId) => kTipProductIds.contains(productId);
