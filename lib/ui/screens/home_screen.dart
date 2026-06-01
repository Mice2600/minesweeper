import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../net/relay_config.dart';
import '../../state/session.dart';
import '../widgets/how_to_play.dart';
import '../widgets/pressable.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(localProfileProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Fit the panel to the available space instead of scrolling:
            // fill the width on phones (capped at 420), and scale the column
            // down only when the window is too short (a small desktop window,
            // or a phone with the keyboard up). On a roomy screen the scale
            // stays 1.0, so it looks identical to a normal layout.
            final contentWidth =
                math.min(constraints.maxWidth - 32, 420.0).clamp(0.0, 420.0);
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    const _Wordmark(),
                    const SizedBox(height: 10),
                    Text(
                      'Co-op Minesweeper — online or on Wi-Fi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate().fadeIn(delay: 250.ms, duration: 400.ms),
                    const SizedBox(height: 30),
                    _NameField(
                      initial: profile.name,
                      onChanged: (v) => ref
                          .read(localProfileProvider.notifier)
                          .setName(v),
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.15, end: 0),
                    const SizedBox(height: 20),

                    // Hero CTA — the zero-friction way in.
                    _HeroButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Quick play',
                      sub: 'Jump into a solo board',
                      onTap: () => _startSolo(ref, context),
                    ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 22),

                    Row(
                      children: [
                        Expanded(child: Divider(color: cs.outlineVariant)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'PLAY WITH FRIENDS',
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: cs.outlineVariant)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _SquareButton(
                            icon: relayIsConfigured
                                ? Icons.public_rounded
                                : Icons.wifi_tethering_rounded,
                            label: 'Host',
                            tone: cs.primary,
                            onTap: () => context.go(relayIsConfigured
                                ? '/host?mode=online'
                                : '/host'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SquareButton(
                            icon: Icons.login_rounded,
                            label: 'Join',
                            tone: cs.tertiary,
                            onTap: () => context.go('/browse'),
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 550.ms).slideY(begin: 0.2, end: 0),
                    const SizedBox(height: 14),

                    if (relayIsConfigured)
                      TextButton.icon(
                        onPressed: () => context.go('/host'),
                        icon: const Icon(Icons.wifi_tethering_rounded, size: 18),
                        label: const Text('Host on local Wi-Fi instead'),
                      )
                    else
                      Text(
                        'Online play needs a relay URL — build with\n'
                        '--dart-define=RELAY_URL=wss://your-relay.workers.dev',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 11),
                      ),

                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: () => showHowToPlay(context),
                      icon: const Icon(Icons.help_outline_rounded, size: 18),
                      label: const Text('How to play'),
                    ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _startSolo(WidgetRef ref, BuildContext context) async {
    final profile = ref.read(localProfileProvider);
    await ref.read(sessionProvider.notifier).startHost(
          name: profile.name,
          avatarSeed: profile.avatarSeed,
        );
    if (!context.mounted) return;
    ref.read(sessionProvider.notifier).hostStartGame();
    context.go('/game');
  }
}

/// The brand wordmark: a tactile grass badge with a planted flag, and the
/// title set in Fredoka with an accent on "sweeper".
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          width: 92,
          height: 92,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppPalette.grass, AppPalette.leaf],
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppPalette.leaf.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.flag_rounded, size: 50, color: Colors.white),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -6, duration: 1800.ms, curve: Curves.easeInOut),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.fredoka(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
            children: [
              TextSpan(text: 'Mine', style: TextStyle(color: cs.onSurface)),
              TextSpan(text: 'sweeper', style: TextStyle(color: cs.primary)),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 450.ms)
            .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
      ],
    );
  }
}

class _HeroButton extends StatelessWidget {
  const _HeroButton({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.secondary, Color.lerp(cs.secondary, Colors.black, 0.12)!],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: cs.secondary.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: cs.onSecondary, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.fredoka(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: cs.onSecondary,
                    ),
                  ),
                  Text(
                    sub,
                    style: TextStyle(
                      color: cs.onSecondary.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: cs.onSecondary),
          ],
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  const _SquareButton({
    required this.icon,
    required this.label,
    required this.tone,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: g.panel,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tone.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(color: g.panelShadow, blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: tone, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.fredoka(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NameField extends StatefulWidget {
  const _NameField({required this.initial, required this.onChanged});
  final String initial;
  final void Function(String) onChanged;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final TextEditingController _c;
  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      decoration: const InputDecoration(
        labelText: 'Your name',
        prefixIcon: Icon(Icons.person_outline),
      ),
      maxLength: 18,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.done,
    );
  }
}
