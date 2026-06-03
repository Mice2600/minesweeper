import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../game/difficulty.dart';
import '../../net/relay_config.dart';
import '../../state/iap.dart';
import '../../state/session.dart';
import '../../state/store.dart';
import '../widgets/avatar.dart';
import '../widgets/coin_pill.dart';
import '../widgets/how_to_play.dart';
import '../widgets/menu_banner.dart';
import '../widgets/pressable.dart';
import '../widgets/tip_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(localProfileProvider);
    final cs = Theme.of(context).colorScheme;

    // Thank-you after a successful tip.
    ref.listen(iapProvider.select((s) => s.tipThanksNonce), (prev, next) {
      if (prev == null || next <= prev || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Thank you so much! 💜'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1800),
        ));
    });
    // Surface a billing error.
    ref.listen(iapProvider.select((s) => s.error), (_, err) {
      if (err == null || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(err),
          behavior: SnackBarBehavior.floating,
          backgroundColor: cs.error,
        ));
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      bottomNavigationBar: const MenuBanner(),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
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
                            const SizedBox(height: 24),

                            // Profile card: avatar + name field
                            _ProfileCard(profile: profile)
                                .animate()
                                .fadeIn(delay: 350.ms)
                                .slideY(begin: 0.15, end: 0),
                            const SizedBox(height: 20),

                            // Quick play CTA
                            _HeroButton(
                              icon: Icons.play_arrow_rounded,
                              label: 'Quick play',
                              sub: 'Jump into a solo board',
                              onTap: () => _startSolo(ref, context),
                            ).animate().fadeIn(delay: 450.ms).slideY(begin: 0.2, end: 0),
                            const SizedBox(height: 10),

                            // Difficulty chips
                            _DifficultyRow(
                              selected: profile.preferredDifficulty,
                              onChanged: (d) => ref
                                  .read(localProfileProvider.notifier)
                                  .setDifficulty(d),
                            ).animate().fadeIn(delay: 480.ms),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(child: Divider(color: cs.outlineVariant)),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 12),
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
                            const SizedBox(height: 14),

                            // Host + Join (2 larger buttons)
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
                                const SizedBox(width: 14),
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
                            const SizedBox(height: 10),

                            // Store — full-width pill below Host/Join
                            _StorePill(onTap: () => context.push('/store'))
                                .animate()
                                .fadeIn(delay: 580.ms),
                            const SizedBox(height: 10),

                            // Achievements — full-width pill below Store
                            _AchievementsPill(
                                    onTap: () => context.push('/achievements'))
                                .animate()
                                .fadeIn(delay: 610.ms),
                            const SizedBox(height: 10),

                            if (relayIsConfigured)
                              TextButton.icon(
                                onPressed: () => context.go('/host'),
                                icon: const Icon(Icons.wifi_tethering_rounded,
                                    size: 18),
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

                            const SizedBox(height: 4),
                            TextButton.icon(
                              onPressed: () => showHowToPlay(context),
                              icon: const Icon(Icons.help_outline_rounded, size: 18),
                              label: const Text('How to play'),
                            ),
                            TextButton.icon(
                              onPressed: () => context.push('/about'),
                              icon: const Icon(Icons.info_outline_rounded, size: 18),
                              label: const Text('About'),
                            ),
                            // Low-key tip link — only when billing is available
                            // (Android with products loaded).
                            if (ref.watch(iapProvider).available)
                              TextButton(
                                onPressed: () => showTipSheet(context),
                                style: TextButton.styleFrom(
                                  foregroundColor: cs.onSurfaceVariant
                                      .withValues(alpha: 0.7),
                                  minimumSize: const Size(0, 32),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text('♥ Support'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 8,
              right: 12,
              child: PressableScale(
                onTap: () => context.push('/store'),
                child: GestureDetector(
                  // Debug-only: wipe coins & skins. Disabled in release builds.
                  onLongPress:
                      kDebugMode ? () => _confirmReset(context, ref) : null,
                  child: CoinPill(coins: ref.watch(storeProvider).coins),
                ),
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('Reset coins & skins?', style: GoogleFonts.fredoka()),
        content: const Text(
          'Debug: restores 10000 coins and locks every skin except '
          'Classic Grass.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    ref.read(storeProvider.notifier).resetDebug();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Coins & skins reset'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(milliseconds: 1200),
      ));
  }

  Future<void> _startSolo(WidgetRef ref, BuildContext context) async {
    final profile = ref.read(localProfileProvider);
    await ref.read(sessionProvider.notifier).startHost(
          name: profile.name,
          avatarSeed: profile.avatarSeed,
          avatarData: profile.avatarData,
          difficulty: profile.preferredDifficulty,
        );
    if (!context.mounted) return;
    ref.read(sessionProvider.notifier).hostStartGame();
    context.go('/game');
  }
}

// ──────────────────────────────────────── Profile card ────────────────────────

class _ProfileCard extends ConsumerStatefulWidget {
  const _ProfileCard({required this.profile});
  final LocalProfile profile;

  @override
  ConsumerState<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends ConsumerState<_ProfileCard> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(localProfileProvider);
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: g.panelBorder, width: 1.5),
        boxShadow: [
          BoxShadow(color: g.panelShadow, blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Avatar with camera badge
          GestureDetector(
            onTap: () => ref.read(localProfileProvider.notifier).pickAndCompressAvatar(),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Avatar(
                  seed: profile.avatarSeed,
                  label: profile.name,
                  avatarData: profile.avatarData,
                  size: 56,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: g.panel, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.camera_alt_rounded,
                        size: 12, color: cs.onPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Name field
          Expanded(
            child: TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Your name',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLength: 18,
              onChanged: (v) =>
                  ref.read(localProfileProvider.notifier).setName(v),
              textInputAction: TextInputAction.done,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────── Difficulty row ──────────────────────

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({required this.selected, required this.onChanged});
  final Difficulty selected;
  final void Function(Difficulty) onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: Difficulty.values.map((d) {
        final active = d == selected;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: ChoiceChip(
            label: Text(d.label),
            selected: active,
            onSelected: (_) => onChanged(d),
            selectedColor: cs.primary.withValues(alpha: 0.18),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: active ? cs.primary : cs.onSurfaceVariant,
            ),
            side: BorderSide(
              color: active
                  ? cs.primary.withValues(alpha: 0.6)
                  : cs.outlineVariant,
              width: active ? 1.5 : 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            showCheckmark: false,
          ),
        );
      }).toList(),
    );
  }
}

// ──────────────────────────────────────── Store pill ──────────────────────────

class _StorePill extends StatelessWidget {
  const _StorePill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: g.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: cs.secondary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: g.panelShadow, blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_rounded, color: cs.secondary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Store',
              style: GoogleFonts.fredoka(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────── Achievements pill ───────────────────

class _AchievementsPill extends StatelessWidget {
  const _AchievementsPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: g.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: cs.tertiary.withValues(alpha: 0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: g.panelShadow, blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_rounded, color: cs.tertiary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Achievements',
              style: GoogleFonts.fredoka(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.tertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────── Wordmark ────────────────────────────

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

// ──────────────────────────────────────── Hero button ─────────────────────────

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
            colors: [
              cs.secondary,
              Color.lerp(cs.secondary, Colors.black, 0.12)!
            ],
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

// ──────────────────────────────────────── Square button ───────────────────────

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
            BoxShadow(
                color: g.panelShadow, blurRadius: 12, offset: const Offset(0, 6)),
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
