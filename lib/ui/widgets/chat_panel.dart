import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../net/messages.dart';
import '../../state/chat.dart';
import '../../state/session.dart';
import 'avatar.dart';
import 'pressable.dart';

/// The chat surface itself: a scrolling transcript plus a composer. Hosted
/// inside `ChatOverlay`, which handles where it sits (bottom-sheet on mobile,
/// side panel on wide screens) and keyboard insets.
class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _jumpToBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  void _send() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    ref.read(sessionProvider.notifier).sendChat(text);
    _controller.clear();
    // Keep the keyboard up for a quick back-and-forth.
    _focus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final cs = Theme.of(context).colorScheme;

    // Autoscroll when a new line arrives.
    ref.listen(chatProvider.select((s) => s.messages.length), (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
    });

    final messages = ref.watch(chatProvider.select((s) => s.messages));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_rounded, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Chat',
                style: GoogleFonts.fredoka(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Close',
                visualDensity: VisualDensity.compact,
                onPressed: () => ref.read(chatProvider.notifier).close(),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: g.panelBorder),
        // ── Transcript ──
        Expanded(
          child: messages.isEmpty
              ? _EmptyState(color: cs.onSurfaceVariant)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  itemCount: messages.length,
                  itemBuilder: (_, i) => _Bubble(message: messages[i]),
                ),
        ),
        Divider(height: 1, color: g.panelBorder),
        // ── Composer ──
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 280,
                  textInputAction: TextInputAction.send,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Message…',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _SendButton(onTap: _send),
            ],
          ),
        ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.primary,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.send_rounded, color: cs.onPrimary, size: 20),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.forum_outlined, size: 40, color: color),
          const SizedBox(height: 10),
          Text(
            'No messages yet — say hi!',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message});
  final ChatMessage message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final cs = Theme.of(context).colorScheme;

    // Prefer the author's live player info (so a renamed/rejoined player shows
    // their current avatar/color); fall back to the snapshot stored on the
    // message if they've since left.
    final PlayerInfo? live =
        ref.watch(sessionProvider.select((s) => s.snapshot?.playerById(message.playerId)));
    final name = live?.name ?? message.name;
    final seed = live?.avatarSeed ?? message.playerId;
    final color = live != null ? Color(live.color) : null;

    if (message.mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8, left: 32),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.16),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: SelectableText(
              message.text,
              style: TextStyle(color: cs.onSurface, height: 1.25),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(seed: seed, label: name, size: 26, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color ?? cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: g.panel,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    border: Border.all(color: g.panelBorder),
                  ),
                  child: SelectableText(
                    message.text,
                    style: TextStyle(color: cs.onSurface, height: 1.25),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
