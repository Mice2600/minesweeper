import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../game/engine.dart';
import '../../net/messages.dart';
import '../../state/session.dart';

/// Donut chart: share of total cells revealed per player.
///
/// One slice per player who revealed at least one cell, colored with the
/// player's chip color. Center label shows the team total.
class RevealShareDonut extends StatelessWidget {
  const RevealShareDonut({super.key, required this.snap});

  final GameSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final entries = <({PlayerInfo player, int revealed})>[
      for (final p in snap.players)
        if ((snap.stats[p.id]?.cellsRevealed ?? 0) > 0)
          (player: p, revealed: snap.stats[p.id]!.cellsRevealed),
    ];
    final total = entries.fold<int>(0, (s, e) => s + e.revealed);

    if (total == 0) {
      return _ChartEmpty(text: 'No cells were revealed.');
    }

    final sections = [
      for (final e in entries)
        PieChartSectionData(
          color: Color(e.player.color),
          value: e.revealed.toDouble(),
          title: '${((e.revealed / total) * 100).round()}%',
          radius: 46,
          titleStyle: GoogleFonts.jetBrainsMono(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
          borderSide: BorderSide(color: cs.surface, width: 2),
        ),
    ];

    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 48,
              sectionsSpace: 2,
              startDegreeOffset: -90,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$total',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              Text(
                'cells',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Grouped bar chart: per-player rods for cells revealed, correct flags,
/// and mines hit. Each metric has its own color, each group is one player.
class PerPlayerBars extends StatelessWidget {
  const PerPlayerBars({super.key, required this.snap});

  final GameSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final cellsColor = cs.primary;
    final flagsColor = cs.tertiary;
    final minesColor = cs.error;

    final players = snap.players;
    final perPlayer = [
      for (final p in players)
        (player: p, stats: snap.stats[p.id] ?? PlayerStats()),
    ];

    if (perPlayer.isEmpty) {
      return _ChartEmpty(text: 'No players to compare.');
    }

    var maxVal = 0;
    for (final e in perPlayer) {
      maxVal = [
        maxVal,
        e.stats.cellsRevealed,
        e.stats.correctFlags,
        e.stats.minesHit,
      ].reduce((a, b) => a > b ? a : b);
    }
    final maxY = (maxVal == 0 ? 1 : maxVal) * 1.15;

    final groups = <BarChartGroupData>[
      for (var i = 0; i < perPlayer.length; i++)
        BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: [
            _rod(perPlayer[i].stats.cellsRevealed.toDouble(), cellsColor),
            _rod(perPlayer[i].stats.correctFlags.toDouble(), flagsColor),
            _rod(perPlayer[i].stats.minesHit.toDouble(), minesColor),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY,
              minY: 0,
              barGroups: groups,
              alignment: BarChartAlignment.spaceAround,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY <= 5
                    ? 1
                    : (maxY / 4).ceilToDouble(),
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: maxY <= 5 ? 1 : (maxY / 4).ceilToDouble(),
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          value.toInt().toString(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= perPlayer.length) {
                        return const SizedBox.shrink();
                      }
                      final name = perPlayer[i].player.name;
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          name.length > 8
                              ? '${name.substring(0, 7)}…'
                              : name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurface,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, gIdx, rod, rIdx) {
                    const labels = ['cells', 'flags', 'mines'];
                    return BarTooltipItem(
                      '${labels[rIdx]}: ${rod.toY.toInt()}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 6,
          children: [
            _LegendDot(color: cellsColor, label: 'Cells revealed'),
            _LegendDot(color: flagsColor, label: 'Correct flags'),
            _LegendDot(color: minesColor, label: 'Mines hit'),
          ],
        ),
      ],
    );
  }

  BarChartRodData _rod(double y, Color color) => BarChartRodData(
        toY: y,
        color: color,
        width: 12,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      );
}

/// Line chart: cumulative non-mine reveals per player over match time.
/// One line per player using their chip color. Mine-hit moments are
/// marked with red dots.
class CumulativeRevealsLine extends StatelessWidget {
  const CumulativeRevealsLine({super.key, required this.snap});

  final GameSnapshot snap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duration = snap.durationMs;

    if (duration <= 0) {
      return _ChartEmpty(text: 'Timing data unavailable.');
    }

    final lines = <LineChartBarData>[];
    var maxY = 0;
    for (final p in snap.players) {
      final timeline = snap.stats[p.id]?.timeline ?? const [];
      if (timeline.isEmpty) continue;
      final sorted = [...timeline]..sort((a, b) => a.tMs.compareTo(b.tMs));
      final spots = <FlSpot>[const FlSpot(0, 0)];
      var cum = 0;
      final mineDots = <FlSpot>[];
      for (final e in sorted) {
        cum += e.revealed;
        spots.add(FlSpot(e.tMs.toDouble(), cum.toDouble()));
        if (e.mineHit) mineDots.add(FlSpot(e.tMs.toDouble(), cum.toDouble()));
      }
      if (cum > maxY) maxY = cum;

      final color = Color(p.color);
      lines.add(
        LineChartBarData(
          spots: spots,
          color: color,
          barWidth: 2.5,
          isCurved: false,
          dotData: FlDotData(
            show: true,
            checkToShowDot: (spot, bar) =>
                mineDots.any((d) => d.x == spot.x && d.y == spot.y),
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 4,
              color: cs.error,
              strokeWidth: 1.5,
              strokeColor: cs.surface,
            ),
          ),
        ),
      );
    }

    if (lines.isEmpty) {
      return _ChartEmpty(text: 'No reveal activity to chart.');
    }

    final yMax = (maxY == 0 ? 1 : maxY) * 1.1;
    final xStep = duration / 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              lineBarsData: lines,
              minX: 0,
              maxX: duration.toDouble(),
              minY: 0,
              maxY: yMax,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: yMax <= 8 ? 1 : (yMax / 4),
                getDrawingHorizontalLine: (_) => FlLine(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: yMax <= 8 ? 1 : (yMax / 4),
                    getTitlesWidget: (value, meta) {
                      if (value == 0 || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          value.toInt().toString(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: xStep,
                    getTitlesWidget: (value, meta) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        formatMmSs(value.toInt()),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (touched) => touched.map((t) {
                    return LineTooltipItem(
                      '${t.y.toInt()} @ ${formatMmSs(t.x.toInt())}',
                      TextStyle(
                        color: t.bar.color ?? cs.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            for (final p in snap.players)
              if ((snap.stats[p.id]?.timeline.isNotEmpty ?? false))
                _LegendDot(color: Color(p.color), label: p.name),
            _LegendDot(color: cs.error, label: 'mine hit', isRing: true),
          ],
        ),
      ],
    );
  }
}

/// Renders MM:SS from a duration in milliseconds.
String formatMmSs(int ms) {
  final totalSeconds = (ms / 1000).round();
  final m = totalSeconds ~/ 60;
  final s = totalSeconds % 60;
  return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    this.isRing = false,
  });
  final Color color;
  final String label;
  final bool isRing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isRing ? Colors.transparent : color,
            border: isRing ? Border.all(color: color, width: 2) : null,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ChartEmpty extends StatelessWidget {
  const _ChartEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
        ),
      ),
    );
  }
}
