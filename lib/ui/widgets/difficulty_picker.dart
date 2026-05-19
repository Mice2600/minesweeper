import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/difficulty.dart';

/// 4-segment mode selector: Easy / Medium / Hard / Custom.
class ModePicker extends StatelessWidget {
  const ModePicker({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final BoardPreset mode;
  final ValueChanged<BoardPreset> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<BoardPreset>(
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      segments: const [
        ButtonSegment(value: BoardPreset.easy, label: Text('Easy')),
        ButtonSegment(value: BoardPreset.medium, label: Text('Medium')),
        ButtonSegment(value: BoardPreset.hard, label: Text('Hard')),
        ButtonSegment(value: BoardPreset.custom, label: Text('Custom')),
      ],
      selected: {mode},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

enum BoardPreset {
  easy,
  medium,
  hard,
  custom;

  static BoardPreset fromConfig(GameConfig cfg, {required bool customSelected}) {
    if (customSelected) return BoardPreset.custom;
    for (final d in Difficulty.values) {
      if (d.width == cfg.width &&
          d.height == cfg.height &&
          d.mines == cfg.mines) {
        return switch (d) {
          Difficulty.easy => BoardPreset.easy,
          Difficulty.medium => BoardPreset.medium,
          Difficulty.hard => BoardPreset.hard,
        };
      }
    }
    return BoardPreset.custom;
  }

  GameConfig? toPresetConfig() => switch (this) {
        BoardPreset.easy => GameConfig.fromDifficulty(Difficulty.easy),
        BoardPreset.medium => GameConfig.fromDifficulty(Difficulty.medium),
        BoardPreset.hard => GameConfig.fromDifficulty(Difficulty.hard),
        BoardPreset.custom => null,
      };
}

class CustomConfigEditor extends StatelessWidget {
  const CustomConfigEditor({
    super.key,
    required this.config,
    required this.onChanged,
  });

  final GameConfig config;
  final ValueChanged<GameConfig> onChanged;

  static const minW = 9;
  static const maxW = 60;
  static const minH = 9;
  static const maxH = 40;
  static const minMines = 9;

  /// Reserve a 9-cell first-click safe zone.
  static int maxMinesFor(int w, int h) => (w * h - 9).clamp(minMines, 9999);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxMines = maxMinesFor(config.width, config.height);
    final mines = config.mines.clamp(minMines, maxMines);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SliderRow(
            label: 'Width',
            range: '$minW – $maxW',
            value: config.width,
            min: minW,
            max: maxW,
            onChanged: (v) {
              final clampedMines =
                  config.mines.clamp(minMines, maxMinesFor(v, config.height));
              onChanged(GameConfig(
                width: v,
                height: config.height,
                mines: clampedMines,
              ));
            },
          ),
          const SizedBox(height: 4),
          _SliderRow(
            label: 'Height',
            range: '$minH – $maxH',
            value: config.height,
            min: minH,
            max: maxH,
            onChanged: (v) {
              final clampedMines =
                  config.mines.clamp(minMines, maxMinesFor(config.width, v));
              onChanged(GameConfig(
                width: config.width,
                height: v,
                mines: clampedMines,
              ));
            },
          ),
          const SizedBox(height: 4),
          _SliderRow(
            label: 'Mines',
            range: '$minMines – $maxMines',
            value: mines,
            min: minMines,
            max: maxMines,
            onChanged: (v) {
              onChanged(GameConfig(
                width: config.width,
                height: config.height,
                mines: v,
              ));
            },
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.range,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final String range;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(range,
                  style: TextStyle(
                      fontSize: 11, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Container(
          width: 56,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Text(
            '$value',
            style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}
