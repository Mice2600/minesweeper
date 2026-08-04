import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../net/messages.dart';
import '../../state/moderation.dart';
import '../../state/session.dart';
import 'player_actions.dart';

/// Invisible widget that turns moderation events into user-visible feedback.
///
/// Drop it anywhere in a screen that shows other players (it renders nothing
/// and takes no space). It covers both directions:
///
///  * **host** — a report lands, so a snackbar names the reported player and
///    offers a one-tap route to the removal sheet. Without this the host would
///    never learn a report happened, which makes the report button decorative.
///  * **reporter** — the host acknowledges, so the optimistic "sent" toast is
///    upgraded to a confirmed one.
class ModerationListener extends ConsumerWidget {
  const ModerationListener({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<int>(
      moderationFeedProvider.select((s) => s.notices.length),
      (prev, next) {
        if (next <= (prev ?? 0)) return;
        final notice = ref.read(moderationFeedProvider).notices.last;
        _showReportReceived(context, ref, notice);
      },
    );

    ref.listen<({String targetId, int seq})?>(
      moderationFeedProvider.select((s) => s.lastAck),
      (prev, next) {
        if (next == null || next.seq == prev?.seq) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('The host received your report.'),
            duration: Duration(seconds: 3),
          ));
      },
    );

    return const SizedBox.shrink();
  }

  void _showReportReceived(
    BuildContext context,
    WidgetRef ref,
    SModerationNotice notice,
  ) {
    final reason = ReportReason.fromSlug(notice.reason).label;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(
          '${notice.reporterName} reported ${notice.targetName} — $reason',
        ),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Review',
          onPressed: () {
            final player = ref
                .read(sessionProvider)
                .snapshot
                ?.playerById(notice.targetId);
            if (player == null) return;
            showPlayerActions(context, player: player);
          },
        ),
      ));
  }
}
