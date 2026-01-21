import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

Future<void> prepareForSignOut(WidgetRef ref) async {
  final uid = ref.read(authStateProvider).value?.uid;
  try {
    await ref
        .read(notificationServiceProvider)
        .resetUserSession(uid: uid);
  } catch (error, stackTrace) {
    if (kDebugMode) {
      debugPrint('prepareForSignOut: resetUserSession failed: $error');
      debugPrint('$stackTrace');
    }
  }
  ref.invalidate(currentUserProvider);
  ref.invalidate(userMembershipProvider);
  ref.invalidate(supportTradersProvider);
  ref.invalidate(tradingSessionConfigProvider);
  ref.invalidate(isPremiumActiveProvider);
}
