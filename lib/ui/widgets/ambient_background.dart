import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// A calm, solid backdrop behind every screen. Intentionally flat — no
/// gradients, glows, or motion — so the content (and the board) stays the
/// focus and the app reads as quiet rather than busy. Wired once in
/// `main.dart` so it never rebuilds on navigation.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return ColoredBox(color: g.bg, child: child);
  }
}
