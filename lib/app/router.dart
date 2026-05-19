import 'package:go_router/go_router.dart';

import '../ui/screens/browse_screen.dart';
import '../ui/screens/game_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/host_lobby_screen.dart';
import '../ui/screens/join_screen.dart';
import '../ui/screens/result_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/host', builder: (_, __) => const HostLobbyScreen()),
    GoRoute(path: '/browse', builder: (_, __) => const BrowseScreen()),
    GoRoute(path: '/join', builder: (_, state) {
      final url = state.uri.queryParameters['url'] ?? '';
      return JoinScreen(initialUrl: url);
    }),
    GoRoute(path: '/game', builder: (_, __) => const GameScreen()),
    GoRoute(path: '/result', builder: (_, __) => const ResultScreen()),
  ],
);
