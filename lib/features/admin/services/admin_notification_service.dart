import 'package:cloud_functions/cloud_functions.dart';

class AdminNotificationService {
  AdminNotificationService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  Future<void> testTrialNotification({
    required String memberName,
    int trialDays = 5,
    String? memberUid,
  }) async {
    await _functions.httpsCallable('testTrialNotification').call({
      'memberName': memberName,
      'trialDays': trialDays,
      if (memberUid != null) 'memberUid': memberUid,
    });
  }

  Future<void> testPurchaseNotification({
    required String memberName,
    String? memberUid,
  }) async {
    await _functions.httpsCallable('testPurchaseNotification').call({
      'memberName': memberName,
      if (memberUid != null) 'memberUid': memberUid,
    });
  }
}
