import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/analytics.dart';
import '../core/prefs.dart';
import '../game/difficulty.dart';
import '../game/engine.dart';
import 'session.dart';

/// Achievements are **local & personal**: every device tracks its own unlocks
/// from the local player's own stats, evaluated once when a match finishes.
/// There is no networking — everything needed is already in [GameSnapshot].
///
/// Persistence mirrors `store.dart`: read on [AchievementsNotifier.build],
/// write back on every mutation. The transient toast queue mirrors
/// `EmojiBurstNotifier` (auto-removing after a delay).

// ─────────────────────────────────── Lifetime stats ────────────────────────

/// Counters that accumulate across every finished game on this device. Bumped
/// exactly once per game thanks to the [lastGameKey] dedupe.
class AchievementStats {
  const AchievementStats({
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.totalCells = 0,
    this.lastGameKey = 0,
  });

  final int gamesPlayed;
  final int gamesWon;

  /// Total non-mine cells the local player has uncovered, all-time.
  final int totalCells;

  /// `endedAtMs` of the last game we evaluated. Guards against double-counting
  /// when the trigger re-fires (widget rebuilds, app relaunch on the result
  /// screen).
  final int lastGameKey;

  AchievementStats copyWith({
    int? gamesPlayed,
    int? gamesWon,
    int? totalCells,
    int? lastGameKey,
  }) =>
      AchievementStats(
        gamesPlayed: gamesPlayed ?? this.gamesPlayed,
        gamesWon: gamesWon ?? this.gamesWon,
        totalCells: totalCells ?? this.totalCells,
        lastGameKey: lastGameKey ?? this.lastGameKey,
      );

  Map<String, dynamic> toJson() => {
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'totalCells': totalCells,
        'lastGameKey': lastGameKey,
      };

  factory AchievementStats.fromJson(Map<String, dynamic> json) =>
      AchievementStats(
        gamesPlayed: json['gamesPlayed'] as int? ?? 0,
        gamesWon: json['gamesWon'] as int? ?? 0,
        totalCells: json['totalCells'] as int? ?? 0,
        lastGameKey: json['lastGameKey'] as int? ?? 0,
      );
}

// ─────────────────────────────────── Definitions ───────────────────────────

/// Everything an achievement's [earned] predicate can read at game-end.
class AchievementContext {
  AchievementContext({
    required this.snap,
    required this.me,
    required this.difficulty,
    required this.stats,
  });

  final GameSnapshot snap;

  /// The local player's final stats for the just-finished game.
  final PlayerStats me;

  /// The standard difficulty this board matches, or null for a custom size.
  final Difficulty? difficulty;

  /// Lifetime counters — already include the just-finished game.
  final AchievementStats stats;

  bool get won => snap.status == GameStatus.won;

  /// Did the local player actually do anything this game?
  bool get participated => me.clicks > 0;

  GameMode get mode => snap.config.mode;
}

/// An immutable achievement definition. [earned] is checked against a finished
/// game; [progress] (optional) renders "7/10 games" on still-locked cumulative
/// achievements from the persisted [AchievementStats] alone.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.earned,
    this.progress,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool Function(AchievementContext) earned;
  final String? Function(AchievementStats)? progress;
}

/// The catalog. Skill/personal achievements gate on [AchievementContext.participated]
/// so a player who did nothing can't pick them up. Easy to tune.
final List<Achievement> kAchievements = [
  Achievement(
    id: 'first_game',
    title: 'First Steps',
    description: 'Finish your first game.',
    icon: Icons.directions_walk_rounded,
    earned: (c) => c.stats.gamesPlayed >= 1,
  ),
  Achievement(
    id: 'first_win',
    title: 'Cleared!',
    description: 'Win your first game.',
    icon: Icons.celebration_rounded,
    earned: (c) => c.stats.gamesWon >= 1,
  ),
  Achievement(
    id: 'win_easy',
    title: 'Greenhorn',
    description: 'Win a game on Easy.',
    icon: Icons.spa_rounded,
    earned: (c) => c.won && c.difficulty == Difficulty.easy,
  ),
  Achievement(
    id: 'win_medium',
    title: 'Steady Hands',
    description: 'Win a game on Medium.',
    icon: Icons.back_hand_rounded,
    earned: (c) => c.won && c.difficulty == Difficulty.medium,
  ),
  Achievement(
    id: 'win_hard',
    title: 'Bomb Squad',
    description: 'Win a game on Hard.',
    icon: Icons.military_tech_rounded,
    earned: (c) => c.won && c.difficulty == Difficulty.hard,
  ),
  Achievement(
    id: 'flawless',
    title: 'Flawless',
    description: 'Win without setting off a single mine.',
    icon: Icons.verified_rounded,
    earned: (c) => c.won && c.participated && c.me.minesHit == 0,
  ),
  Achievement(
    id: 'sharpshooter',
    title: 'Sharpshooter',
    description: 'Win a game with no wrong flags (at least one correct).',
    icon: Icons.gps_fixed_rounded,
    earned: (c) =>
        c.won && c.me.correctFlags > 0 && c.me.incorrectFlags == 0,
  ),
  Achievement(
    id: 'big_dig',
    title: 'Big Dig',
    description: 'Uncover 30+ cells in a single tap.',
    icon: Icons.open_in_full_rounded,
    earned: (c) => c.me.largestCascade >= 30,
  ),
  Achievement(
    id: 'chord_master',
    title: 'Chord Master',
    description: 'Make 10+ chord moves in one game.',
    icon: Icons.touch_app_rounded,
    earned: (c) => c.me.chordMoves >= 10,
  ),
  Achievement(
    id: 'speed_demon',
    title: 'Speed Demon',
    description: 'Win a game in under a minute.',
    icon: Icons.bolt_rounded,
    earned: (c) =>
        c.won && c.snap.durationMs > 0 && c.snap.durationMs < 60000,
  ),
  Achievement(
    id: 'survivor',
    title: 'Survivor',
    description: 'Win a Hearts game without losing a heart.',
    icon: Icons.favorite_rounded,
    earned: (c) =>
        c.won &&
        c.mode == GameMode.hearts &&
        c.snap.hearts == c.snap.initialHearts,
  ),
  Achievement(
    id: 'close_call',
    title: 'Close Call',
    description: 'Win a Hearts game with a single heart left.',
    icon: Icons.favorite_border_rounded,
    earned: (c) =>
        c.won && c.mode == GameMode.hearts && c.snap.hearts == 1,
  ),
  Achievement(
    id: 'teamwork',
    title: 'Teamwork',
    description: 'Win a game where a teammate also dug.',
    icon: Icons.groups_rounded,
    earned: (c) =>
        c.won &&
        c.snap.stats.values.where((s) => s.cellsRevealed > 0).length >= 2,
  ),
  Achievement(
    id: 'veteran',
    title: 'Veteran',
    description: 'Finish 10 games.',
    icon: Icons.shield_rounded,
    earned: (c) => c.stats.gamesPlayed >= 10,
    progress: (s) =>
        s.gamesPlayed >= 10 ? null : '${s.gamesPlayed}/10 games',
  ),
  Achievement(
    id: 'centurion',
    title: 'Centurion',
    description: 'Uncover 1,000 cells in total.',
    icon: Icons.grid_on_rounded,
    earned: (c) => c.stats.totalCells >= 1000,
    progress: (s) =>
        s.totalCells >= 1000 ? null : '${s.totalCells}/1000 cells',
  ),
];

// ─────────────────────────────────── Toast queue ───────────────────────────

/// A transient "achievement unlocked" popup, queued for the overlay to render
/// and auto-dismissed after a few seconds.
class AchievementToast {
  AchievementToast(this.achievementId, this.title, this.icon)
      : id = _rand.nextInt(1 << 31);
  static final _rand = Random();

  final int id;
  final String achievementId;
  final String title;
  final IconData icon;
}

// ─────────────────────────────────── State ─────────────────────────────────

class AchievementState {
  const AchievementState({
    required this.unlocked,
    required this.stats,
    this.pending = const [],
  });

  final Set<String> unlocked;
  final AchievementStats stats;
  final List<AchievementToast> pending;

  AchievementState copyWith({
    Set<String>? unlocked,
    AchievementStats? stats,
    List<AchievementToast>? pending,
  }) =>
      AchievementState(
        unlocked: unlocked ?? this.unlocked,
        stats: stats ?? this.stats,
        pending: pending ?? this.pending,
      );
}

// ─────────────────────────────────── Notifier ──────────────────────────────

const String _kUnlockedKey = 'achievements.unlocked';
const String _kStatsKey = 'achievements.stats';

const Duration _toastLifetime = Duration(seconds: 4);

/// Persisted unlocked set + lifetime counters, plus the live toast queue.
/// Reads from SharedPreferences on build and writes back on every change.
final achievementsProvider =
    NotifierProvider<AchievementsNotifier, AchievementState>(
        AchievementsNotifier.new);

class AchievementsNotifier extends Notifier<AchievementState> {
  @override
  AchievementState build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final unlocked = {...?prefs.getStringList(_kUnlockedKey)};
    var stats = const AchievementStats();
    final raw = prefs.getString(_kStatsKey);
    if (raw != null) {
      try {
        stats = AchievementStats.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Corrupt blob — fall back to zeros rather than crash.
      }
    }
    return AchievementState(unlocked: unlocked, stats: stats);
  }

  /// Evaluate the catalog against a finished game. Idempotent per game: a
  /// repeat call with the same `endedAtMs` is a no-op, so it's safe to fire
  /// from a rebuilding widget listener.
  void recordGameEnd(GameSnapshot snap, String localId) {
    final key = snap.endedAtMs;
    if (key <= 0 || key == state.stats.lastGameKey) return;
    if (snap.status != GameStatus.won && snap.status != GameStatus.lost) {
      return;
    }

    final me = snap.stats[localId] ?? PlayerStats();
    final won = snap.status == GameStatus.won;

    final newStats = state.stats.copyWith(
      gamesPlayed: state.stats.gamesPlayed + 1,
      gamesWon: state.stats.gamesWon + (won ? 1 : 0),
      totalCells: state.stats.totalCells + me.cellsRevealed,
      lastGameKey: key,
    );

    final ctx = AchievementContext(
      snap: snap,
      me: me,
      difficulty: _difficultyOf(snap.config),
      stats: newStats,
    );

    final unlocked = {...state.unlocked};
    final newToasts = <AchievementToast>[];
    for (final a in kAchievements) {
      if (unlocked.contains(a.id)) continue;
      var ok = false;
      try {
        ok = a.earned(ctx);
      } catch (_) {
        ok = false;
      }
      if (ok) {
        unlocked.add(a.id);
        newToasts.add(AchievementToast(a.id, a.title, a.icon));
        Analytics.instance.achievementUnlocked(id: a.id);
      }
    }

    // Counters always advance once per game, even when nothing new unlocked.
    state = state.copyWith(
      unlocked: unlocked,
      stats: newStats,
      pending: [...state.pending, ...newToasts],
    );
    _persist();

    for (final t in newToasts) {
      Future.delayed(_toastLifetime, () => dismissToast(t.id));
    }
  }

  void dismissToast(int id) {
    if (!state.pending.any((t) => t.id == id)) return;
    state = state.copyWith(
      pending: state.pending.where((t) => t.id != id).toList(),
    );
  }

  /// Debug: wipe all progress back to first-launch.
  void resetDebug() {
    state = const AchievementState(
      unlocked: {},
      stats: AchievementStats(),
    );
    _persist();
  }

  void _persist() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setStringList(_kUnlockedKey, state.unlocked.toList());
    prefs.setString(_kStatsKey, jsonEncode(state.stats.toJson()));
  }
}

/// The standard [Difficulty] this board matches by size + mine count, or null
/// for a custom configuration.
Difficulty? _difficultyOf(GameConfig c) {
  for (final d in Difficulty.values) {
    if (d.width == c.width && d.height == c.height && d.mines == c.mines) {
      return d;
    }
  }
  return null;
}
