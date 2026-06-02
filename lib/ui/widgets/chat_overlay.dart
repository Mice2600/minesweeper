import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../audio/sfx.dart';
import '../../state/chat.dart';
import '../../state/session.dart';
import 'avatar.dart';
import 'chat_panel.dart';

/// Floats [ChatPanel] over the screen without consuming layout. Drop it in as
/// the *last child* of a screen's body `Stack`: when closed it's an inert,
/// transparent overlay; when open it slides in — a bottom-sheet on narrow
/// screens, a right-docked panel on wide ones — over the board, never resizing
/// it. The keyboard is handled by the Scaffold's default bottom-inset resize,
/// which keeps the bottom-anchored panel above the keyboard.
class ChatOverlay extends ConsumerWidget {
  const ChatOverlay({super.key});

  static const _dur = Duration(milliseconds: 220);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(chatProvider.select((s) => s.open));
    final wide = MediaQuery.sizeOf(context).width >= 720;

    return Stack(
      children: [
        // Panel — ignores pointer when closed so the board stays interactive.
        IgnorePointer(
          ignoring: !open,
          child: Stack(
            children: [
              // Tap-to-dismiss scrim (mobile only).
              if (!wide)
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: _dur,
                    opacity: open ? 1 : 0,
                    child: GestureDetector(
                      onTap: () => ref.read(chatProvider.notifier).close(),
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.25),
                      ),
                    ),
                  ),
                ),
              if (wide)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  child: AnimatedSlide(
                    duration: _dur,
                    curve: Curves.easeOutCubic,
                    offset: open ? Offset.zero : const Offset(1, 0),
                    child: const _PanelShell(wide: true),
                  ),
                )
              else
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedSlide(
                    duration: _dur,
                    curve: Curves.easeOutCubic,
                    offset: open ? Offset.zero : const Offset(0, 1),
                    child: const _PanelShell(wide: false),
                  ),
                ),
            ],
          ),
        ),

        // Toast — always interactive, independent of panel state.
        const _ChatToast(),
      ],
    );
  }
}

// ──────────────────────────────────── Toast notification ─────────────────────

class _ChatToast extends ConsumerWidget {
  const _ChatToast();

  static const _dur = Duration(milliseconds: 260);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Play chat sound whenever the unread count increases.
    ref.listen<int>(
      chatProvider.select((s) => s.unread),
      (prev, next) {
        if (next > (prev ?? 0)) {
          ref.read(soundProvider).play(SfxKind.chat);
        }
      },
    );

    final open = ref.watch(chatProvider.select((s) => s.open));
    final unread = ref.watch(chatProvider.select((s) => s.unread));
    final lastMsg = ref.watch(chatProvider.select((s) => s.lastMessage));

    final visible = !open && unread > 0 && lastMsg != null;

    // Resolve live player info to get the photo avatar.
    final live = ref.watch(
      sessionProvider.select((s) => s.snapshot?.playerById(lastMsg?.playerId ?? '')),
    );

    final authorName = live?.name ?? lastMsg?.name ?? '';
    final seed = live?.avatarSeed ?? lastMsg?.playerId ?? '';
    final avatarData = live?.avatarData;
    final color = live != null ? Color(live.color) : null;
    final preview = _truncate(lastMsg?.text ?? '');

    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;

    return Positioned(
      top: 8,
      right: 8,
      child: AnimatedSlide(
        duration: _dur,
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(1.4, 0),
        child: AnimatedOpacity(
          duration: _dur,
          opacity: visible ? 1.0 : 0.0,
          child: IgnorePointer(
            ignoring: !visible,
            child: GestureDetector(
              onTap: () => ref.read(chatProvider.notifier).open(),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: g.panel,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: g.panelBorder, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: g.panelShadow,
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Avatar(
                      seed: seed,
                      label: authorName,
                      avatarData: avatarData,
                      size: 28,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            authorName,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color ?? cs.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            preview,
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _truncate(String text) {
    const max = 38;
    final trimmed = text.trim();
    return trimmed.length <= max ? trimmed : '${trimmed.substring(0, max)}…';
  }
}

// ──────────────────────────────────── Panel shell ────────────────────────────

class _PanelShell extends StatelessWidget {
  const _PanelShell({required this.wide});
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final media = MediaQuery.sizeOf(context);

    final radius = wide
        ? const BorderRadius.only(
            topLeft: Radius.circular(22),
            bottomLeft: Radius.circular(22),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(22),
            topRight: Radius.circular(22),
          );

    final shell = DecoratedBox(
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: radius,
        border: Border.all(color: g.panelBorder),
        boxShadow: [
          BoxShadow(
            color: g.panelShadow,
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: SafeArea(
          top: wide,
          child: const ChatPanel(),
        ),
      ),
    );

    if (wide) {
      return SizedBox(width: 340, child: shell);
    }
    final height = (media.height * 0.6).clamp(300.0, 560.0);
    return SizedBox(
      width: double.infinity,
      height: height,
      child: shell,
    );
  }
}
