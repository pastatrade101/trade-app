import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../models/app_user.dart';
import '../widgets/app_toast.dart';

class NudgeHelper {
  static Future<void> showOnce({
    required BuildContext context,
    required WidgetRef ref,
    required AppUser user,
    required String key,
    required String message,
  }) async {
    if (user.nudgeFlags?[key] == true) {
      return;
    }
    AppToast.info(context, message);
    try {
      await ref.read(userRepositoryProvider).setUserFields(
            user.uid,
            {'nudgeFlags.$key': true},
          );
    } catch (_) {}
  }
}
