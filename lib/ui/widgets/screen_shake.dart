import 'dart:math';

import 'package:flutter/material.dart';

/// Translates its child with a damped 2D sinusoidal shake whenever
/// [triggerId] changes (and is non-zero). [magnitude] is the peak pixel
/// offset at t=0; the shake decays linearly to 0 over [duration].
class ScreenShake extends StatefulWidget {
  const ScreenShake({
    super.key,
    required this.triggerId,
    required this.magnitude,
    required this.child,
    this.duration = const Duration(milliseconds: 520),
  });

  final int triggerId;
  final double magnitude;
  final Widget child;
  final Duration duration;

  @override
  State<ScreenShake> createState() => _ScreenShakeState();
}

class _ScreenShakeState extends State<ScreenShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late int _lastId;
  double _activeMagnitude = 0;
  double _angleSeed = 0;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _lastId = widget.triggerId;
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didUpdateWidget(ScreenShake old) {
    super.didUpdateWidget(old);
    if (widget.triggerId != _lastId && widget.triggerId != 0) {
      _lastId = widget.triggerId;
      _activeMagnitude = widget.magnitude;
      _angleSeed = _rng.nextDouble() * pi * 2;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Offset _offset() {
    if (_ctrl.status == AnimationStatus.dismissed) return Offset.zero;
    final t = _ctrl.value;
    final decay = 1 - t;
    final amp = _activeMagnitude * decay;
    const freq = 16 * pi; // ~8 Hz over 1 second normalized
    final x = amp * sin(t * freq + _angleSeed);
    final y = amp * sin(t * freq * 1.07 + _angleSeed + 0.6);
    return Offset(x, y);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Transform.translate(offset: _offset(), child: child),
      child: widget.child,
    );
  }
}
