import 'dart:io';

import 'package:flutter/material.dart';

import '../../../ui/apple_paywall_screen.dart';
import 'premium_paywall_screen.dart';

class PaywallRouter extends StatelessWidget {
  const PaywallRouter({
    super.key,
    this.sourceScreen,
  });

  final String? sourceScreen;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return ApplePaywallScreen(sourceScreen: sourceScreen);
    }
    if (Platform.isAndroid) {
      return PremiumPaywallScreen(sourceScreen: sourceScreen);
    }
    return PremiumPaywallScreen(sourceScreen: sourceScreen);
  }
}
