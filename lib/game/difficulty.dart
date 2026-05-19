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

class GameConfig {
  const GameConfig({
    required this.width,
    required this.height,
    required this.mines,
  })  : assert(width > 0 && height > 0),
        assert(mines > 0 && mines < width * height);

  factory GameConfig.fromDifficulty(Difficulty d) =>
      GameConfig(width: d.width, height: d.height, mines: d.mines);

  factory GameConfig.fromJson(Map<String, dynamic> json) => GameConfig(
        width: json['width'] as int,
        height: json['height'] as int,
        mines: json['mines'] as int,
      );

  final int width;
  final int height;
  final int mines;

  int get cellCount => width * height;

  Map<String, dynamic> toJson() =>
      {'width': width, 'height': height, 'mines': mines};
}
