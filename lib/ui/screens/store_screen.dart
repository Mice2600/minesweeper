import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/board_skin.dart';
import '../../app/skin_pricing.dart';
import '../../app/theme.dart';
import '../../state/skin.dart';
import '../../state/store.dart';
import '../widgets/coin_pill.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
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
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
