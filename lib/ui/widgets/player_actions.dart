import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../../net/messages.dart';
import '../../state/chat.dart';
import '../../state/moderation.dart';
import '../../state/session.dart';
import '../screens/about_screen.dart' show kSupportEmail;
import 'avatar.dart';

/// The safety menu for one player: **block**, **report**, and — for the host —
/// **remove from game**.
///
/// This is the entry point Google Play's user-generated-content policy requires
/// an app with chat, custom names, and user-supplied avatars to provide, so it
/// is reachable from every surface a player is visible on: the lobby slots, the
/// in-game player bar, and each chat message.
///
/// Call [showPlayerActions] rather than pushing this directly.
Future<void> showPlayerActions(
  BuildContext context, {
  required PlayerInfo player,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlayerActionsSheet(player: player),
  );
}

class _PlayerActionsSheet extends ConsumerWidget {
  const _PlayerActionsSheet({required this.player});
  final PlayerInfo player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final session = ref.watch(sessionProvider);
    final blocked = ref.watch(blockedPlayersProvider);

    final isMe = player.id == session.localId;
    final iAmHost = session.isHost;
    final isBlocked =
        blocked.isBlocked(id: player.id, name: player.name);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Avatar(
                  seed: player.avatarSeed,
                  label: player.name,
                  // A blocked player's photo stays hidden even here — the
                  // whole point of blocking an avatar is not having to see it.
                  avatarData: isBlocked ? null : player.avatarData,
                  size: 44,
                  color: Color(player.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fredoka(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        isMe
                            ? 'This is you'
                            : (player.isHost ? 'Host' : 'Player'),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (isMe)
              _Hint(
                text: 'Safety tools apply to other players. Tap someone else '
                    'in the lobby or player bar to block or report them.',
              )
            else ...[
              _ActionRow(
                icon: isBlocked
                    ? Icons.volume_up_rounded
                    : Icons.block_rounded,
                label: isBlocked ? 'Unblock' : 'Block',
                subtitle: isBlocked
                    ? "You'll see this player's messages again."
                    : 'Hide their messages, reactions, cursor, and photo.',
                onTap: () {
                  final notifier = ref.read(blockedPlayersProvider.notifier);
                  if (isBlocked) {
                    notifier.unblock(id: player.id, name: player.name);
                  } else {
                    notifier.block(id: player.id, name: player.name);
                  }
                  Navigator.of(context).pop();
                  _toast(
                    context,
                    isBlocked
                        ? 'Unblocked ${player.name}'
                        : 'Blocked ${player.name}',
                  );
                },
              ),
              _ActionRow(
                icon: Icons.flag_rounded,
                label: 'Report',
                subtitle: 'Send the host a report about this player.',
                tone: cs.error,
                onTap: () async {
                  Navigator.of(context).pop();
                  await showReportSheet(context, player: player);
                },
              ),
              if (iAmHost)
                _ActionRow(
                  icon: Icons.person_remove_rounded,
                  label: 'Remove from game',
                  subtitle:
                      "They're disconnected and can't rejoin this room.",
                  tone: cs.error,
                  onTap: () async {
                    final ok = await _confirmKick(context, player.name);
                    if (!ok || !context.mounted) return;
                    ref.read(sessionProvider.notifier).sendKick(player.id);
                    Navigator.of(context).pop();
                    _toast(context, 'Removed ${player.name}');
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmKick(BuildContext context, String name) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove player?'),
      content: Text(
        '$name will be disconnected and blocked from rejoining this room. '
        'They can still join a future game you host.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ──────────────────────────────── Report sheet ────────────────────────────────

/// Reason picker + optional details, then files the report.
///
/// Filing does three things at once, because any one alone is a dead end:
/// it tells the **host** (who can act right now), writes a **local record**
/// with the reported player's recent chat lines attached as evidence (nothing
/// is stored server-side, so this is the only copy that outlives the room), and
/// offers to **email the developer** if the host is the problem.
Future<void> showReportSheet(
  BuildContext context, {
  required PlayerInfo player,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: _ReportSheet(player: player),
    ),
  );
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.player});
  final PlayerInfo player;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  final _details = TextEditingController();
  bool _alsoBlock = true;
  bool _sending = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() => _sending = true);

    final player = widget.player;
    final details = _details.text.trim();

    // Snapshot what this player actually said, while the transcript still
    // exists. After the room closes there is nothing to reconstruct it from.
    final evidence = ref
        .read(chatProvider)
        .messages
        .where((m) => m.playerId == player.id)
        .map((m) => m.text)
        .toList();
    final recent = evidence.length > 20
        ? evidence.sublist(evidence.length - 20)
        : evidence;

    final report = FiledReport(
      targetName: player.name,
      reason: reason,
      details: details.isEmpty ? null : details,
      evidence: recent,
      ts: DateTime.now(),
    );

    ref.read(sessionProvider.notifier).sendReport(
          player.id,
          reason: reason.slug,
          details: details.isEmpty ? null : details,
        );
    ref.read(reportLogProvider.notifier).add(report);
    if (_alsoBlock) {
      ref
          .read(blockedPlayersProvider.notifier)
          .block(id: player.id, name: player.name);
    }

    if (!mounted) return;
    Navigator.of(context).pop();
    _toast(
      context,
      _alsoBlock
          ? 'Report sent to the host · ${player.name} blocked'
          : 'Report sent to the host',
      action: SnackBarAction(
        label: 'Email us',
        onPressed: () => _emailReport(report),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Report ${widget.player.name}',
                style: GoogleFonts.fredoka(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "What's going on?",
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 14),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (v) => setState(() => _reason = v),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final r in ReportReason.values)
                      RadioListTile<ReportReason>(
                        value: r,
                        title: Text(r.label,
                            style: const TextStyle(fontSize: 14.5)),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _details,
                minLines: 2,
                maxLines: 4,
                maxLength: 280,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Details (optional)',
                  counterText: '',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              CheckboxListTile(
                value: _alsoBlock,
                onChanged: (v) => setState(() => _alsoBlock = v ?? true),
                title: const Text(
                  'Also block this player',
                  style: TextStyle(fontSize: 14.5),
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 4),
              Text(
                'Your report goes to the host of this game, who can remove the '
                'player. A copy is kept on your device under Settings → Safety '
                'so you can email it to us if the host takes no action.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, height: 1.35),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _reason == null || _sending ? null : _submit,
                style: FilledButton.styleFrom(backgroundColor: cs.error),
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: const Text('Send report'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the user's mail app with the report pre-filled. Best-effort: on a
/// device with no mail client configured, `launchUrl` simply returns false and
/// the report stays in the local log.
Future<void> emailReport(FiledReport report) => _emailReport(report);

Future<void> _emailReport(FiledReport report) async {
  final uri = Uri(
    scheme: 'mailto',
    path: kSupportEmail,
    queryParameters: {
      'subject': 'Minesweeper Co-op — player report',
      'body': report.asText(),
    },
  );
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No mail client. The local copy is still there.
  }
}

// ─────────────────────────────────── Bits ─────────────────────────────────────

void _toast(BuildContext context, String message, {SnackBarAction? action}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      action: action,
      duration: const Duration(seconds: 4),
    ));
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = tone ?? cs.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: g.panelBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
