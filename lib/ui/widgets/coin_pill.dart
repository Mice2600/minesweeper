import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A coin balance chip: coin glyph + monospace count on a soft pill. Shared by
/// the main menu and the Store header.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on_rounded,
              color: Color(0xFFFFB300), size: 18),
          const SizedBox(width: 6),
          Text(
            '$coins',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
