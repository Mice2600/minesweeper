import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../state/session.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(localProfileProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Logo(color: cs.primary),
                  const SizedBox(height: 12),
                  Text(
                    'Minesweeper',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .displaySmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.15, end: 0),
                  const SizedBox(height: 6),
                  Text(
                    'Co-op on your local Wi-Fi',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  _NameField(
                    initial: profile.name,
                    onChanged: (v) => ref
                        .read(localProfileProvider.notifier)
                        .setName(v),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.go('/host'),
                    icon: const Icon(Icons.wifi_tethering_rounded),
                    label: const Text('Host a game'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/browse'),
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Join a game'),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => _startSolo(ref, context),
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Play solo'),
                  ),
                ],
              ),
            ),
          ),
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

class _Logo extends StatelessWidget {
  const _Logo({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(Icons.flag_rounded, size: 56, color: color),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(
            duration: 1800.ms,
            curve: Curves.easeInOut,
            begin: const Offset(1, 1),
            end: const Offset(1.05, 1.05))
        .then();
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
