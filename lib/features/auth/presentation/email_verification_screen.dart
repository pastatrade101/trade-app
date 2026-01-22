import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/utils/session_cleanup.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with WidgetsBindingObserver {
  Timer? _verificationTimer;
  bool _sending = false;
  bool _reloadInProgress = false;
  bool _refreshing = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reloadUser(showSpinner: false, showMessageOnError: false);
    _verificationTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _reloadUser(showSpinner: false, showMessageOnError: false),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _verificationTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadUser(showSpinner: false, showMessageOnError: false);
    }
  }

  Future<void> _sendVerification() async {
    setState(() {
      _sending = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendEmailVerification();
      setState(() {
        _message = 'Verification link sent. Check your inbox.';
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _reloadUser({
    bool showSpinner = true,
    bool showMessageOnError = true,
  }) async {
    if (_reloadInProgress) {
      return;
    }
    _reloadInProgress = true;
    if (showSpinner) {
      setState(() {
        _refreshing = true;
        _message = null;
      });
    }
    try {
      await ref.read(authRepositoryProvider).reloadCurrentUser();
    } catch (error) {
      if (showMessageOnError && mounted) {
        setState(() {
          _message = error.toString();
        });
      }
    } finally {
      _reloadInProgress = false;
      if (showSpinner && mounted) {
        setState(() => _refreshing = false);
      }
    }
    if (!mounted) {
      return;
    }
    final user = ref.read(authRepositoryProvider).currentUser;
    if (user != null && user.emailVerified) {
      _verificationTimer?.cancel();
      if (mounted) {
        setState(() {
          _message = 'Email verified. Signing you in...';
        });
      }
      ref.invalidate(authStateProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).value;
    final email = authUser?.email ?? 'your email';
    final tokens = AppThemeTokens.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await prepareForSignOut(ref);
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'We sent a verification link to $email. '
              'Click it to continue using the app.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 12),
            if (_message != null)
              Text(
                _message!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _sending ? null : _sendVerification,
              child: _sending
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Resend verification email'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _refreshing ? null : _reloadUser,
              child: _refreshing
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('I verified — continue'),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.warning.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.warning.withOpacity(0.4)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.report, color: tokens.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Didn't receive the email? "
                      'Please check your Spam or Promotions folder. '
                      "If you still don't see it, add support@trading.club to your contacts.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: tokens.mutedText,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
