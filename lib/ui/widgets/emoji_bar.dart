import 'package:flutter/material.dart';

class EmojiBar extends StatelessWidget {
  const EmojiBar({super.key, required this.onSend});
  final ValueChanged<String> onSend;

  static const _emojis = ['🎉', '👍', '🤔', '😱', '🚩', '😅'];

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
                  icon: Text(e, style: const TextStyle(fontSize: 20)),
                ))
            .toList(),
      ),
    );
  }
}
