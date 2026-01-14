import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'providers.dart';
import 'navigation.dart';
import '../features/auth/presentation/auth_gate.dart';

class TradingClubApp extends ConsumerWidget {
  const TradingClubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'MarketResolve',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      navigatorKey: rootNavigatorKey,
      home: const AuthGate(),
    );
  }
}
