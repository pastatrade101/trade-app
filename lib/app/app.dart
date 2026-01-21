import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_theme.dart';
import 'providers.dart';
import 'navigation.dart';
import '../core/services/update_service.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../services/analytics_service.dart';

class TradingClubApp extends ConsumerStatefulWidget {
  const TradingClubApp({super.key});

  @override
  ConsumerState<TradingClubApp> createState() => _TradingClubAppState();
}

class _TradingClubAppState extends ConsumerState<TradingClubApp> {
  bool _checkedForUpdate = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkForUpdate();
      });
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checkedForUpdate) return;
    _checkedForUpdate = true;
    if (!kReleaseMode) {
      return;
    }
    try {
      await UpdateService.enforceMandatoryUpdate();
    } catch (error, stackTrace) {
      debugPrint('Update check failed: $error\n$stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final analyticsObserver = AnalyticsService.analyticsBuildEnabled
        ? AnalyticsService.instance.observer
        : null;

    return MaterialApp(
      title: 'MarketResolve TZ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      navigatorKey: rootNavigatorKey,
      navigatorObservers:
          analyticsObserver == null ? const [] : [analyticsObserver],
      home: const AuthGate(),
    );
  }
}
