import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/chat.dart';

/// App-bar chat toggle. Shows a flat unread-count badge when messages have
/// arrived while the panel was closed. Toggling opens [ChatPanel] (via the
/// shared [chatProvider] state, rendered by `ChatOverlay`) and marks read.
class ChatButton extends ConsumerWidget {
  const ChatButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(chatProvider.select((s) => s.unread));
    final open = ref.watch(chatProvider.select((s) => s.open));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          tooltip: 'Chat',
          onPressed: () => ref.read(chatProvider.notifier).toggle(),
          icon: Icon(
            open
                ? Icons.chat_bubble_rounded
                : Icons.chat_bubble_outline_rounded,
          ),
        ),
        if (unread > 0)
          Positioned(
            right: 4,
            top: 4,
            child: _Badge(count: unread),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: cs.surface, width: 1.5),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          color: cs.onError,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}
