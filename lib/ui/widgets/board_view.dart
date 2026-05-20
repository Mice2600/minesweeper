import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    required this.onReveal,
    required this.onFlag,
    required this.onChord,
    required this.onCursor,
    required this.onCursorLeave,
    this.interactive = true,
  });

  final GameSnapshot snapshot;

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
                  CustomMultiChildLayout(
                    delegate: _GridLayout(
                      width: w,
                      height: h,
                      cell: cellSize,
                    ),
                    children: [
                      for (var y = 0; y < h; y++)
                        for (var x = 0; x < w; x++)
                          LayoutId(
                            id: y * w + x,
                            child: _AnimatedCell(
                              x: x,
                              y: y,
                              value: _displayValue(x, y),
                              flagColor: _flagColor(x, y),
                              size: cellSize,
                              highlight: _isLastEvent(x, y),
                              pulsing: _pulseIndices.contains(y * w + x),
                            ),
                          ),
                    ],
                  ),
                  if (widget.snapshot.lastExplosion != null)
                    Positioned.fill(
                      child: ExplosionOverlay(
                        eventId: widget.snapshot.lastExplosion!.id,
                        centers: widget.snapshot.lastExplosion!.centers,
                        cellSize: cellSize,
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
      out.add(Positioned(
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
  _GridLayout({required this.width, required this.height, required this.cell});
  final int width;
  final int height;
  final double cell;

  @override
  void performLayout(Size size) {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final id = y * width + x;
        if (!hasChild(id)) continue;
        layoutChild(id, BoxConstraints.tight(Size(cell, cell)));
        positionChild(id, Offset(x * cell, y * cell));
      }
    }
  }

  @override
  bool shouldRelayout(covariant _GridLayout old) =>
      old.width != width || old.height != height || old.cell != cell;
}

class _AnimatedCell extends StatelessWidget {
  const _AnimatedCell({
    required this.x,
    required this.y,
    required this.value,
    required this.flagColor,
    required this.size,
    required this.highlight,
    required this.pulsing,
  });
  final int x;
  final int y;
  final int value;
  final Color? flagColor;
  final double size;
  final bool highlight;
  final bool pulsing;
  @override
  Widget build(BuildContext context) {
    return CellTile(
      x: x,
      y: y,
      value: value,
      flagColor: flagColor,
      size: size,
      highlight: highlight || pulsing,
    );
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
