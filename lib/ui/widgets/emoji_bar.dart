import 'package:flutter/material.dart';

import '../../core/moderation.dart';

/// Font fallbacks so emoji render as proper colour glyphs even though the app's
/// default text theme is Nunito (which has no emoji). Flutter tries the primary
/// family per-glyph, then walks these for anything missing.
const emojiFontFallback = <String>[
  'Apple Color Emoji', // iOS / macOS
  'Segoe UI Emoji', // Windows
  'Noto Color Emoji', // Android / Linux / web
  'Noto Emoji',
  'EmojiOne Color',
];

class EmojiBar extends StatelessWidget {
  const EmojiBar({super.key, required this.onSend});
  final ValueChanged<String> onSend;

  /// The set lives in [Moderation] because the host validates against it —
  /// keeping one list means the bar can't drift out of sync with what the
  /// host will actually accept and re-broadcast.
  static const _emojis = Moderation.emojiReactions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: _emojis
            .map((e) => IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onSend(e),
                  icon: Text(
                    e,
                    style: const TextStyle(
                      fontSize: 20,
                      fontFamilyFallback: emojiFontFallback,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}
