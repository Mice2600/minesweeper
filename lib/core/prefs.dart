import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app-wide [SharedPreferences] instance. It is async to obtain, so it is
/// resolved once in `main()` and injected via a `ProviderScope` override:
///
/// ```dart
/// final prefs = await SharedPreferences.getInstance();
/// runApp(ProviderScope(
///   overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
///   child: const MinesweeperApp(),
/// ));
/// ```
///
/// Reading it without that override throws — by design, so a missing bootstrap
/// fails loudly instead of silently losing persisted data.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider must be overridden in main() with the resolved '
    'SharedPreferences instance.',
  ),
);
