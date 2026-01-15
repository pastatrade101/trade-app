import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/widgets/app_toast.dart';
import '../../auth/presentation/auth_screen.dart';
import '../../home/presentation/home_shell.dart';
import '../../premium/presentation/payment_method_screen.dart';
import 'onboarding_widgets.dart';

const _planFree = 'free';
const _planDaily = 'premium_daily';
const _planMonthly = 'premium_monthly';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late int _step;
  bool _saving = false;
  String? _selectedPlanId;
  String? _selectedProvider;
  bool _notifSignals = true;
  bool _notifAnnouncements = true;

  @override
  void initState() {
    super.initState();
    _step = _normalizeStep(widget.user.onboardingStep);
    _notifSignals = widget.user.notifyNewSignals ?? true;
    _notifAnnouncements = widget.user.notifAnnouncements ?? true;
  }

  int _normalizeStep(int? step) {
    if (step == null || step < 0 || step > 6) {
      return 0;
    }
    return step;
  }

  Future<void> _writeUser(Map<String, dynamic> data) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).setUserFields(
            widget.user.uid,
            data,
          );
    } catch (error) {
      if (mounted) {
        AppToast.error(context, 'Could not save. You can continue.');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _goToStep(int step) async {
    await _writeUser({'onboardingStep': step});
    if (!mounted) {
      return;
    }
    setState(() => _step = step);
  }

  Future<void> _finishOnboarding() async {
    final membershipTier = widget.user.membership?.tier ?? _planFree;
    await _writeUser({
      'onboardingCompleted': true,
      'onboardingStep': 0,
      'notifSignals': _notifSignals,
      'notifyNewSignals': _notifSignals,
      'notifAnnouncements': _notifAnnouncements,
      'membershipTier': membershipTier,
    });
    if (!mounted) {
      return;
    }
    if (_selectedPlanId == _planDaily || _selectedPlanId == _planMonthly) {
      await _startPaymentFlow();
      return;
    }
    _goHome();
  }

  Future<void> _startPaymentFlow() async {
    final planId = _selectedPlanId;
    if (planId == null) {
      _goHome();
      return;
    }
    final product =
        await ref.read(productRepositoryProvider).fetchProduct(planId);
    if (!mounted) {
      return;
    }
    if (product == null || !product.isActive) {
      AppToast.error(context, 'Selected plan is not available right now.');
      _goHome();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PaymentMethodScreen(
          product: product,
          initialProvider: _selectedProvider,
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeShell()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _buildStep(),
    );
  }

  Widget _buildStep() {
    final isSignedIn = FirebaseAuth.instance.currentUser != null;
    switch (_step) {
      case 0:
        return BrandSplashScreen(
          key: const ValueKey('onboarding-step-0'),
          onContinue: () => _goToStep(1),
        );
      case 1:
        return WelcomeScreen(
          key: const ValueKey('onboarding-step-1'),
          loading: _saving,
          showAuthAction: !isSignedIn,
          onContinue: () => _goToStep(2),
          onSignIn: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
          },
        );
      case 2:
        return HowItWorksScreen(
          key: const ValueKey('onboarding-step-2'),
          loading: _saving,
          onContinue: () => _goToStep(3),
          onSkip: () => _goToStep(3),
        );
      case 3:
        return PlanSelectionScreen(
          key: const ValueKey('onboarding-step-3'),
          onSelectPlan: (planId) {
            setState(() => _selectedPlanId = planId);
            if (planId == _planFree) {
              _goToStep(5);
            } else {
              _goToStep(4);
            }
          },
        );
      case 4:
        return PaymentMethodSelectionScreen(
          key: const ValueKey('onboarding-step-4'),
          loading: _saving,
          initialProvider: _selectedProvider,
          onContinue: (provider) {
            setState(() => _selectedProvider = provider);
            _goToStep(5);
          },
          onBack: () => _goToStep(3),
        );
      case 5:
        return NotificationOptInScreen(
          key: const ValueKey('onboarding-step-5'),
          loading: _saving,
          notifSignals: _notifSignals,
          notifAnnouncements: _notifAnnouncements,
          onToggleSignals: (value) => setState(() => _notifSignals = value),
          onToggleAnnouncements: (value) =>
              setState(() => _notifAnnouncements = value),
          onContinue: () => _goToStep(6),
          onSkip: () => _goToStep(6),
        );
      case 6:
      default:
        return FinishScreen(
          key: const ValueKey('onboarding-step-6'),
          loading: _saving,
          onFinish: _finishOnboarding,
        );
    }
  }
}

class BrandSplashScreen extends StatelessWidget {
  const BrandSplashScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text(
                'Mchambuzi Kai',
                style: textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Official Trading App',
                style: textTheme.titleMedium?.copyWith(
                  color: tokens.mutedText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'powered by MarketResolve',
                style: textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                ),
              ),
              const Spacer(),
              Text(
                'Tanzania-focused signals for Gold & Forex',
                style: textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onContinue,
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.loading,
    required this.showAuthAction,
    required this.onContinue,
    required this.onSignIn,
  });

  final bool loading;
  final bool showAuthAction;
  final VoidCallback onContinue;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OnboardingScaffold(
      step: 1,
      totalSteps: 6,
      title: 'Trade with clarity.',
      subtitle:
          'Get structured trading signals built around London, New York, and Asia sessions - designed for Tanzanian traders.',
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _OnboardingBullet(
                icon: Icons.schedule,
                color: colorScheme.primary,
                text: 'Session-based signals with clear time windows',
              ),
              const SizedBox(height: 12),
              _OnboardingBullet(
                icon: Icons.lock_outline,
                color: colorScheme.secondary,
                text: 'Premium unlocks full signal details',
              ),
              const SizedBox(height: 12),
              _OnboardingBullet(
                icon: Icons.history_toggle_off,
                color: colorScheme.tertiary,
                text: 'Transparent history and results',
              ),
            ],
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: loading ? null : onContinue,
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ),
        if (showAuthAction)
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: loading ? null : onSignIn,
              child: const Text('Sign in / Create account'),
            ),
          ),
      ],
    );
  }
}

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({
    super.key,
    required this.loading,
    required this.onContinue,
    required this.onSkip,
  });

  final bool loading;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 2,
      totalSteps: 6,
      title: 'How it works',
      subtitle: 'Quick, focused guidance for every trading session.',
      body: Column(
        children: const [
          _HowCard(
            title: 'Session Signals',
            text: 'Signals are posted for a specific session and expire automatically.',
          ),
          SizedBox(height: 12),
          _HowCard(
            title: 'Premium Access',
            text:
                'Free users see previews. Premium members unlock full entries, SL/TP, and risk notes.',
          ),
          SizedBox(height: 12),
          _HowCard(
            title: 'Trusted & Simple',
            text:
                'This app is curated - no rankings, no noise. Just clear signals and guidance.',
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: loading ? null : onContinue,
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: loading ? null : onSkip,
            child: const Text('Skip'),
          ),
        ),
      ],
    );
  }
}

class PlanSelectionScreen extends StatelessWidget {
  const PlanSelectionScreen({
    super.key,
    required this.onSelectPlan,
  });

  final void Function(String planId) onSelectPlan;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 3,
      totalSteps: 6,
      title: 'Choose your access',
      subtitle: 'Start free, upgrade anytime.',
      body: Column(
        children: [
          _PlanCard(
            tag: 'Free',
            title: 'Free Preview',
            benefits: const [
              'See signal previews (pair + session)',
              'View announcements and daily highlight (preview)',
              'Browse testimonials',
            ],
            buttonLabel: 'Continue with Free',
            onPressed: () => onSelectPlan(_planFree),
          ),
        ],
      ),
      actions: const [],
    );
  }
}

class PaymentMethodSelectionScreen extends StatefulWidget {
  const PaymentMethodSelectionScreen({
    super.key,
    required this.loading,
    required this.initialProvider,
    required this.onContinue,
    required this.onBack,
  });

  final bool loading;
  final String? initialProvider;
  final void Function(String provider) onContinue;
  final VoidCallback onBack;

  @override
  State<PaymentMethodSelectionScreen> createState() =>
      _PaymentMethodSelectionScreenState();
}

class _PaymentMethodSelectionScreenState
    extends State<PaymentMethodSelectionScreen> {
  late String _provider;

  @override
  void initState() {
    super.initState();
    _provider = widget.initialProvider ?? _paymentOptions.first.provider;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return OnboardingScaffold(
      step: 4,
      totalSteps: 6,
      title: 'Choose payment method',
      subtitle: 'Complete your upgrade with mobile money.',
      body: Column(
        children: _paymentOptions
            .map(
              (option) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: RadioListTile<String>(
                  value: option.provider,
                  groupValue: _provider,
                  onChanged: widget.loading
                      ? null
                      : (value) => setState(
                            () => _provider = value ?? _provider,
                          ),
                  secondary: _BrandBadge(color: option.color, icon: option.icon),
                  title: Text(option.label),
                  subtitle: Text(
                    option.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: tokens.mutedText,
                        ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.loading
                ? null
                : () => widget.onContinue(_provider),
            child: widget.loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Continue to pay'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: widget.loading ? null : widget.onBack,
            child: const Text('Back'),
          ),
        ),
      ],
    );
  }
}

class NotificationOptInScreen extends StatelessWidget {
  const NotificationOptInScreen({
    super.key,
    required this.loading,
    required this.notifSignals,
    required this.notifAnnouncements,
    required this.onToggleSignals,
    required this.onToggleAnnouncements,
    required this.onContinue,
    required this.onSkip,
  });

  final bool loading;
  final bool notifSignals;
  final bool notifAnnouncements;
  final ValueChanged<bool> onToggleSignals;
  final ValueChanged<bool> onToggleAnnouncements;
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 5,
      totalSteps: 6,
      title: 'Never miss a signal',
      subtitle:
          'Enable alerts so you get notified when a new premium signal or announcement is posted.',
      body: Column(
        children: [
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: notifSignals,
                  onChanged: loading ? null : onToggleSignals,
                  title: const Text('Signal alerts'),
                  subtitle: const Text('Premium and session updates'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: notifAnnouncements,
                  onChanged: loading ? null : onToggleAnnouncements,
                  title: const Text('Announcements'),
                  subtitle: const Text('Daily highlight and updates'),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: loading ? null : onContinue,
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enable notifications'),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: loading ? null : onSkip,
            child: const Text('Maybe later'),
          ),
        ),
      ],
    );
  }
}

class FinishScreen extends StatelessWidget {
  const FinishScreen({
    super.key,
    required this.loading,
    required this.onFinish,
  });

  final bool loading;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return OnboardingScaffold(
      step: 6,
      totalSteps: 6,
      title: "You're ready.",
      subtitle:
          "Go to Signals to view today's sessions. Premium members unlock full details instantly.",
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Trade around London, New York, and Asia sessions with clear timing and guidance.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: tokens.mutedText),
          ),
        ),
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: loading ? null : onFinish,
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Go to Signals'),
          ),
        ),
      ],
    );
  }
}

class _OnboardingBullet extends StatelessWidget {
  const _OnboardingBullet({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _HowCard extends StatelessWidget {
  const _HowCard({
    required this.title,
    required this.text,
  });

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: tokens.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.tag,
    required this.title,
    required this.benefits,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String tag;
  final String title;
  final List<String> benefits;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Text(
                    tag,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...benefits.map(
              (benefit) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 18, color: tokens.success),
                    const SizedBox(width: 8),
                    Expanded(child: Text(benefit)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentOption {
  const _PaymentOption({
    required this.provider,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.icon,
  });

  final String provider;
  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
}

const _paymentOptions = [
  _PaymentOption(
    provider: 'vodacom',
    label: 'M-Pesa (Vodacom)',
    subtitle: 'Approve the M-Pesa prompt on your phone',
    color: Color(0xFFE60000),
    icon: Icons.phone_android,
  ),
  _PaymentOption(
    provider: 'airtel',
    label: 'Airtel Money',
    subtitle: 'Approve the Airtel Money request',
    color: Color(0xFF2563EB),
    icon: Icons.phone_android,
  ),
  _PaymentOption(
    provider: 'mixx',
    label: 'Mixx by Yas',
    subtitle: 'USSD/push prompt on your Mixx wallet',
    color: Color(0xFFFFD100),
    icon: Icons.phone_android,
  ),
  _PaymentOption(
    provider: 'tigo',
    label: 'Tigo Pesa',
    subtitle: 'Authorize on your TigoPesa wallet',
    color: Color(0xFF0033A0),
    icon: Icons.phone_android,
  ),
  _PaymentOption(
    provider: 'halopesa',
    label: 'HaloPesa',
    subtitle: 'Approve the HaloPesa request',
    color: Color(0xFF00A651),
    icon: Icons.phone_android,
  ),
];

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final brightness = ThemeData.estimateBrightnessForColor(color);
    final iconColor = brightness == Brightness.dark ? Colors.white : Colors.black;
    return CircleAvatar(
      radius: 20,
      backgroundColor: color,
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}
