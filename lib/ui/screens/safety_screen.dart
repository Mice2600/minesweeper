import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme.dart';
import '../../state/moderation.dart';
import '../widgets/player_actions.dart' show emailReport;

/// Safety centre: the durable half of the moderation tools.
///
/// Block and report are per-player actions taken in the moment; this screen is
/// where they can be reviewed and undone later. Google Play's user-generated-
/// content policy expects both halves — a way to act, and a way to see and
/// manage what you've done.
class SafetyScreen extends ConsumerWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final blocked = ref.watch(blockedPlayersProvider);
    final labels = ref.read(blockedPlayersProvider.notifier).labels;
    final reports = ref.watch(reportLogProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Safety',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _Intro(),
                const SizedBox(height: 20),
                _SectionHeader(
                  icon: Icons.block_rounded,
                  title: 'Blocked players (${blocked.names.length})',
                ),
                const SizedBox(height: 8),
                if (blocked.names.isEmpty)
                  _Empty(
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    text: "You haven't blocked anyone.",
                  )
                else
                  ...blocked.names.map(
                    (folded) => _BlockedRow(
                      label: labels[folded] ?? folded,
                      onUnblock: () => ref
                          .read(blockedPlayersProvider.notifier)
                          .unblockFolded(folded),
                    ),
                  ),
                const SizedBox(height: 24),
                _SectionHeader(
                  icon: Icons.flag_rounded,
                  title: 'Reports you sent (${reports.length})',
                ),
                const SizedBox(height: 8),
                if (reports.isEmpty)
                  _Empty(
                    icon: Icons.inbox_rounded,
                    text: "You haven't reported anyone.",
                  )
                else ...[
                  ...reports.reversed.map((r) => _ReportRow(report: r)),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () =>
                        ref.read(reportLogProvider.notifier).clear(),
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: cs.error),
                    label: Text('Clear report history',
                        style: TextStyle(color: cs.error)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: g.panelBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tap any player — in the lobby, the player bar, or on one of '
            'their chat messages — to block, report, or (if you host) remove '
            'them.',
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            'Blocking hides that player’s messages, reactions, cursor, and '
            'profile picture. Chat and names are also filtered automatically. '
            'Everything here is stored on your device only.',
            style: TextStyle(
                color: cs.onSurfaceVariant, height: 1.4, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
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
    );
  }
}

class _BlockedRow extends StatelessWidget {
  const _BlockedRow({required this.label, required this.onUnblock});
  final String label;
  final VoidCallback onUnblock;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: cs.error.withValues(alpha: 0.15),
        child: Icon(Icons.person_off_rounded, size: 20, color: cs.error),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        'Blocked by name',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: TextButton(onPressed: onUnblock, child: const Text('Unblock')),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});
  final FiledReport report;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = report.ts;
    final when = '${d.year}-${_two(d.month)}-${_two(d.day)} '
        '${_two(d.hour)}:${_two(d.minute)}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: cs.error.withValues(alpha: 0.15),
        child: Icon(Icons.flag_rounded, size: 20, color: cs.error),
      ),
      title: Text(report.targetName,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${report.reason.label} · $when',
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
      ),
      trailing: IconButton(
        tooltip: 'Email this report to the developer',
        icon: const Icon(Icons.mail_outline_rounded, size: 20),
        onPressed: () => emailReport(report),
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Text(text, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
