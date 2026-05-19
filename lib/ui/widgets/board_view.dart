import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../state/session.dart';
import 'cell_tile.dart';

typedef CellCb = void Function(int x, int y);
typedef CursorCb = void Function(double nx, double ny);

class BoardView extends StatefulWidget {
  const BoardView({
    super.key,
    required this.snapshot,
    required this.onReveal,
    required this.onFlag,
    required this.onChord,
    required this.onCursor,
    this.interactive = true,
  });

  final GameSnapshot snapshot;
  final CellCb onReveal;
  final CellCb onFlag;
  final CellCb onChord;
  final CursorCb onCursor;
  final bool interactive;

  @override
  State<BoardView> createState() => _BoardViewState();
}

class _BoardViewState extends State<BoardView> {
  final Set<int> _pulseIndices = {};
  Timer? _pulseTimer;

  @override
  void dispose() {
    _pulseTimer?.cancel();
    super.dispose();
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
    return LayoutBuilder(builder: (context, constraints) {
      final w = widget.snapshot.width;
      final h = widget.snapshot.height;
      const minCell = 28.0;
      const maxCell = 56.0;
      final wantW = constraints.maxWidth / w;
      final wantH = constraints.maxHeight / h;
      final cell = wantW.isFinite && wantH.isFinite
          ? wantW.clamp(minCell, maxCell).toDouble()
          : minCell;
      final cellSize =
          wantH.isFinite ? cell.clamp(minCell, wantH).toDouble() : cell;

      final boardWidth = cellSize * w;
      final boardHeight = cellSize * h;

      return Center(
        child: SizedBox(
          width: boardWidth,
          height: boardHeight,
          child: MouseRegion(
            onHover: widget.interactive
                ? (e) => _emitCursor(e.localPosition, boardWidth, boardHeight)
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
                              value: widget.snapshot.cellAt(x, y),
                              flagColor: _flagColor(x, y),
                              size: cellSize,
                              highlight: _isLastEvent(x, y),
                              pulsing: _pulseIndices.contains(y * w + x),
                            ),
                          ),
                    ],
                  ),
                  ..._buildCursors(boardWidth, boardHeight),
                ],
              ),
            ),
          ),
        ),
      );
    });
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
    required this.value,
    required this.flagColor,
    required this.size,
    required this.highlight,
    required this.pulsing,
  });
  final int value;
  final Color? flagColor;
  final double size;
  final bool highlight;
  final bool pulsing;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: pulsing ? 0.84 : (highlight ? 1.06 : 1.0),
      duration: Duration(milliseconds: pulsing ? 120 : 200),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.18),
          color: pulsing
              ? cs.primary.withValues(alpha: 0.25)
              : Colors.transparent,
        ),
        child: CellTile(
          value: value,
          flagColor: flagColor,
          size: size,
          highlight: highlight || pulsing,
        ),
      ),
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
