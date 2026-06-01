import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// The app's standard tactile surface: GamePalette panel fill + soft border +
/// drop shadow, on rounded corners. Used in place of a flat Material [Card] so
/// every elevated surface shares the same depth language (home buttons, HUD
/// bubbles, result panels, lobby cards).
class GamePanel extends StatelessWidget {
  const GamePanel({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.radius = 22,
    this.clipBehavior = Clip.none,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double radius;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final g = Theme.of(context).extension<GamePalette>() ?? GamePalette.light;
    return Container(
      padding: padding,
      clipBehavior: clipBehavior,
      decoration: BoxDecoration(
        color: g.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? g.panelBorder),
        boxShadow: [
          BoxShadow(color: g.panelShadow, blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: child,
    );
  }
}
