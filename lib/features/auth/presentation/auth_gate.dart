import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../admin/presentation/admin_shell.dart';
import '../../home/presentation/home_shell.dart';
import '../../onboarding/presentation/onboarding_router.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../app/app_theme.dart';
import '../../../screens/terms_screen.dart';
import '../../../services/terms_service.dart';
import '../../../services/analytics_service.dart';
import 'auth_screen.dart';
import 'email_verification_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);

    ref.listen(authStateProvider, (previous, next) {
      final user = next.value;
      final previousUid = previous?.value?.uid;
      if (user != null) {
        final firebaseUser = FirebaseAuth.instance.currentUser;
        if (firebaseUser != null) {
          unawaited(
            ref
                .read(notificationServiceProvider)
                .initForUser(firebaseUser.uid),
          );
        }
        unawaited(ref.read(userRepositoryProvider).ensureUserDoc(user.uid));
        unawaited(AnalyticsService.instance.setUserId(user.uid));
        if (previousUid != user.uid) {
          final membershipService = ref.read(membershipServiceProvider);
          final membershipStream =
              membershipService.watchMembership(user.uid);
          ref.read(notificationServiceProvider).startPremiumSessionsTopicSync(
                uid: user.uid,
                membershipStream: membershipStream,
                membershipService: membershipService,
              );
        }
      } else if (previousUid != null) {
        unawaited(
          ref
              .read(notificationServiceProvider)
              .resetUserSession(uid: previousUid),
        );
        unawaited(AnalyticsService.instance.setUserId(null));
      }
    });
    ref.listen(currentUserProvider, (previous, next) {
      final profile = next.value;
      if (profile == null) {
        return;
      }
      final prevProfile = previous?.value;
      if (prevProfile != null &&
          prevProfile.uid == profile.uid &&
          prevProfile.notifyNewSignals == profile.notifyNewSignals &&
          prevProfile.notifAnnouncements == profile.notifAnnouncements &&
          prevProfile.role == profile.role) {
        return;
      }
      unawaited(_syncNotificationTopics(ref, profile));
      unawaited(_syncSignalTopics(ref, traders: null));
      unawaited(_syncAnalyticsUser(ref, profile));
    });
    ref.listen(userMembershipProvider, (previous, next) {
      unawaited(_syncSignalTopics(ref, traders: null));
      final profile = ref.read(currentUserProvider).value;
      if (profile != null) {
        unawaited(_syncAnalyticsUser(ref, profile));
      }
    });
    ref.listen(supportTradersProvider, (previous, next) {
      unawaited(_syncSignalTopics(ref, traders: next.value));
    });

    return authState.when(
      data: (user) {
        if (user == null) {
          return const AuthScreen();
        }
        if (!user.emailVerified) {
          return const EmailVerificationScreen();
        }
        final profileState = ref.watch(currentUserProvider);
        return profileState.when(
          data: (profile) {
            if (profile == null) {
              return const _LoadingScreen();
            }
            if (!_hasAcceptedTerms(profile)) {
              return const TermsScreen();
            }
            if (profile.role == 'admin') {
              return const AdminShell();
            }
            return OnboardingRouter(user: profile);
          },
          loading: () {
            final firebaseUser = FirebaseAuth.instance.currentUser;
            return firebaseUser == null
                ? const AuthScreen()
                : const _LoadingScreen();
          },
          error: (error, _) => _ProfileFallbackHome(
            uid: user.uid,
            message: 'Unable to load your profile. Continuing to home.',
          ),
        );
      },
      loading: () {
        return const _LoadingScreen();
      },
      error: (error, _) => _ErrorScreen(message: error.toString()),
    );
  }
}

Future<void> _syncNotificationTopics(WidgetRef ref, AppUser profile) async {
  final notifySignals =
      profile.notifyNewSignals ?? profile.notifSignals ?? true;
  final notifyAnnouncements = profile.notifAnnouncements ?? true;
  if (!notifySignals && !notifyAnnouncements) {
    return;
  }
  await ref.read(notificationServiceProvider).ensurePermission();
}

Future<void> _syncSignalTopics(
  WidgetRef ref, {
  List<AppUser>? traders,
}) async {
  final profile = ref.read(currentUserProvider).value;
  if (profile == null) {
    return;
  }
  final notifySignals =
      profile.notifyNewSignals ?? profile.notifSignals ?? true;
  final traderList =
      traders ?? ref.read(supportTradersProvider).value ?? const <AppUser>[];
  final traderUids = traderList
      .map((trader) => trader.uid)
      .where((uid) => uid.isNotEmpty)
      .toList();
  if (traderUids.isEmpty) {
    return;
  }
  final enabled = notifySignals;
  if (enabled) {
    await ref.read(notificationServiceProvider).ensurePermission();
  }
  await ref.read(notificationServiceProvider).syncTraderTopics(
        traderUids: traderUids,
        enabled: enabled,
      );
}

Future<void> _syncAnalyticsUser(WidgetRef ref, AppUser profile) async {
  final membership = ref.read(userMembershipProvider).value;
  final membershipService = ref.read(membershipServiceProvider);
  final isPremium = membershipService.isPremiumActive(membership);
  await AnalyticsService.instance.setUserId(profile.uid);
  await AnalyticsService.instance.setUserProperty('role', profile.role);
  await AnalyticsService.instance
      .setUserProperty('membership', isPremium ? 'premium' : 'free');
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Soko Gliant',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Signals that don't escape accountability.",
                style: textTheme.bodyMedium?.copyWith(
                  color: tokens.mutedText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  const _ErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(message, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _ProfileFallbackHome extends StatefulWidget {
  const _ProfileFallbackHome({
    required this.uid,
    required this.message,
  });

  final String uid;
  final String message;

  @override
  State<_ProfileFallbackHome> createState() => _ProfileFallbackHomeState();
}

class _ProfileFallbackHomeState extends State<_ProfileFallbackHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      AppToast.info(context, widget.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    return HomeShell(user: AppUser.placeholder(widget.uid));
  }
}

bool _hasAcceptedTerms(AppUser profile) {
  return profile.termsAccepted == true &&
      profile.termsVersion == TermsService.termsVersion;
}
