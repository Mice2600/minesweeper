import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  runApp(const ProviderScope(child: MinesweeperApp()));
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
      ),
    );
  }
}
