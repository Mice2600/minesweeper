import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../ads/ads.dart';
import '../../analytics/analytics.dart';
import '../../app/board_skin.dart';
import '../../app/coin_packs.dart';
import '../../app/skin_pricing.dart';
import '../../app/theme.dart';
import '../../state/ad_gate.dart';
import '../../state/iap.dart';
import '../../state/skin.dart';
import '../../state/store.dart';
import '../widgets/coin_pill.dart';
import '../widgets/menu_banner.dart';
import '../widgets/pressable.dart';
import '../widgets/skin_picker.dart';

/// The skin Store: spend coins to unlock board skins, then equip the ones you
/// own. Reachable from the main menu and from the in-game skin picker.
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final equipped = ref.watch(boardSkinProvider);
    final iap = ref.watch(iapProvider);

    // Surface a billing error as a SnackBar.
    ref.listen(iapProvider.select((s) => s.error), (_, err) {
      if (err == null || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(err),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
    });
    // A coin-balance increase means a pack purchase landed → celebrate it.
    ref.listen(storeProvider.select((s) => s.coins), (prev, next) {
      if (prev == null || next <= prev || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('+${next - prev} coins added — thank you!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1600),
        ));
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: const MenuBanner(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Store',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: CoinPill(coins: store.coins)),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            if (iap.available || Ads.instance.available) ...[
              SliverToBoxAdapter(
                child: _CoinPacksSection(
                  iap: iap,
                  showRewarded: Ads.instance.available,
                ),
              ),
              _SliverSectionHeader(label: 'Board skins'),
            ],
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 200,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.82,
                ),
                itemCount: kBoardSkins.length,
                itemBuilder: (ctx, i) {
                  final skin = kBoardSkins[i];
                  return _StoreCard(
                    skin: skin,
                    owned: store.owns(skin.id),
                    equipped: skin.id == equipped.id,
                    price: skinPrice(skin),
                    affordable: store.coins >= skinPrice(skin),
                    onTap: () => _onTap(context, ref, skin),
                  ).animate().fadeIn(
                        delay: (20 * (i % 8)).ms,
                        duration: 250.ms,
                      );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onTap(BuildContext context, WidgetRef ref, BoardSkin skin) {
    final store = ref.read(storeProvider);
    final cs = Theme.of(context).colorScheme;

    if (store.owns(skin.id)) {
      ref.read(boardSkinProvider.notifier).select(skin);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Equipped ${skin.name}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1200),
        ));
      return;
    }

    final price = skinPrice(skin);
    if (store.coins < price) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Not enough coins — ${skin.name} costs $price'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: cs.error,
        ));
      return;
    }

    _confirmPurchase(context, ref, skin, price);
  }

  Future<void> _confirmPurchase(
    BuildContext context,
    WidgetRef ref,
    BoardSkin skin,
    int price,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Unlock ${skin.name}?', style: GoogleFonts.fredoka()),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This costs '),
            const Icon(Icons.monetization_on_rounded,
                color: Color(0xFFFFB300), size: 18),
            const SizedBox(width: 3),
            Text('$price',
                style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w800)),
            const Text(' coins.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    final bought = ref.read(storeProvider.notifier).buy(skin);
    if (!bought || !context.mounted) return;

    // Auto-equip the freshly unlocked skin.
    ref.read(boardSkinProvider.notifier).select(skin);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Unlocked & equipped ${skin.name}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ));
  }
}

/// A simple section title rendered as a sliver (used between coins and skins).
class _SliverSectionHeader extends StatelessWidget {
  const _SliverSectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

/// Horizontal strip of ways to get coins: an optional "watch ad" card (Android
/// with ads ready) followed by the real-money packs (when billing is available).
class _CoinPacksSection extends ConsumerWidget {
  const _CoinPacksSection({required this.iap, required this.showRewarded});
  final IapState iap;
  final bool showRewarded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final cards = <Widget>[
      if (showRewarded)
        _RewardedCard(onTap: () => _watchRewarded(context, ref)),
      if (iap.available)
        for (final pack in kCoinPacks)
          _CoinPackCard(
            pack: pack,
            priceLabel: iap.products[pack.productId]?.price,
            pending: iap.pendingProductId == pack.productId,
            // Disable all buy buttons while any purchase is in flight.
            enabled: iap.products[pack.productId] != null &&
                iap.pendingProductId == null,
            onBuy: () => ref.read(iapProvider.notifier).buyCoins(pack),
          ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: Color(0xFFFFB300), size: 20),
              const SizedBox(width: 8),
              Text(
                'Get coins',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 158,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: cards.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, i) =>
                cards[i].animate().fadeIn(delay: (40 * i).ms, duration: 250.ms),
          ),
        ),
      ],
    );
  }

  void _watchRewarded(BuildContext context, WidgetRef ref) {
    final gate = ref.read(adGateProvider.notifier);
    if (!Ads.instance.rewardedReady) {
      _snack(context, 'Ad not ready yet — try again in a moment.');
      return;
    }
    if (!gate.rewardedReady()) {
      _snack(context, 'More free coins in ${gate.rewardedCooldownRemaining()}s.');
      return;
    }
    Ads.instance.showRewarded(onReward: () {
      // The store's coin-increase listener shows the "+coins" thank-you.
      ref.read(storeProvider.notifier).addCoins(kRewardedCoins);
      gate.recordRewarded();
      Analytics.instance.adRewardEarned(coins: kRewardedCoins);
    });
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1400),
      ));
  }
}

/// "Watch ad → free coins" card, styled to sit alongside the coin packs.
class _RewardedCard extends StatelessWidget {
  const _RewardedCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return Container(
      width: 138,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.tertiary.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: g.panelShadow, blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Icon(Icons.smart_display_rounded, color: cs.tertiary, size: 30),
              const SizedBox(height: 4),
              Text(
                '+$kRewardedCoins',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              Text(
                'Free coins',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: FilledButton.tonal(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: cs.tertiary.withValues(alpha: 0.18),
                foregroundColor: cs.tertiary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'Watch ad',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinPackCard extends StatelessWidget {
  const _CoinPackCard({
    required this.pack,
    required this.priceLabel,
    required this.pending,
    required this.enabled,
    required this.onBuy,
  });

  final CoinPack pack;
  final String? priceLabel;
  final bool pending;
  final bool enabled;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return Container(
      width: 138,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: g.panelBorder, width: 1),
        boxShadow: [
          BoxShadow(
              color: g.panelShadow, blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: Color(0xFFFFB300), size: 30),
              const SizedBox(height: 4),
              Text(
                '${pack.coins}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              Text(
                pack.label,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              if (pack.badge != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.tertiary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pack.badge!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: cs.tertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 34,
            child: FilledButton(
              onPressed: enabled ? onBuy : null,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: pending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      priceLabel ?? '—',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  const _StoreCard({
    required this.skin,
    required this.owned,
    required this.equipped,
    required this.price,
    required this.affordable,
    required this.onTap,
  });

  final BoardSkin skin;
  final bool owned;
  final bool equipped;
  final int price;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final borderColor = equipped
        ? cs.primary
        : owned
            ? cs.primary.withValues(alpha: 0.35)
            : g.panelBorder;

    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: g.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
            width: equipped ? 2.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: g.panelShadow, blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  SkinPreview(skin: skin),
                  if (!owned)
                    Container(
                      color: Colors.black
                          .withValues(alpha: affordable ? 0.32 : 0.55),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.lock_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                        size: 28,
                      ),
                    ),
                  if (equipped)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: cs.primary,
                        child: const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    skin.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.nunito(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _Footer(
                    owned: owned,
                    equipped: equipped,
                    price: price,
                    affordable: affordable,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.owned,
    required this.equipped,
    required this.price,
    required this.affordable,
  });

  final bool owned;
  final bool equipped;
  final int price;
  final bool affordable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (equipped) {
      return _tag(cs.primary, Icons.check_circle_rounded, 'Equipped');
    }
    if (owned) {
      return _tag(cs.onSurfaceVariant, Icons.touch_app_rounded, 'Tap to equip');
    }
    // Locked: show price, dimmed if unaffordable.
    final color = affordable ? cs.onSurface : cs.onSurfaceVariant;
    return Row(
      children: [
        Icon(Icons.monetization_on_rounded,
            color: affordable ? const Color(0xFFFFB300) : cs.onSurfaceVariant,
            size: 16),
        const SizedBox(width: 4),
        Text(
          '$price',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _tag(Color color, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
