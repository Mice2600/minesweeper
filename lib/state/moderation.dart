import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/moderation.dart';
import '../core/prefs.dart';
import '../net/messages.dart';

/// Client-side safety state: who this device has blocked, and the local log of
/// reports it has filed.
///
/// Blocking is deliberately a *local* control, unlike kicking. The host decides
/// who stays in the room; every player decides what they personally have to
/// look at. A block therefore needs no protocol support and works identically
/// on LAN and online.
///
/// **Identity is the hard part.** The game has no accounts, so a player's
/// logical id is minted fresh per room and can't anchor a durable block. We
/// key on two things instead:
///
///  * the **logical id**, which is exact but only lives as long as the room —
///    this is what actually filters the current session;
///  * the **folded display name**, which persists across sessions and catches
///    the common case of the same person rejoining under the same handle.
///
/// Neither is spoof-proof; together they're the strongest signal available
/// without asking players to create accounts.

// ─────────────────────────────────── Blocking ─────────────────────────────────

class BlockedPlayers {
  const BlockedPlayers({this.ids = const {}, this.names = const {}});

  /// Logical player ids blocked in the current room. Cleared on leave.
  final Set<String> ids;

  /// Folded display names blocked durably, persisted across launches.
  /// Keys are produced by [foldName].
  final Set<String> names;

  bool isBlocked({required String id, required String name}) =>
      ids.contains(id) || names.contains(foldName(name));

  /// Case/leet-insensitive key for a display name, so `Xx_Griefer_xX` and
  /// `xX GR1EFER Xx` collapse to the same entry.
  static String foldName(String name) => Moderation.stripInvisible(name)
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  BlockedPlayers copyWith({Set<String>? ids, Set<String>? names}) =>
      BlockedPlayers(ids: ids ?? this.ids, names: names ?? this.names);
}

final blockedPlayersProvider =
    NotifierProvider<BlockedPlayersNotifier, BlockedPlayers>(
        BlockedPlayersNotifier.new);

class BlockedPlayersNotifier extends Notifier<BlockedPlayers> {
  static const _kNames = 'moderation.blockedNames';
  static const _kLabels = 'moderation.blockedLabels';

  /// Display labels for the blocked-players screen, keyed by folded name, so
  /// the list reads `Griefer99` rather than `griefer99`.
  Map<String, String> _labels = {};
  Map<String, String> get labels => Map.unmodifiable(_labels);

  @override
  BlockedPlayers build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final names = prefs.getStringList(_kNames)?.toSet() ?? <String>{};
    final rawLabels = prefs.getString(_kLabels);
    if (rawLabels != null) {
      try {
        _labels = (jsonDecode(rawLabels) as Map).cast<String, String>();
      } catch (_) {
        _labels = {};
      }
    }
    return BlockedPlayers(names: names);
  }

  /// Blocks a player by both handles: the id (effective immediately, this
  /// room) and the folded name (persisted, future rooms).
  void block({required String id, required String name}) {
    final folded = BlockedPlayers.foldName(name);
    final names = {...state.names};
    if (folded.isNotEmpty) {
      names.add(folded);
      _labels[folded] = name;
    }
    state = state.copyWith(ids: {...state.ids, id}, names: names);
    _persist();
  }

  /// Lifts a block. Clearing the folded name also clears any id blocked under
  /// it, so one tap fully undoes one block.
  void unblock({String? id, String? name}) {
    final ids = {...state.ids};
    if (id != null) ids.remove(id);
    final names = {...state.names};
    if (name != null) {
      final folded = BlockedPlayers.foldName(name);
      names.remove(folded);
      _labels.remove(folded);
    }
    state = state.copyWith(ids: ids, names: names);
    _persist();
  }

  /// Unblocks by the stored folded key — what the blocked-players screen has.
  void unblockFolded(String folded) {
    final names = {...state.names}..remove(folded);
    _labels.remove(folded);
    state = state.copyWith(names: names);
    _persist();
  }

  /// Drops the room-scoped id blocks when a session ends. Persisted name
  /// blocks survive — that's the point of them.
  void clearSessionBlocks() =>
      state = state.copyWith(ids: const <String>{});

  void _persist() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setStringList(_kNames, state.names.toList());
    prefs.setString(_kLabels, jsonEncode(_labels));
  }
}

// ─────────────────────────────────── Reporting ────────────────────────────────

/// Why a player was reported. The slug is what crosses the wire
/// ([CReport.reason]); the label is what the reporter picked.
enum ReportReason {
  abusiveChat('abusiveChat', 'Abusive or offensive messages'),
  harassment('harassment', 'Harassment or bullying'),
  inappropriateAvatar('inappropriateAvatar', 'Inappropriate profile picture'),
  inappropriateName('inappropriateName', 'Inappropriate display name'),
  spam('spam', 'Spam or advertising'),
  cheating('cheating', 'Cheating or deliberate griefing'),
  other('other', 'Something else');

  const ReportReason(this.slug, this.label);
  final String slug;
  final String label;

  static ReportReason fromSlug(String slug) => values.firstWhere(
        (r) => r.slug == slug,
        orElse: () => ReportReason.other,
      );
}

/// One filed report, kept on this device.
class FiledReport {
  const FiledReport({
    required this.targetName,
    required this.reason,
    required this.details,
    required this.evidence,
    required this.ts,
  });

  final String targetName;
  final ReportReason reason;
  final String? details;

  /// Chat lines from the reported player, captured at report time. Without
  /// this the report is unactionable by the time anyone reads it — the room is
  /// long gone and nothing is stored server-side.
  final List<String> evidence;

  final DateTime ts;

  Map<String, dynamic> toJson() => {
        'targetName': targetName,
        'reason': reason.slug,
        if (details != null) 'details': details,
        'evidence': evidence,
        'ts': ts.toIso8601String(),
      };

  factory FiledReport.fromJson(Map<String, dynamic> j) => FiledReport(
        targetName: j['targetName'] as String? ?? '',
        reason: ReportReason.fromSlug(j['reason'] as String? ?? 'other'),
        details: j['details'] as String?,
        evidence:
            ((j['evidence'] as List?) ?? const []).map((e) => '$e').toList(),
        ts: DateTime.tryParse(j['ts'] as String? ?? '') ?? DateTime(1970),
      );

  /// Plain-text rendering used for the "email this report" body.
  String asText() {
    final b = StringBuffer()
      ..writeln('Reported player: $targetName')
      ..writeln('Reason: ${reason.label}')
      ..writeln('When: ${ts.toIso8601String()}');
    if (details != null && details!.isNotEmpty) {
      b.writeln('Details: $details');
    }
    if (evidence.isNotEmpty) {
      b.writeln('Messages from this player:');
      for (final line in evidence) {
        b.writeln('  • $line');
      }
    }
    return b.toString();
  }
}

/// Local, on-device record of reports filed from this install. Nothing is
/// uploaded: it exists so the reporter can review what they sent and forward
/// it to the developer if the host didn't act.
final reportLogProvider =
    NotifierProvider<ReportLogNotifier, List<FiledReport>>(
        ReportLogNotifier.new);

class ReportLogNotifier extends Notifier<List<FiledReport>> {
  static const _kReports = 'moderation.reports';

  /// Keep the log bounded — it's a convenience record, not an archive.
  static const _maxReports = 50;

  @override
  List<FiledReport> build() {
    final raw = ref.read(sharedPreferencesProvider).getStringList(_kReports);
    if (raw == null) return const [];
    final out = <FiledReport>[];
    for (final s in raw) {
      try {
        out.add(FiledReport.fromJson(
            (jsonDecode(s) as Map).cast<String, dynamic>()));
      } catch (_) {
        // A malformed entry shouldn't cost the user the rest of their log.
      }
    }
    return out;
  }

  void add(FiledReport report) {
    final next = [...state, report];
    if (next.length > _maxReports) {
      next.removeRange(0, next.length - _maxReports);
    }
    state = next;
    ref.read(sharedPreferencesProvider).setStringList(
          _kReports,
          next.map((r) => jsonEncode(r.toJson())).toList(),
        );
  }

  void clear() {
    state = const [];
    ref.read(sharedPreferencesProvider).remove(_kReports);
  }
}

// ──────────────────────────────── Live feed ───────────────────────────────────

/// Moderation events for the current room, for the UI to surface as toasts.
class ModerationFeed {
  const ModerationFeed({this.notices = const [], this.lastAck});

  /// Reports the **host** has received this room, oldest first.
  final List<SModerationNotice> notices;

  /// Set when the host acknowledges a report *this* device filed. The counter
  /// makes two acks for the same player distinguishable, so a `ref.listen`
  /// fires for each one instead of coalescing them.
  final ({String targetId, int seq})? lastAck;

  ModerationFeed copyWith({
    List<SModerationNotice>? notices,
    ({String targetId, int seq})? lastAck,
  }) =>
      ModerationFeed(
        notices: notices ?? this.notices,
        lastAck: lastAck ?? this.lastAck,
      );
}

final moderationFeedProvider =
    NotifierProvider<ModerationFeedNotifier, ModerationFeed>(
        ModerationFeedNotifier.new);

class ModerationFeedNotifier extends Notifier<ModerationFeed> {
  int _seq = 0;

  @override
  ModerationFeed build() => const ModerationFeed();

  void addNotice(SModerationNotice notice) =>
      state = state.copyWith(notices: [...state.notices, notice]);

  void ackReport(String targetId) =>
      state = state.copyWith(lastAck: (targetId: targetId, seq: ++_seq));

  /// Reset when a session ends — reports belong to the room they came from.
  void clear() => state = const ModerationFeed();
}
