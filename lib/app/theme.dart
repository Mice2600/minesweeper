import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Art direction: "Dig the Field".
///
/// The board is the hero and it already commits to the Google-Minesweeper
/// grass/dirt look (leaf greens + warm earth). The whole app leans into that:
/// a sunny, outdoorsy, slightly playful identity. Leaf-green is the brand,
/// warm cream/parchment are the surfaces, and a punchy pumpkin-amber is the
/// "do this now" accent that pops against all the green. Headings are set in
/// Fredoka (chunky + rounded + game-y), body in Nunito (clean, friendly), and
/// stats stay in JetBrains Mono.
/// ─────────────────────────────────────────────────────────────────────────
class AppPalette {
  // Grass + leaf greens (tie into the board's #AAD751 grass).
  static const leaf = Color(0xFF4C9A2A);
  static const leafBright = Color(0xFF9CCC65);
  static const grass = Color(0xFFAAD751);

  // Earth / dirt tones (tie into the board's revealed-dirt #E5C29F).
  static const dirt = Color(0xFFC9A06B);
  static const soil = Color(0xFF6B4F2A);

  // Sunny pumpkin-amber: the primary call-to-action accent.
  static const amber = Color(0xFFEE7B30);
  static const amberBright = Color(0xFFFFB270);

  // Sky blue: informational / tertiary.
  static const sky = Color(0xFF3B82C4);

  // Warm neutrals.
  static const cream = Color(0xFFFBF6E9);
  static const parchment = Color(0xFFF1E8D2);
  static const ink = Color(0xFF2B2A22);

  // Night-forest neutrals (dark mode).
  static const forest = Color(0xFF152018);

  static const danger = Color(0xFFD7402F);
}

/// Brand tokens that differ between light and dark and don't fit the Material
/// [ColorScheme] — surfaced as a [ThemeExtension] so widgets (notably the
/// ambient background and tactile panels) can read them off the theme.
@immutable
class GamePalette extends ThemeExtension<GamePalette> {
  const GamePalette({
    required this.bg,
    required this.panel,
    required this.panelBorder,
    required this.panelShadow,
  });

  /// Flat, calm page background behind every screen (no gradient/motion).
  final Color bg;

  /// Tactile panel fill + border + soft drop shadow.
  final Color panel;
  final Color panelBorder;
  final Color panelShadow;

  static const light = GamePalette(
    bg: Color(0xFFF1ECDF),
    panel: Color(0xFFFFFFFF),
    panelBorder: Color(0x12000000),
    panelShadow: Color(0x12231A0C),
  );

  static const dark = GamePalette(
    bg: Color(0xFF161D18),
    panel: Color(0xFF202B23),
    panelBorder: Color(0x1AFFFFFF),
    panelShadow: Color(0x4D000000),
  );

  @override
  GamePalette copyWith({
    Color? bg,
    Color? panel,
    Color? panelBorder,
    Color? panelShadow,
  }) =>
      GamePalette(
        bg: bg ?? this.bg,
        panel: panel ?? this.panel,
        panelBorder: panelBorder ?? this.panelBorder,
        panelShadow: panelShadow ?? this.panelShadow,
      );

  @override
  GamePalette lerp(ThemeExtension<GamePalette>? other, double t) {
    if (other is! GamePalette) return this;
    return GamePalette(
      bg: Color.lerp(bg, other.bg, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelBorder: Color.lerp(panelBorder, other.panelBorder, t)!,
      panelShadow: Color.lerp(panelShadow, other.panelShadow, t)!,
    );
  }
}

class AppTheme {
  static ColorScheme _scheme(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const ColorScheme.dark(
        primary: AppPalette.leafBright,
        onPrimary: Color(0xFF11270A),
        primaryContainer: Color(0xFF2F5320),
        onPrimaryContainer: Color(0xFFD7F0B5),
        secondary: AppPalette.amberBright,
        onSecondary: Color(0xFF3A1A02),
        secondaryContainer: Color(0xFF5C3415),
        onSecondaryContainer: Color(0xFFFFD9B8),
        tertiary: Color(0xFF8FC1EE),
        onTertiary: Color(0xFF06243C),
        surface: AppPalette.forest,
        onSurface: Color(0xFFEDE7D5),
        surfaceContainerHighest: Color(0xFF2A382D),
        surfaceContainerHigh: Color(0xFF243027),
        surfaceContainer: Color(0xFF1E2A21),
        onSurfaceVariant: Color(0xFFBFC6B2),
        outline: Color(0xFF8A9382),
        outlineVariant: Color(0xFF424B3C),
        error: Color(0xFFFF6B5E),
        onError: Color(0xFF3A0905),
      );
    }
    return const ColorScheme.light(
      primary: AppPalette.leaf,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFCDEBA1),
      onPrimaryContainer: Color(0xFF18380A),
      secondary: AppPalette.amber,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFFFDDBE),
      onSecondaryContainer: Color(0xFF4A2407),
      tertiary: AppPalette.sky,
      onTertiary: Colors.white,
      surface: AppPalette.cream,
      onSurface: AppPalette.ink,
      surfaceContainerHighest: Color(0xFFEAE0C8),
      surfaceContainerHigh: Color(0xFFF0E7D2),
      surfaceContainer: Color(0xFFF5EEDC),
      onSurfaceVariant: Color(0xFF6E674F),
      outline: Color(0xFF938B70),
      outlineVariant: Color(0xFFDDD3B8),
      error: AppPalette.danger,
      onError: Colors.white,
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    // Nunito is the friendly, readable body face. Fredoka — chunky and rounded
    // — is layered on top for the big display/heading slots so titles read as a
    // game, not a settings app.
    final body = GoogleFonts.nunitoTextTheme().apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    fredoka(double size, FontWeight weight, {double spacing = 0}) =>
        GoogleFonts.fredoka(
          fontSize: size,
          fontWeight: weight,
          color: scheme.onSurface,
          letterSpacing: spacing,
          height: 1.05,
        );
    return body.copyWith(
      displayLarge: fredoka(57, FontWeight.w700, spacing: -1),
      displayMedium: fredoka(45, FontWeight.w700, spacing: -0.5),
      displaySmall: fredoka(36, FontWeight.w700),
      headlineLarge: fredoka(32, FontWeight.w600),
      headlineMedium: fredoka(28, FontWeight.w600),
      headlineSmall: fredoka(24, FontWeight.w600),
      titleLarge: fredoka(22, FontWeight.w600),
      titleMedium: body.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: body.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  static ThemeData build(Brightness brightness, ColorScheme? dynamicScheme) {
    // We intentionally commit to the brand palette rather than adopting the
    // device's dynamic color: a game wants a consistent identity. The
    // DynamicColorBuilder wiring is kept so we still pick up the platform's
    // text-scale / high-contrast behaviours, but the scheme is ours.
    final scheme = _scheme(brightness);
    final base = brightness == Brightness.dark
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
    final text = _textTheme(scheme);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: text,
      extensions: [
        brightness == Brightness.dark ? GamePalette.dark : GamePalette.light,
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fredoka(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.secondary,
          foregroundColor: scheme.onSecondary,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 17),
          textStyle: GoogleFonts.nunito(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: GoogleFonts.nunito(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w700,
        ),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        labelStyle: GoogleFonts.nunito(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
    );
  }
}

/// Wraps the app in `DynamicColorBuilder`-free brand theming. The builder
/// signature is kept so `main.dart` doesn't need to change shape.
class ThemeShell extends StatelessWidget {
  const ThemeShell({super.key, required this.builder});

  final Widget Function(BuildContext, ThemeData light, ThemeData dark) builder;

  @override
  Widget build(BuildContext context) {
    return builder(
      context,
      AppTheme.build(Brightness.light, null),
      AppTheme.build(Brightness.dark, null),
    );
  }
}
