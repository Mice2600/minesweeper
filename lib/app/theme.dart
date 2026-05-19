import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const seedColor = Color(0xFF6750A4);

  static ThemeData build(Brightness brightness, ColorScheme? dynamicScheme) {
    final scheme = dynamicScheme ??
        ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);

    final base = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }
}

/// Wraps the app in `DynamicColorBuilder` so on Android 12+ we pick up the
/// system accent automatically.
class ThemeShell extends StatelessWidget {
  const ThemeShell({super.key, required this.builder});

  final Widget Function(BuildContext, ThemeData light, ThemeData dark) builder;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (light, dark) {
        return builder(
          context,
          AppTheme.build(Brightness.light, light),
          AppTheme.build(Brightness.dark, dark),
        );
      },
    );
  }
}
