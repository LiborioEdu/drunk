import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/route_finder/presentation/screens/route_finder_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: DrunkApp(),
    ),
  );
}

class DrunkApp extends StatelessWidget {
  const DrunkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DRUNK - 10km Pub Crawl',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const RouteFinderScreen(),
    );
  }
}
