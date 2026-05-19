enum Difficulty {
  easy('Easy', 9, 9, 10),
  medium('Medium', 16, 16, 40),
  hard('Hard', 30, 16, 99);

  const Difficulty(this.label, this.width, this.height, this.mines);

  final String label;
  final int width;
  final int height;
  final int mines;

  static Difficulty fromName(String name) =>
      Difficulty.values.firstWhere((d) => d.name == name, orElse: () => easy);
}

/// Rules for how a mine hit affects the game.
enum GameMode {
  /// Hitting any mine ends the game immediately.
  classic,

  /// The team shares N hearts. Hitting a mine triggers a chain explosion
  /// (reveals 3x3 around it; chains through adjacent mines). One trigger
  /// click costs one heart regardless of how many mines chain. Hearts at 0
  /// ends the game.
  hearts,
}

class GameConfig {
  const GameConfig({
    required this.width,
    required this.height,
    required this.mines,
    this.mode = GameMode.classic,
    this.initialHearts = 1,
  })  : assert(width > 0 && height > 0),
        assert(mines > 0 && mines < width * height),
        assert(initialHearts > 0);

  factory GameConfig.fromDifficulty(
    Difficulty d, {
    GameMode mode = GameMode.classic,
    int hearts = 3,
  }) =>
      GameConfig(
        width: d.width,
        height: d.height,
        mines: d.mines,
        mode: mode,
        initialHearts: mode == GameMode.hearts ? hearts : 1,
      );

  factory GameConfig.fromJson(Map<String, dynamic> json) => GameConfig(
        width: json['width'] as int,
        height: json['height'] as int,
        mines: json['mines'] as int,
        mode: _parseMode(json['mode']),
        initialHearts: json['initialHearts'] as int? ?? 1,
      );

  final int width;
  final int height;
  final int mines;
  final GameMode mode;
  final int initialHearts;

  int get cellCount => width * height;

  GameConfig copyWith({
    int? width,
    int? height,
    int? mines,
    GameMode? mode,
    int? initialHearts,
  }) =>
      GameConfig(
        width: width ?? this.width,
        height: height ?? this.height,
        mines: mines ?? this.mines,
        mode: mode ?? this.mode,
        initialHearts: initialHearts ?? this.initialHearts,
      );

  Map<String, dynamic> toJson() => {
        'width': width,
        'height': height,
        'mines': mines,
        'mode': mode.name,
        'initialHearts': initialHearts,
      };

  static GameMode _parseMode(Object? raw) {
    if (raw is! String) return GameMode.classic;
    for (final m in GameMode.values) {
      if (m.name == raw) return m;
    }
    return GameMode.classic;
  }
}
