import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../app/theme.dart';
import '../../game/difficulty.dart';
import '../../net/messages.dart';
import '../../state/session.dart';
import '../widgets/avatar.dart';
import '../widgets/chat_button.dart';
import '../widgets/chat_overlay.dart';
import '../widgets/difficulty_picker.dart';
import '../widgets/emoji_bar.dart';
import '../widgets/emoji_overlay.dart';
import '../widgets/game_panel.dart';
import '../widgets/pressable.dart';

class HostLobbyScreen extends ConsumerStatefulWidget {
  const HostLobbyScreen({super.key, this.mode = HostMode.lan});

  final HostMode mode;

  @override
  ConsumerState<HostLobbyScreen> createState() => _HostLobbyScreenState();
}

class _HostLobbyScreenState extends ConsumerState<HostLobbyScreen> {
  bool _customSelected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureHosting());
  }

  Future<void> _ensureHosting() async {
    final s = ref.read(sessionProvider);
    if (s.connectionState != SessionConnState.idle) return;
    final p = ref.read(localProfileProvider);
    await ref.read(sessionProvider.notifier).startHost(
          name: p.name,
          avatarSeed: p.avatarSeed,
          mode: widget.mode,
        );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);

    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next.connectionState == SessionConnState.playing) {
        context.go('/game');
      }
    });

    final players = s.snapshot?.players ?? const <PlayerInfo>[];
    final firstUrl = s.hostUrls.isNotEmpty ? s.hostUrls.first : null;
    final preset = BoardPreset.fromConfig(s.config, customSelected: _customSelected);
    final notifier = ref.read(sessionProvider.notifier);

    final connecting = s.connectionState == SessionConnState.idle ||
        s.connectionState == SessionConnState.connecting;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await ref.read(sessionProvider.notifier).leave();
            if (!context.mounted) return;
            context.go('/');
          },
        ),
        title: const Text('Game lobby'),
        actions: const [ChatButton()],
      ),
      body: connecting
          ? const _Connecting()
          : Stack(
              children: [
                LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 880;

                final invite = widget.mode == HostMode.online
                    ? _OnlineRoomCard(roomCode: s.roomCode)
                    : _LanRoomCard(
                        urls: s.hostUrls,
                        firstUrl: firstUrl,
                        port: s.hostPort,
                      );

                final boardSection = _Section(
                  icon: Icons.grid_view_rounded,
                  title: 'Board',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DifficultyPicker(
                        preset: preset,
                        columns: wide ? 4 : 2,
                        onSelect: _onPresetChanged,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${s.config.width}×${s.config.height} grid · '
                        '${s.config.mines} mines',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (preset == BoardPreset.custom) ...[
                        const SizedBox(height: 12),
                        CustomConfigEditor(
                          config: s.config,
                          onChanged: notifier.setConfig,
                        ),
                      ],
                    ],
                  ),
                );

                final rulesSection = _Section(
                  icon: Icons.gavel_rounded,
                  title: 'Rules',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ModePicker(
                        mode: s.config.mode,
                        onChanged: (m) => notifier.setConfig(
                          s.config.copyWith(
                            mode: m,
                            initialHearts: m == GameMode.hearts ? 3 : 1,
                          ),
                        ),
                      ),
                      if (s.config.mode == GameMode.hearts) ...[
                        const SizedBox(height: 12),
                        _LivesPicker(
                          hearts: s.config.initialHearts,
                          onChanged: (h) => notifier.setConfig(
                            s.config.copyWith(initialHearts: h),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      _AutoFlagToggle(
                        value: s.config.autoFlagChord,
                        onChanged: (v) => notifier.setConfig(
                          s.config.copyWith(autoFlagChord: v),
                        ),
                      ),
                    ],
                  ),
                );

                final playersSection = _Section(
                  icon: Icons.groups_rounded,
                  title: 'Players  ${players.length}/4',
                  child: _PlayerSlots(
                    players: players,
                    localId: s.localId,
                    columns: 2,
                    online: widget.mode == HostMode.online,
                    soloHint: players.length <= 1,
                  ),
                );

                final start = _StartButton(
                  solo: players.length <= 1,
                  onPressed: notifier.hostStartGame,
                );

                final reactBar = Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: EmojiBar(onSend: notifier.sendEmoji),
                  ),
                );

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1040),
                      child: wide
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          invite,
                                          const SizedBox(height: 20),
                                          playersSection,
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      flex: 6,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          boardSection,
                                          const SizedBox(height: 20),
                                          rulesSection,
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                reactBar,
                                const SizedBox(height: 18),
                                Center(
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 480),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: start,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                invite,
                                const SizedBox(height: 20),
                                boardSection,
                                const SizedBox(height: 20),
                                rulesSection,
                                const SizedBox(height: 20),
                                playersSection,
                                const SizedBox(height: 20),
                                reactBar,
                                const SizedBox(height: 18),
                                start,
                              ],
                            ),
                    ),
                  ),
                );
              },
                ),
                // So the host can react and see joiners' reactions live.
                const Positioned.fill(
                    child: IgnorePointer(child: EmojiOverlay())),
                const ChatOverlay(),
              ],
            ),
    );
  }

  void _onPresetChanged(BoardPreset preset) {
    setState(() => _customSelected = preset == BoardPreset.custom);
    final cfg = preset.toPresetConfig();
    if (cfg != null) {
      // Only swap the board dimensions/mines — keep the player's choices for
      // game mode, lives, and auto-flag chord across preset changes.
      final current = ref.read(sessionProvider).config;
      ref.read(sessionProvider.notifier).setConfig(
            current.copyWith(
              width: cfg.width,
              height: cfg.height,
              mines: cfg.mines,
            ),
          );
    }
    // For Custom, keep whatever config is currently set so sliders start there.
  }
}

// ───────────────────────────────────── Loading ─────────────────────────────

class _Connecting extends StatelessWidget {
  const _Connecting();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Setting up your lobby…',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────── Section ─────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.fredoka(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

// ──────────────────────────────── Choice tiles ─────────────────────────────

/// Lays [tiles] into rows of [columns], stretching each cell to equal width
/// (and equal height within a row) so they read as a tidy game-y grid.
Widget _tileGrid(List<Widget> tiles, int columns, {double gap = 10}) {
  final rows = <Widget>[];
  for (var i = 0; i < tiles.length; i += columns) {
    final cells = <Widget>[];
    for (var j = 0; j < columns; j++) {
      if (j > 0) cells.add(SizedBox(width: gap));
      final idx = i + j;
      cells.add(Expanded(
        child: idx < tiles.length ? tiles[idx] : const SizedBox.shrink(),
      ));
    }
    rows.add(IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: cells),
    ));
    if (i + columns < tiles.length) rows.add(SizedBox(height: gap));
  }
  return Column(children: rows);
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.accent,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    final ac = accent ?? cs.primary;
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? ac.withValues(alpha: 0.16) : g.panel,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? ac : g.panelBorder,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? null
              : [
                  BoxShadow(
                      color: g.panelShadow,
                      blurRadius: 8,
                      offset: const Offset(0, 3)),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: selected ? ac : cs.onSurfaceVariant),
            const SizedBox(height: 7),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.fredoka(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({
    required this.preset,
    required this.columns,
    required this.onSelect,
  });
  final BoardPreset preset;
  final int columns;
  final ValueChanged<BoardPreset> onSelect;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String dims(Difficulty d) => '${d.width}×${d.height} · ${d.mines}';
    final tiles = <Widget>[
      _ChoiceTile(
        icon: Icons.spa_rounded,
        title: 'Easy',
        subtitle: dims(Difficulty.easy),
        accent: cs.primary,
        selected: preset == BoardPreset.easy,
        onTap: () => onSelect(BoardPreset.easy),
      ),
      _ChoiceTile(
        icon: Icons.grass_rounded,
        title: 'Medium',
        subtitle: dims(Difficulty.medium),
        accent: cs.tertiary,
        selected: preset == BoardPreset.medium,
        onTap: () => onSelect(BoardPreset.medium),
      ),
      _ChoiceTile(
        icon: Icons.whatshot_rounded,
        title: 'Hard',
        subtitle: dims(Difficulty.hard),
        accent: cs.secondary,
        selected: preset == BoardPreset.hard,
        onTap: () => onSelect(BoardPreset.hard),
      ),
      _ChoiceTile(
        icon: Icons.tune_rounded,
        title: 'Custom',
        subtitle: 'Your rules',
        accent: cs.primary,
        selected: preset == BoardPreset.custom,
        onTap: () => onSelect(BoardPreset.custom),
      ),
    ];
    return _tileGrid(tiles, columns);
  }
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.mode, required this.onChanged});
  final GameMode mode;
  final ValueChanged<GameMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tiles = <Widget>[
      _ChoiceTile(
        icon: Icons.bolt_rounded,
        title: 'Classic',
        subtitle: 'One mine ends it',
        accent: cs.primary,
        selected: mode == GameMode.classic,
        onTap: () => onChanged(GameMode.classic),
      ),
      _ChoiceTile(
        icon: Icons.favorite_rounded,
        title: 'Lives',
        subtitle: 'Shared hearts',
        accent: const Color(0xFFE53935),
        selected: mode == GameMode.hearts,
        onTap: () => onChanged(GameMode.hearts),
      ),
    ];
    return _tileGrid(tiles, 2);
  }
}

class _LivesPicker extends StatelessWidget {
  const _LivesPicker({required this.hearts, required this.onChanged});
  final int hearts;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text('Lives',
            style: TextStyle(
                fontWeight: FontWeight.w700, color: cs.onSurface)),
        const SizedBox(width: 12),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var n = 1; n <= 5; n++)
                ChoiceChip(
                  label: Text('$n'),
                  selected: hearts == n,
                  onSelected: (_) => onChanged(n),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AutoFlagToggle extends StatelessWidget {
  const _AutoFlagToggle({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GamePanel(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auto-flag chord',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(
                  'Chording a number whose hidden neighbours must all be mines '
                  'flags them in one tap.',
                  style:
                      TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ──────────────────────────────── Player slots ─────────────────────────────

class _PlayerSlots extends StatelessWidget {
  const _PlayerSlots({
    required this.players,
    required this.localId,
    required this.columns,
    required this.online,
    required this.soloHint,
  });
  final List<PlayerInfo> players;
  final String localId;
  final int columns;
  final bool online;
  final bool soloHint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final slots = <Widget>[
      for (final p in players) _FilledSlot(player: p, isMe: p.id == localId),
      for (var i = players.length; i < 4; i++) const _EmptySlot(),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tileGrid(slots, columns),
        if (soloHint) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 15, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  online
                      ? 'Share the room code to invite friends — or just start solo.'
                      : 'Share the QR or address to invite — or just start solo.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FilledSlot extends StatelessWidget {
  const _FilledSlot({required this.player, required this.isMe});
  final PlayerInfo player;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Color(player.color);
    return GamePanel(
      borderColor: color.withValues(alpha: 0.55),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Avatar(
              seed: player.avatarSeed,
              label: player.name,
              size: 38,
              color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: cs.onSurface,
                        ),
                      ),
                    ),
                    if (player.isHost) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.shield_rounded, size: 13, color: color),
                    ],
                  ],
                ),
                Text(
                  player.isHost ? (isMe ? 'You · Host' : 'Host') : 'Ready',
                  style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: cs.outlineVariant, width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.onSurfaceVariant.withValues(alpha: 0.10),
            ),
            child: Icon(Icons.person_add_alt_1_rounded,
                size: 20, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Text(
            'Open slot',
            style: TextStyle(
                color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────── Start ───────────────────────────────

class _StartButton extends StatelessWidget {
  const _StartButton({required this.solo, required this.onPressed});
  final bool solo;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          textStyle: GoogleFonts.fredoka(
            fontSize: 21,
            fontWeight: FontWeight.w600,
          ),
        ),
        icon: const Icon(Icons.play_arrow_rounded, size: 28),
        label: Text(solo ? 'Start solo' : 'Start game'),
      ),
    );
  }
}

// ─────────────────────────────────── Room cards ────────────────────────────

class _OnlineRoomCard extends StatelessWidget {
  const _OnlineRoomCard({required this.roomCode});
  final String? roomCode;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final code = roomCode;
    return GamePanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.public_rounded, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('ROOM CODE',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.6,
                  )),
            ],
          ),
          const SizedBox(height: 10),
          if (code == null)
            const SizedBox(
              height: 56,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SelectableText(
                code,
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.w800,
                  fontSize: 40,
                  letterSpacing: 8,
                  color: cs.primary,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Share this code with friends so they can join from anywhere.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
          const SizedBox(height: 14),
          if (code != null)
            FilledButton.tonalIcon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Code copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy code'),
            ),
        ],
      ),
    );
  }
}

class _LanRoomCard extends StatelessWidget {
  const _LanRoomCard({
    required this.urls,
    required this.firstUrl,
    required this.port,
  });
  final List<String> urls;
  final String? firstUrl;
  final int port;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GamePanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_tethering_rounded,
                  size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text('SCAN TO JOIN',
                  style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.6,
                  )),
            ],
          ),
          const SizedBox(height: 12),
          if (firstUrl != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: firstUrl!,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Tell others on this Wi-Fi to scan or enter:',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (urls.isEmpty)
            Text(
              'Server on port $port',
              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w600),
            )
          else
            ...urls.map(
              (u) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: SelectableText(
                  u,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
