import 'package:go_router/go_router.dart';

import '../analytics/analytics.dart';
import '../state/session.dart';
import '../ui/screens/about_screen.dart';
import '../ui/screens/achievements_screen.dart';
import '../ui/screens/browse_screen.dart';
import '../ui/screens/game_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/host_lobby_screen.dart';
import '../ui/screens/join_screen.dart';
import '../ui/screens/result_screen.dart';
import '../ui/screens/store_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  // Auto-logs screen_view on navigation when analytics is active; empty list
  // otherwise. appRouter is built lazily after Analytics.init() runs in main().
  observers: [
    if (Analytics.instance.navigatorObserver != null)
      Analytics.instance.navigatorObserver!,
  ],
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/host', builder: (_, state) {
      final mode = state.uri.queryParameters['mode'] == 'online'
          ? HostMode.online
          : HostMode.lan;
      return HostLobbyScreen(mode: mode);
    }),
    GoRoute(path: '/browse', builder: (_, __) => const BrowseScreen()),
    GoRoute(path: '/join', builder: (_, state) {
      final url = state.uri.queryParameters['url'];
      final code = state.uri.queryParameters['code'];
      return JoinScreen(lanUrl: url, roomCode: code);
    }),
    GoRoute(path: '/game', builder: (_, __) => const GameScreen()),
    GoRoute(path: '/result', builder: (_, __) => const ResultScreen()),
    GoRoute(path: '/store', builder: (_, __) => const StoreScreen()),
    GoRoute(
        path: '/achievements',
        builder: (_, __) => const AchievementsScreen()),
    GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
  ],
);
