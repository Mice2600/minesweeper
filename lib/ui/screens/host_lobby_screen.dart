import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../game/difficulty.dart';
import '../../state/session.dart';
import '../widgets/difficulty_picker.dart';
import '../widgets/player_chip.dart';

class HostLobbyScreen extends ConsumerStatefulWidget {
  const HostLobbyScreen({super.key});

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
    await ref
        .read(sessionProvider.notifier)
        .startHost(name: p.name, avatarSeed: p.avatarSeed);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(sessionProvider);
    final cs = Theme.of(context).colorScheme;

    ref.listen<SessionState>(sessionProvider, (prev, next) {
      if (next.connectionState == SessionConnState.playing) {
        context.go('/game');
      }
    });

    final players = s.snapshot?.players ?? const [];
    final firstUrl = s.hostUrls.isNotEmpty ? s.hostUrls.first : null;
    final mode = BoardPreset.fromConfig(s.config, customSelected: _customSelected);

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
        title: const Text('Hosting'),
      ),
      body: (s.connectionState == SessionConnState.idle ||
              s.connectionState == SessionConnState.connecting)
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          if (firstUrl != null)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: QrImageView(
                                data: firstUrl,
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
                            'Tell others to scan or enter:',
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 8),
                          if (s.hostUrls.isEmpty)
                            Text('Server on port ${s.hostPort}',
                                style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600))
                          else
                            ...s.hostUrls.map(
                              (u) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: SelectableText(
                                  u,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Board',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ModePicker(
                    mode: mode,
                    onChanged: _onModeChanged,
                  ),
                  const SizedBox(height: 8),
                  _ModeSummary(config: s.config),
                  if (mode == BoardPreset.custom) ...[
                    const SizedBox(height: 12),
                    CustomConfigEditor(
                      config: s.config,
                      onChanged: (cfg) {
                        ref.read(sessionProvider.notifier).setConfig(cfg);
                      },
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text('Rules',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _RulesPicker(
                    mode: s.config.mode,
                    hearts: s.config.initialHearts,
                    onModeChanged: (m) {
                      final hearts = m == GameMode.hearts ? 3 : 1;
                      ref.read(sessionProvider.notifier).setConfig(
                            s.config.copyWith(
                              mode: m,
                              initialHearts: hearts,
                            ),
                          );
                    },
                    onHeartsChanged: (h) {
                      ref.read(sessionProvider.notifier).setConfig(
                            s.config.copyWith(initialHearts: h),
                          );
                    },
                  ),
                  const SizedBox(height: 24),
                  Text('Players (${players.length}/4)',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: players
                        .map((p) => PlayerChip(
                              player: p,
                              subtitle: p.isHost ? 'You — Host' : null,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: () {
                      ref.read(sessionProvider.notifier).hostStartGame();
                    },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start game'),
                  ),
                ],
              ),
            ),
    );
  }

  void _onModeChanged(BoardPreset mode) {
    setState(() => _customSelected = mode == BoardPreset.custom);
    final preset = mode.toPresetConfig();
    if (preset != null) {
      ref.read(sessionProvider.notifier).setConfig(preset);
    }
    // For Custom, keep whatever config is currently set so sliders start there.
  }
}

class _ModeSummary extends StatelessWidget {
  const _ModeSummary({required this.config});
  final GameConfig config;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      '${config.width}×${config.height} grid · ${config.mines} mines',
      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
    );
  }
}

class _RulesPicker extends StatelessWidget {
  const _RulesPicker({
    required this.mode,
    required this.hearts,
    required this.onModeChanged,
    required this.onHeartsChanged,
  });

  final GameMode mode;
  final int hearts;
  final ValueChanged<GameMode> onModeChanged;
  final ValueChanged<int> onHeartsChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<GameMode>(
          style: SegmentedButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          segments: const [
            ButtonSegment(
              value: GameMode.classic,
              label: Text('Classic'),
              icon: Icon(Icons.bolt_rounded),
            ),
            ButtonSegment(
              value: GameMode.hearts,
              label: Text('Lives'),
              icon: Icon(Icons.favorite_rounded),
            ),
          ],
          selected: {mode},
          onSelectionChanged: (s) => onModeChanged(s.first),
        ),
        const SizedBox(height: 6),
        Text(
          mode == GameMode.classic
              ? 'One mine ends the game.'
              : 'Team shares lives. Mines chain-explode through neighbours; '
                  'each click on a mine costs one life.',
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
        if (mode == GameMode.hearts) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Lives',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              for (var n = 1; n <= 5; n++) ...[
                ChoiceChip(
                  label: Text('$n'),
                  selected: hearts == n,
                  onSelected: (_) => onHeartsChanged(n),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
