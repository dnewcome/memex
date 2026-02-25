import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'screens/home_screen.dart';
import 'screens/editor_screen.dart';
import 'screens/entity_screen.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MemexApp(),
    ),
  );
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/blocks/:id',
      builder: (context, state) =>
          EditorScreen(blockId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/entities',
      builder: (context, state) => const EntityListScreen(),
    ),
    GoRoute(
      path: '/entities/:id',
      builder: (context, state) =>
          EntityDetailScreen(entityId: state.pathParameters['id']!),
    ),
  ],
);

class MemexApp extends StatelessWidget {
  const MemexApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Memex',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: Color(0xFFE0E0E0)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: _router,
    );
  }
}
