import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/board_skin.dart';
import '../app/skin_pricing.dart';
import '../core/prefs.dart';

/// Coin balance granted on first launch (and by the debug reset). No ad/earn
/// source is wired yet, so this is simply the starting wallet.
const int kStartingCoins = 10000;

const String _kCoinsKey = 'store.coins';
const String _kOwnedKey = 'store.owned';

/// The player's persisted wallet and unlocked-skin set. Immutable; mutate
/// through [StoreNotifier], which mirrors every change into SharedPreferences.
class StoreState {
  const StoreState({required this.coins, required this.ownedSkinIds});

  final int coins;
  final Set<String> ownedSkinIds;

  bool owns(String skinId) => ownedSkinIds.contains(skinId);

  StoreState copyWith({int? coins, Set<String>? ownedSkinIds}) => StoreState(
        coins: coins ?? this.coins,
        ownedSkinIds: ownedSkinIds ?? this.ownedSkinIds,
      );
}

/// Persisted coins + owned skins. Reads the initial state from
/// SharedPreferences on build and writes back on every mutation, so progress
/// survives app restarts. The free default skin ([kFreeSkinId]) is always owned.
final storeProvider =
    NotifierProvider<StoreNotifier, StoreState>(StoreNotifier.new);

class StoreNotifier extends Notifier<StoreState> {
  @override
  StoreState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final coins = prefs.getInt(_kCoinsKey) ?? kStartingCoins;
    final owned = {...?prefs.getStringList(_kOwnedKey), kFreeSkinId};
    return StoreState(coins: coins, ownedSkinIds: owned);
  }

  /// Attempts to unlock [skin]. Returns true if the purchase succeeded (enough
  /// coins and not already owned), false otherwise.
  bool buy(BoardSkin skin) {
    if (state.owns(skin.id)) return false;
    final price = skinPrice(skin);
    if (state.coins < price) return false;
    state = state.copyWith(
      coins: state.coins - price,
      ownedSkinIds: {...state.ownedSkinIds, skin.id},
    );
    _persist();
    return true;
  }

  /// Adds coins to the wallet (e.g. a future rewarded-ad source). Not yet
  /// surfaced in the UI.
  void addCoins(int amount) {
    if (amount <= 0) return;
    state = state.copyWith(coins: state.coins + amount);
    _persist();
  }

  /// Debug: wipe back to the first-launch state.
  void resetDebug() {
    state = const StoreState(
      coins: kStartingCoins,
      ownedSkinIds: {kFreeSkinId},
    );
    _persist();
  }

  void _persist() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt(_kCoinsKey, state.coins);
    prefs.setStringList(_kOwnedKey, state.ownedSkinIds.toList());
  }
}
