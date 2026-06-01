import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../state/chat.dart';
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

    return IgnorePointer(
      ignoring: !open,
      child: Stack(
        children: [
          // Tap-to-dismiss scrim (mobile only; the wide side panel leaves the
          // board tappable while chatting).
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
    );
  }
}

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
