import 'package:go_router/go_router.dart';

import '../state/session.dart';
import '../ui/screens/browse_screen.dart';
import '../ui/screens/game_screen.dart';
import '../ui/screens/home_screen.dart';
import '../ui/screens/host_lobby_screen.dart';
import '../ui/screens/join_screen.dart';
import '../ui/screens/result_screen.dart';
import '../ui/screens/store_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
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
  ],
);
