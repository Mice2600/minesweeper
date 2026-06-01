import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/difficulty.dart';
import 'difficulty_picker.dart';
import 'game_panel.dart';

/// Read-only summary of the match parameters the host has chosen. Shown to a
/// joining player while they wait, and updates live as the host changes
/// settings (the host re-broadcasts the lobby on every change).
class MatchSummary extends StatelessWidget {
  const MatchSummary({super.key, required this.config});
  final GameConfig config;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final preset = BoardPreset.fromConfig(config, customSelected: false);
    final diffName = switch (preset) {
      BoardPreset.easy => 'Easy',
      BoardPreset.medium => 'Medium',
      BoardPreset.hard => 'Hard',
      BoardPreset.custom => 'Custom',
    };
    final isHearts = config.mode == GameMode.hearts;

    return GamePanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 17, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Match settings',
                style: GoogleFonts.fredoka(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                'set by host',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _Row(
            icon: Icons.grid_view_rounded,
            label: 'Board',
            value: '$diffName · ${config.width}×${config.height}',
          ),
          _Divider(),
          _Row(
            icon: Icons.dangerous_outlined,
            label: 'Mines',
            value: '${config.mines}',
          ),
          _Divider(),
          _Row(
            icon: isHearts ? Icons.favorite_rounded : Icons.bolt_rounded,
            label: 'Mode',
            value: isHearts ? 'Lives · ${config.initialHearts}♥' : 'Classic',
            valueTint: isHearts ? const Color(0xFFE53935) : null,
          ),
          _Divider(),
          _Row(
            icon: Icons.flag_rounded,
            label: 'Auto-flag chord',
            value: config.autoFlagChord ? 'On' : 'Off',
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.valueTint,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color? valueTint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: valueTint ?? cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
  }
}
