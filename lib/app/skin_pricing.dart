import 'board_skin.dart';

/// The id of the one skin that is owned for free from first launch, so the
/// board always has a usable look before any purchase.
const String kFreeSkinId = 'classic';

/// Coin price per [CellStructure] tier. The plain grass color-variants are the
/// cheapest; the more elaborate structures cost more. The free default skin
/// ([kFreeSkinId]) overrides this to 0 — see [skinPrice].
const Map<CellStructure, int> _structurePrice = {
  CellStructure.grass: 500,
  CellStructure.flat: 1000,
  CellStructure.tile: 1200,
  CellStructure.bevel: 1500,
  CellStructure.neon: 2500,
  CellStructure.neumorphic: 3000,
};

/// The coin cost to unlock [skin]. The free default skin costs 0; everything
/// else is priced by its structural tier. Pure and deterministic — derived
/// from the skin's own fields, so the large `kBoardSkins` literal needs no
/// per-entry price field.
int skinPrice(BoardSkin skin) {
  if (skin.id == kFreeSkinId) return 0;
  return _structurePrice[skin.structure] ?? 1000;
}
