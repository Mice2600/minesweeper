import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../analytics/analytics.dart';
import '../app/coin_packs.dart';
import '../app/tips.dart';
import 'store.dart';

/// True only where `in_app_purchase` can actually transact (Android here).
/// Web and Windows have no billing support, so the whole feature is gated off.
final bool _iapSupportedPlatform =
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

/// Snapshot of the billing connection for the UI to watch.
class IapState {
  const IapState({
    this.available = false,
    this.loading = false,
    this.products = const {},
    this.pendingProductId,
    this.error,
    this.tipThanksNonce = 0,
  });

  /// Billing is reachable and at least one coin product is for sale. When
  /// false the "Get coins" UI is hidden entirely.
  final bool available;

  /// Querying products / a purchase is in flight.
  final bool loading;

  /// Live store products keyed by product id (carries the localized price).
  final Map<String, ProductDetails> products;

  /// Product id whose purchase sheet is currently open, if any.
  final String? pendingProductId;

  /// Last user-facing error, if any.
  final String? error;

  /// Increments after each successful developer tip, so the UI can pop a
  /// one-shot thank-you.
  final int tipThanksNonce;

  IapState copyWith({
    bool? available,
    bool? loading,
    Map<String, ProductDetails>? products,
    String? pendingProductId,
    bool clearPending = false,
    String? error,
    bool clearError = false,
    bool bumpThanks = false,
  }) =>
      IapState(
        available: available ?? this.available,
        loading: loading ?? this.loading,
        products: products ?? this.products,
        pendingProductId:
            clearPending ? null : (pendingProductId ?? this.pendingProductId),
        error: clearError ? null : (error ?? this.error),
        tipThanksNonce: tipThanksNonce + (bumpThanks ? 1 : 0),
      );
}

/// Owns the billing connection: queries the coin products, listens for purchase
/// updates, and grants coins through [StoreNotifier.addCoins] on success. The
/// coin amount is always looked up from [coinPackForId] (server-trusted), never
/// taken from the client.
final iapProvider =
    NotifierProvider<IapNotifier, IapState>(IapNotifier.new);

class IapNotifier extends Notifier<IapState> {
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  IapState build() {
    if (!_iapSupportedPlatform) {
      return const IapState(available: false);
    }
    _sub = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdate,
      onError: (Object e) =>
          state = state.copyWith(error: 'Store error: $e', clearPending: true),
    );
    ref.onDispose(() => _sub?.cancel());
    // Kick off async init; state updates when it resolves.
    unawaited(_init());
    return const IapState(loading: true);
  }

  Future<void> _init() async {
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        state = const IapState(available: false, loading: false);
        return;
      }
      final response = await InAppPurchase.instance
          .queryProductDetails({...kCoinProductIds, ...kTipProductIds});
      final map = {for (final p in response.productDetails) p.id: p};
      state = state.copyWith(
        available: map.isNotEmpty,
        loading: false,
        products: map,
        clearError: true,
      );
    } catch (e) {
      state = const IapState(available: false, loading: false);
      if (kDebugMode) debugPrint('[iap] init failed: $e');
    }
  }

  /// Starts the Play purchase flow for [pack]. The outcome arrives via the
  /// purchase stream ([_onPurchaseUpdate]).
  Future<void> buyCoins(CoinPack pack) => _buy(pack.productId);

  /// Starts the Play purchase flow for a developer tip.
  Future<void> buyTip(TipTier tip) => _buy(tip.productId);

  Future<void> _buy(String productId) async {
    final product = state.products[productId];
    if (product == null) {
      state = state.copyWith(error: 'That item is unavailable right now.');
      return;
    }
    state = state.copyWith(pendingProductId: productId, clearError: true);
    try {
      await InAppPurchase.instance.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: product),
      );
    } catch (e) {
      state = state.copyWith(error: 'Could not start purchase: $e', clearPending: true);
    }
  }

  void _onPurchaseUpdate(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          state = state.copyWith(pendingProductId: purchase.productID);
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          final wasTip = _grant(purchase);
          state = state.copyWith(
              clearPending: true, clearError: true, bumpThanks: wasTip);
        case PurchaseStatus.error:
          state = state.copyWith(
            error: purchase.error?.message ?? 'Purchase failed.',
            clearPending: true,
          );
        case PurchaseStatus.canceled:
          state = state.copyWith(clearPending: true);
      }
      // Always acknowledge, or Google will refund the purchase after 3 days.
      if (purchase.pendingCompletePurchase) {
        unawaited(InAppPurchase.instance.completePurchase(purchase));
      }
    }
  }

  /// Applies a completed purchase. Returns true if it was a developer tip (so
  /// the caller can show a thank-you). Coins are granted from the trusted
  /// [coinPackForId] table, never a client value.
  bool _grant(PurchaseDetails purchase) {
    final pack = coinPackForId(purchase.productID);
    if (pack != null) {
      ref.read(storeProvider.notifier).addCoins(pack.coins);
      Analytics.instance
          .coinPackPurchased(productId: pack.productId, coins: pack.coins);
      return false;
    }
    if (isTipProduct(purchase.productID)) {
      Analytics.instance.tipPurchased(productId: purchase.productID);
      return true;
    }
    return false; // unknown product → grant nothing
  }
}
