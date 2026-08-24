import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ads.dart';
import 'analytics/analytics.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/prefs.dart';
import 'ui/widgets/achievement_overlay.dart';
import 'ui/widgets/ambient_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Every face the app uses is bundled under assets/google_fonts/, so no font
  // is ever fetched from fonts.gstatic.com at runtime. That request sent the
  // user's IP to a third party the privacy policy didn't mention, and it left
  // headings in a fallback face until it completed — or forever, offline.
  //
  // With fetching off, a weight that isn't bundled falls back to the system
  // font and logs "google_fonts was unable to load font <name>". Grep for that
  // after adding a new weight.
  GoogleFonts.config.allowRuntimeFetching = false;

  // Local disk read; the ProviderScope override below needs a resolved value.
  final prefs = await SharedPreferences.getInstance();

  // Awaited on purpose, unlike ads below. This is a platform-channel init with
  // no network round trip, and `appRouter` reads `navigatorObserver` once when
  // it's first built — if analytics weren't live by then, screen_view logging
  // would be silently off for the whole session.
  await Analytics.instance.init();

  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MinesweeperApp(),
  ));

  // Deliberately after runApp and deliberately not awaited. Ads.init gathers
  // UMP consent first, which is a network round trip that may then present a
  // full-screen form. Awaiting it here parked a cold start on the native
  // splash — on a slow connection, for seconds — and tried to show that form
  // before any Flutter UI existed to host it.
  //
  // Nothing needs to block on this: the facade swallows its own failures, and
  // widgets that create ads on mount await `Ads.instance.whenReady` so they
  // don't race the cold start.
  unawaited(Ads.instance.init());
}

class MinesweeperApp extends StatelessWidget {
  const MinesweeperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemeShell(
      builder: (context, light, dark) => MaterialApp.router(
        debugShowCheckedModeBanner: false,
        title: 'Minesweeper Co-op',
        theme: light,
        darkTheme: dark,
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
        // Show a scrollbar on every platform (Flutter hides it on mobile by
        // default) so when a screen does have to scroll, it never looks like
        // the UI was silently cut off.
        scrollBehavior: const _AppScrollBehavior(),
        // Every route's scaffold is transparent (see AppTheme) and floats on a
        // single shared solid backdrop. The AchievementOverlay sits above every
        // route as one persistent toast host, so an unlock toast triggered on
        // the game screen survives the auto-navigation to /result.
        builder: (context, child) => AmbientBackground(
          child: Stack(
            children: [
              child ?? const SizedBox.shrink(),
              const AchievementOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Keeps scrollbars visible on touch platforms too (not just desktop), so an
/// overflowing screen always advertises that there's more below.
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return Scrollbar(controller: details.controller, child: child);
  }
}
