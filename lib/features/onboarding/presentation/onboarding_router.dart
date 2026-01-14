import 'package:flutter/material.dart';

import '../../../core/models/app_user.dart';
import '../../home/presentation/home_shell.dart';
import 'onboarding_flow.dart';

class OnboardingRouter extends StatelessWidget {
  const OnboardingRouter({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    if (user.onboardingCompleted == true) {
      return HomeShell(user: user);
    }
    return OnboardingFlow(user: user);
  }
}
