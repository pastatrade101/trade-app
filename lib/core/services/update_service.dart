import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

class UpdateService {
  UpdateService._();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Checks for an available Android update and applies it immediately if
  /// possible; falls back to a flexible update if allowed and requested.
  /// Returns true if an update was started, false if the app is up to date.
  static Future<bool> enforceMandatoryUpdate({
    bool flexibleFallback = true,
  }) async {
    if (!_isAndroid) return false;

    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable &&
        info.updateAvailability !=
            UpdateAvailability.developerTriggeredUpdateInProgress) {
      return false;
    }

    if (info.immediateUpdateAllowed) {
      await InAppUpdate.performImmediateUpdate();
      return true;
    }

    if (flexibleFallback && info.flexibleUpdateAllowed) {
      await InAppUpdate.startFlexibleUpdate();
      await InAppUpdate.completeFlexibleUpdate();
      return true;
    }

    // No supported update flow is available even though an update exists.
    return false;
  }
}
