import 'package:flutter/material.dart';

import '../presentation/plan_selection_screen.dart';

class AndroidBillingService {
  Future<void> startCheckout(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PlanSelectionScreen()),
    );
  }
}
