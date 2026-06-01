import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/board_skin.dart';
import '../../game/engine.dart';
import '../../state/session.dart';
import 'cell_tile.dart';
import 'explosion_overlay.dart';
import 'explosion_timing.dart';

typedef CellCb = void Function(int x, int y);
typedef CursorCb = void Function(double nx, double ny);

class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.snapshot,
    required this.cellSize,
    required this.skin,
    required this.onReveal,
    required this.onFlag,
    required this.onChord,
    required this.onCursor,
    required this.onCursorLeave,
    this.interactive = true,
  });

  final GameSnapshot snapshot;

  /// Color set for the board map.
  final BoardSkin skin;

  /// Pixel size of a single cell. Sized by the parent so the layout can be
  /// computed once with full visibility of viewport insets, padding, etc.
  final double cellSize;
  final CellCb onReveal;
  final CellCb onFlag;
  final CellCb onChord;
  final CursorCb onCursor;
  final VoidCallback onCursorLeave;
  final bool interactive;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  final Set<int> _pulseIndices = {};
  Timer? _pulseTimer;

  /// Per-cell-index timestamp (microsecondsSinceEpoch) at which a chain-
  /// revealed cell should become visible. Cells revealed normally are not
  /// in this map and render immediately.
  final Map<int, int> _revealAt = {};
  int _lastExplosionId = 0;
  Timer? _chainTicker;

  // Timing comes from the shared ExplosionTiming so cells and rings stay in
  // lockstep.

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _chainTicker?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(BoardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeScheduleChainReveal(oldWidget.snapshot, widget.snapshot);
  }

  void _maybeScheduleChainReveal(GameSnapshot oldSnap, GameSnapshot newSnap) {
    final explosion = newSnap.lastExplosion;
    if (explosion == null || explosion.id == _lastExplosionId) return;
    _lastExplosionId = explosion.id;
    final centers = explosion.centers;
    if (centers.isEmpty) return;
    final now = DateTime.now().microsecondsSinceEpoch;
    // For every cell that just transitioned from hidden to revealed, compute
    // when its ring would reach it.
    final w = newSnap.width;
    final cells = newSnap.cells;
    final oldCells = oldSnap.cells;
    final lenMatch = oldCells.length == cells.length;
    for (var i = 0; i < cells.length; i++) {
      if (lenMatch && oldCells[i] != -2) continue; // already revealed
      if (cells[i] == -2) continue; // still hidden
      final cx = i % w;
      final cy = i ~/ w;
      var bestMs = 1 << 30;
      for (var k = 0; k < centers.length; k++) {
        final dx = (cx - centers[k][0]).abs();
        final dy = (cy - centers[k][1]).abs();
        var cheb = dx > dy ? dx : dy;
        if (cheb > ExplosionTiming.maxDistance) {
          cheb = ExplosionTiming.maxDistance;
        }
        final delay = k * ExplosionTiming.msPerCenter +
            cheb * ExplosionTiming.msPerDistance;
        if (delay < bestMs) bestMs = delay;
      }
      if (bestMs > 0) {
        _revealAt[i] = now + bestMs * 1000;
      }
    }
    _chainTicker?.cancel();
    _chainTicker = Timer.periodic(const Duration(milliseconds: 30), (_) {
      final t = DateTime.now().microsecondsSinceEpoch;
      _revealAt.removeWhere((_, due) => due <= t);
      if (_revealAt.isEmpty) {
        _chainTicker?.cancel();
        _chainTicker = null;
      }
      if (mounted) setState(() {});
    });
  }

  void _pulseNeighbors(int x, int y) {
    final snap = widget.snapshot;
    final next = <int>{};
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        if (dx == 0 && dy == 0) continue;
        final nx = x + dx;
        final ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= snap.width || ny >= snap.height) continue;
        if (snap.cellAt(nx, ny) != -2) continue; // only pulse hidden cells
        if (snap.flagAt(nx, ny) != null) continue; // skip flagged
        if (snap.questionAt(nx, ny) != null) continue; // skip questioned
        next.add(ny * snap.width + nx);
      }
    }
    if (next.isEmpty) return;
    setState(() {
      _pulseIndices
        ..clear()
        ..addAll(next);
    });
    _pulseTimer?.cancel();
    _pulseTimer = Timer(const Duration(milliseconds: 240), () {
      if (!mounted) return;
      setState(_pulseIndices.clear);
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.snapshot.width;
    final h = widget.snapshot.height;
    final cellSize = widget.cellSize;
    final boardWidth = cellSize * w;
    final boardHeight = cellSize * h;
    final won = widget.snapshot.status == GameStatus.won;
    final exploded = widget.snapshot.explodedMines;

    return SizedBox(
      width: boardWidth,
      height: boardHeight,
      child: Listener(
        onPointerDown: widget.interactive
            ? (e) {
                if (e.kind != PointerDeviceKind.touch) return;
                _emitCursor(e.localPosition, boardWidth, boardHeight);
              }
            : null,
        onPointerMove: widget.interactive
            ? (e) {
                if (e.kind != PointerDeviceKind.touch) return;
                _emitCursor(e.localPosition, boardWidth, boardHeight);
              }
            : null,
        onPointerUp: widget.interactive
            ? (e) {
                if (e.kind != PointerDeviceKind.touch) return;
                widget.onCursorLeave();
              }
            : null,
        onPointerCancel: widget.interactive
            ? (e) {
                if (e.kind != PointerDeviceKind.touch) return;
                widget.onCursorLeave();
              }
            : null,
        child: MouseRegion(
            onHover: widget.interactive
                ? (e) => _emitCursor(e.localPosition, boardWidth, boardHeight)
                : null,
            onExit: widget.interactive
                ? (_) => widget.onCursorLeave()
                : null,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: widget.interactive
                  ? (d) => _tap(d.localPosition, cellSize, false)
                  : null,
              onSecondaryTapUp: widget.interactive
                  ? (d) => _tap(d.localPosition, cellSize, true)
                  : null,
              onLongPressStart: widget.interactive
                  ? (d) {
                      HapticFeedback.mediumImpact();
                      _tap(d.localPosition, cellSize, true);
                    }
                  : null,
              child: Stack(
                children: [
                  // Board background shows through cell gaps (tile/neumorphic).
                  // Transparent for full-bleed structures, so nothing mounts and
                  // the grid covers everything exactly as before.
                  if (widget.skin.boardBackground != Colors.transparent)
                    Positioned.fill(
                      child: ColoredBox(color: widget.skin.boardBackground),
                    ),
                  CustomMultiChildLayout(
                    delegate: _GridLayout(
                      width: w,
                      height: h,
                      cell: cellSize,
                      // Gap structures must not overlap or the overlap eats the
                      // gap; full-bleed structures keep the seam-hiding overlap.
                      overdraw: widget.skin.cellGapFrac > 0 ? 0.0 : 0.75,
                    ),
                    children: [
                      for (var y = 0; y < h; y++)
                        for (var x = 0; x < w; x++)
                          LayoutId(
                            id: y * w + x,
                            child: RepaintBoundary(
                              child: _AnimatedCell(
                                x: x,
                                y: y,
                                value: _displayValue(x, y),
                                flagColor: _flagColor(x, y),
                                questionColor: _questionColor(x, y),
                                size: cellSize,
                                skin: widget.skin,
                                highlight: _isLastEvent(x, y),
                                pulsing: _pulseIndices.contains(y * w + x),
                                won: won,
                                wasExploded: exploded.contains(y * w + x),
                              ),
                            ),
                          ),
                    ],
                  ),
                  // The painted "cliff" edge only makes sense for the grass
                  // structure; other structures draw their own per-cell
                  // borders/bevels in CellTile.
                  if (widget.skin.structure == CellStructure.grass)
                    IgnorePointer(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size(boardWidth, boardHeight),
                          painter: _BoardEdgesPainter(
                            displayValues: [
                              for (var i = 0; i < w * h; i++)
                                _displayValue(i % w, i ~/ w),
                            ],
                            width: w,
                            height: h,
                            cell: cellSize,
                            edgeColor: widget.skin.hiddenEdge,
                          ),
                        ),
                      ),
                    ),
                  if (widget.snapshot.lastExplosion != null)
                    Positioned.fill(
                      // Its own layer so the animated rings/debris don't share
                      // (and re-rasterize) the static edge-stroke pass.
                      child: RepaintBoundary(
                        child: ExplosionOverlay(
                          eventId: widget.snapshot.lastExplosion!.id,
                          centers: widget.snapshot.lastExplosion!.centers,
                          cellSize: cellSize,
                        ),
                      ),
                    ),
                  ..._buildCursors(boardWidth, boardHeight),
                ],
              ),
            ),
          ),
        ),
      );
  }

  /// Returns the value to render for cell (x,y) right now. If the cell is
  /// being held back by an in-flight chain animation, returns -2 (hidden)
  /// until its scheduled time arrives.
  int _displayValue(int x, int y) {
    final w = widget.snapshot.width;
    final idx = y * w + x;
    final due = _revealAt[idx];
    if (due != null && DateTime.now().microsecondsSinceEpoch < due) {
      return -2;
    }
    return widget.snapshot.cellAt(x, y);
  }

  Color? _flagColor(int x, int y) {
    final pid = widget.snapshot.flagAt(x, y);
    if (pid == null) return null;
    final p = widget.snapshot.playerById(pid);
    return p == null ? null : Color(p.color);
  }

  Color? _questionColor(int x, int y) {
    final pid = widget.snapshot.questionAt(x, y);
    if (pid == null) return null;
    final p = widget.snapshot.playerById(pid);
    return p == null ? null : Color(p.color);
  }

  bool _isLastEvent(int x, int y) {
    final le = widget.snapshot.lastEvent;
    return le != null && le.x == x && le.y == y;
  }

  void _tap(Offset pos, double cellSize, bool flag) {
    final snap = widget.snapshot;
    final x = (pos.dx ~/ cellSize);
    final y = (pos.dy ~/ cellSize);
    if (x < 0 || y < 0 || x >= snap.width || y >= snap.height) return;
    final cellValue = snap.cellAt(x, y);
    if (flag) {
      widget.onFlag(x, y);
    } else if (cellValue >= 1 && cellValue <= 8) {
      _pulseNeighbors(x, y);
      widget.onChord(x, y);
    } else {
      widget.onReveal(x, y);
    }
  }

  void _emitCursor(Offset local, double w, double h) {
    if (w <= 0 || h <= 0) return;
    final nx = (local.dx / w).clamp(0.0, 1.0);
    final ny = (local.dy / h).clamp(0.0, 1.0);
    widget.onCursor(nx, ny);
  }

  List<Widget> _buildCursors(double w, double h) {
    final out = <Widget>[];
    widget.snapshot.cursors.forEach((pid, pos) {
      final p = widget.snapshot.playerById(pid);
      if (p == null) return;
      // Cursors are sent at ~10 Hz (see [_throttledCursor]). AnimatedPositioned
      // lerps between updates so motion looks fluid at much lower bandwidth.
      // The ValueKey keeps the widget identity stable across rebuilds so the
      // tween animates instead of teleporting.
      out.add(AnimatedPositioned(
        key: ValueKey('cursor-$pid'),
        duration: const Duration(milliseconds: 140),
        curve: Curves.linear,
        left: pos.nx * w - 10,
        top: pos.ny * h - 10,
        child: IgnorePointer(
          child: _CursorMark(color: Color(p.color), name: p.name),
        ),
      ));
    });
    return out;
  }
}

class _GridLayout extends MultiChildLayoutDelegate {
  _GridLayout({
    required this.width,
    required this.height,
    required this.cell,
    this.overdraw = 0.75,
  });
  final int width;
  final int height;
  final double cell;

  // Each cell overdraws by this much on the right and bottom so neighbors
  // overlap by a fraction of a pixel. At fractional InteractiveViewer zoom
  // levels this hides subpixel antialiasing seams between adjacent cells
  // (which otherwise appear as thin bright lines through the grid). Gap
  // structures pass 0 so the overlap doesn't eat their intentional gap.
  final double overdraw;

  @override
  void performLayout(Size size) {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final id = y * width + x;
        if (!hasChild(id)) continue;
        final extraW = x == width - 1 ? 0.0 : overdraw;
        final extraH = y == height - 1 ? 0.0 : overdraw;
        layoutChild(id, BoxConstraints.tight(Size(cell + extraW, cell + extraH)));
        positionChild(id, Offset(x * cell, y * cell));
      }
    }
  }

  @override
  bool shouldRelayout(covariant _GridLayout old) =>
      old.width != width ||
      old.height != height ||
      old.cell != cell ||
      old.overdraw != overdraw;
}

class _AnimatedCell extends StatelessWidget {
  const _AnimatedCell({
    required this.x,
    required this.y,
    required this.value,
    required this.flagColor,
    required this.questionColor,
    required this.size,
    required this.skin,
    required this.highlight,
    required this.pulsing,
    required this.won,
    required this.wasExploded,
  });
  final int x;
  final int y;
  final int value;
  final Color? flagColor;
  final Color? questionColor;
  final double size;
  final BoardSkin skin;
  final bool highlight;
  final bool pulsing;
  final bool won;
  final bool wasExploded;
  @override
  Widget build(BuildContext context) {
    return CellTile(
      x: x,
      y: y,
      value: value,
      flagColor: flagColor,
      questionColor: questionColor,
      size: size,
      skin: skin,
      highlight: highlight || pulsing,
      won: won,
      wasExploded: wasExploded,
    );
  }
}

/// Paints the dark "cliff" between hidden grass and revealed dirt as a
/// single canvas pass on top of the grid. Drawing edges as one painter
/// avoids the InteractiveViewer subpixel-seam issue that affects per-cell
/// borders, and keeps lines sharp regardless of zoom.
class _BoardEdgesPainter extends CustomPainter {
  _BoardEdgesPainter({
    required this.displayValues,
    required this.width,
    required this.height,
    required this.cell,
    required this.edgeColor,
  });

  final List<int> displayValues;
  final int width;
  final int height;
  final double cell;
  final Color edgeColor;

  static const double _strokeWidth = 1.5;

  bool _hidden(int x, int y) {
    if (x < 0 || y < 0 || x >= width || y >= height) return false;
    return displayValues[y * width + x] == -2;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = edgeColor
      ..strokeWidth = _strokeWidth
      ..style = PaintingStyle.stroke;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (!_hidden(x, y)) continue;
        final left = x * cell;
        final top = y * cell;
        final right = left + cell;
        final bottom = top + cell;
        if (!_hidden(x, y - 1)) {
          canvas.drawLine(Offset(left, top), Offset(right, top), paint);
        }
        if (!_hidden(x + 1, y)) {
          canvas.drawLine(Offset(right, top), Offset(right, bottom), paint);
        }
        if (!_hidden(x, y + 1)) {
          canvas.drawLine(Offset(left, bottom), Offset(right, bottom), paint);
        }
        if (!_hidden(x - 1, y)) {
          canvas.drawLine(Offset(left, top), Offset(left, bottom), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BoardEdgesPainter old) {
    if (old.width != width ||
        old.height != height ||
        old.cell != cell ||
        old.edgeColor != edgeColor) {
      return true;
    }
    final a = old.displayValues;
    final b = displayValues;
    if (a.length != b.length) return true;
    for (var i = 0; i < a.length; i++) {
      // Only the hidden/not-hidden distinction matters for edges.
      if ((a[i] == -2) != (b[i] == -2)) return true;
    }
    return false;
  }
}

class _CursorMark extends StatelessWidget {
  const _CursorMark({required this.color, required this.name});
  final Color color;
  final String name;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
