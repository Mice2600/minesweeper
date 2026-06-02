import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/ads.dart';
import 'analytics/analytics.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'core/prefs.dart';
import 'ui/widgets/ambient_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // Starts Firebase Analytics if configured; a no-op otherwise. Never throws.
  await Analytics.instance.init();
  // Initializes AdMob (consent + SDK) on Android; a no-op elsewhere. Never throws.
  await Ads.instance.init();
  runApp(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MinesweeperApp(),
  ));
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
        // single shared solid backdrop.
        builder: (context, child) => AmbientBackground(
          child: child ?? const SizedBox.shrink(),
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
