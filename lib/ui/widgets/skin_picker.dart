import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/board_skin.dart';
import '../../app/skin_pricing.dart';
import '../../state/skin.dart';
import '../../state/store.dart';
import 'cell_tile.dart';

/// Opens a bottom sheet to pick the board skin. Owned skins apply instantly
/// (the board watches [boardSkinProvider]) and close the sheet. Locked skins
/// show a lock + price; tapping one closes the sheet and opens the Store.
Future<void> showSkinPicker(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => const _SkinPickerSheet(),
  );
}

class _SkinPickerSheet extends ConsumerWidget {
  const _SkinPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(boardSkinProvider);
    final store = ref.watch(storeProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                'Board skin',
                style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate:
                    const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.45,
                ),
                itemCount: kBoardSkins.length,
                itemBuilder: (ctx, i) {
                  final skin = kBoardSkins[i];
                  final owned = store.owns(skin.id);
                  return _SkinCard(
                    skin: skin,
                    selected: skin.id == current.id,
                    locked: !owned,
                    price: skinPrice(skin),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      if (owned) {
                        ref.read(boardSkinProvider.notifier).select(skin);
                      } else {
                        ctx.push('/store');
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  const _SkinCard({
    required this.skin,
    required this.selected,
    required this.locked,
    required this.price,
    required this.onTap,
  });

  final BoardSkin skin;
  final bool selected;
  final bool locked;
  final int price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? accent : Theme.of(context).dividerColor,
              width: selected ? 2.5 : 1,
            ),
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
                    if (locked) _LockOverlay(price: price),
                    if (selected && !locked)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: accent,
                          child: const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                child: Text(
                  skin.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A scrim with a lock and price drawn over a locked skin's preview.
class _LockOverlay extends StatelessWidget {
  const _LockOverlay({required this.price});

  final int price;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.42),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, color: Colors.white, size: 26),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.monetization_on_rounded,
                  color: Color(0xFFFFD54F), size: 15),
              const SizedBox(width: 3),
              Text(
                '$price',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A small live board snippet rendered with the REAL [CellTile], so each skin's
/// structure (gaps, bevels, hairlines, glow) — not just its colors — shows in
/// the picker and store. Truthful by construction: it shares the production
/// render path.
class SkinPreview extends StatelessWidget {
  const SkinPreview({super.key, required this.skin});

  final BoardSkin skin;

  /// Sample mini-board as `(value, flagged)` per cell. value: -2 hidden,
  /// -1 mine, 0 empty, 1..8 numbers. One flagged hidden cell shows the glyph.
  static const _sample = <List<(int, bool)>>[
    [(-2, true), (-2, false), (-2, false), (-2, false)],
    [(1, false), (2, false), (3, false), (0, false)],
    [(-1, false), (1, false), (-2, false), (2, false)],
  ];

  // A representative "player" color for the flagged sample cell.
  static const _sampleFlag = Color(0xFF2C7BE5);

  @override
  Widget build(BuildContext context) {
    const cols = 4;
    final rows = _sample.length;
    // Gaps show the board background (tile/neon/neumorphic); full-bleed
    // structures cover it, so any value is fine there.
    final bg = skin.boardBackground != Colors.transparent
        ? skin.boardBackground
        : Theme.of(context).colorScheme.surfaceContainerHighest;

    return LayoutBuilder(
      builder: (ctx, c) {
        final cell =
            (c.maxWidth / cols).clamp(0.0, c.maxHeight / rows).toDouble();
        return Container(
          color: bg,
          alignment: Alignment.center,
          child: SizedBox(
            width: cell * cols,
            height: cell * rows,
            child: Column(
              children: [
                for (var y = 0; y < rows; y++)
                  Row(
                    children: [
                      for (var x = 0; x < cols; x++)
                        SizedBox(
                          width: cell,
                          height: cell,
                          child: CellTile(
                            value: _sample[y][x].$1,
                            flagColor: _sample[y][x].$2 ? _sampleFlag : null,
                            questionColor: null,
                            size: cell,
                            x: x,
                            y: y,
                            skin: skin,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
