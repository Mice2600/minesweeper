import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/board_skin.dart';
import '../core/prefs.dart';

const String _kSelectedSkinKey = 'store.selectedSkin';

/// The board skin currently applied to the game map. Persisted across restarts
/// (the equipped skin id is stored in SharedPreferences). Selecting is gated to
/// owned skins by the UI; this notifier itself just applies and remembers.
final boardSkinProvider =
    NotifierProvider<BoardSkinNotifier, BoardSkin>(BoardSkinNotifier.new);

class BoardSkinNotifier extends Notifier<BoardSkin> {
  @override
  BoardSkin build() {
    final id = ref.read(sharedPreferencesProvider).getString(_kSelectedSkinKey);
    return kBoardSkins.firstWhere(
      (s) => s.id == id,
      orElse: () => kDefaultBoardSkin,
    );
  }

  void select(BoardSkin skin) {
    state = skin;
    ref.read(sharedPreferencesProvider).setString(_kSelectedSkinKey, skin.id);
  }
}
