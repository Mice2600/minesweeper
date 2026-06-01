import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/board_skin.dart';

/// The board skin currently applied to the game map. Session-only — resets to
/// [kDefaultBoardSkin] on app restart. Selected live from the game UI.
final boardSkinProvider =
    NotifierProvider<BoardSkinNotifier, BoardSkin>(BoardSkinNotifier.new);

class BoardSkinNotifier extends Notifier<BoardSkin> {
  @override
  BoardSkin build() => kDefaultBoardSkin;

  void select(BoardSkin skin) => state = skin;
}
