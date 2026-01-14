import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/widgets/app_toast.dart';
import '../../home/presentation/home_shell.dart';
import 'onboarding_widgets.dart';

class OnboardingFlow extends ConsumerStatefulWidget {
  const OnboardingFlow({super.key, required this.user});

  final AppUser user;

  @override
  ConsumerState<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends ConsumerState<OnboardingFlow> {
  late int _step;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _step = _normalizeStep(widget.user.onboardingStep);
  }

  int _normalizeStep(int? step) {
    if (step == null || step < 1 || step > 3) {
      return 1;
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

  Future<void> _skipToHome() async {
    await _writeUser({
      'onboardingCompleted': true,
      'onboardingStep': 0,
    });
    if (!mounted) {
      return;
    }
    _goHome();
  }

  Future<void> _finishOnboarding() async {
    await _writeUser({
      'onboardingCompleted': true,
      'onboardingStep': 0,
    });
    if (!mounted) {
      return;
    }
    _goHome();
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
    switch (_step) {
      case 2:
        return PersonalizationScreen(
          key: const ValueKey('onboarding-step-2'),
          loading: _saving,
          initialDisplayName: widget.user.displayName,
          onContinue: (displayName, interests) async {
            final trimmed = displayName.trim();
            final data = <String, dynamic>{'onboardingStep': 3};
            if (trimmed.isNotEmpty) {
              data['displayName'] = trimmed;
            }
            if (interests.isNotEmpty) {
              data['interests'] = interests;
            }
            await _writeUser(data);
            if (!mounted) {
              return;
            }
            setState(() => _step = 3);
          },
          onSkip: () => _goToStep(3),
        );
      case 3:
        return RolesInfoScreen(
          key: const ValueKey('onboarding-step-3'),
          loading: _saving,
          onFinish: _finishOnboarding,
          onSkip: _finishOnboarding,
        );
      case 1:
      default:
        return WelcomeScreen(
          key: const ValueKey('onboarding-step-1'),
          loading: _saving,
          onContinue: () => _goToStep(2),
          onSkip: _skipToHome,
        );
    }
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
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
    final colorScheme = Theme.of(context).colorScheme;
    return OnboardingScaffold(
      step: 1,
      title: 'Welcome',
      subtitle: 'Track signals, learn from tips, and review outcomes.',
      body: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _OnboardingBullet(
                icon: Icons.track_changes,
                color: colorScheme.primary,
                text: 'Track live signals without the pressure.',
              ),
              const SizedBox(height: 12),
              _OnboardingBullet(
                icon: Icons.timeline,
                color: colorScheme.secondary,
                text: 'Outcome updates appear after each trade closes.',
              ),
              const SizedBox(height: 12),
              _OnboardingBullet(
                icon: Icons.bookmark_border,
                color: colorScheme.tertiary,
                text: 'Save tips and revisit your favorite signals.',
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

class PersonalizationScreen extends StatefulWidget {
  const PersonalizationScreen({
    super.key,
    required this.loading,
    required this.initialDisplayName,
    required this.onContinue,
    required this.onSkip,
  });

  final bool loading;
  final String initialDisplayName;
  final void Function(String displayName, List<String> interests) onContinue;
  final VoidCallback onSkip;

  @override
  State<PersonalizationScreen> createState() => _PersonalizationScreenState();
}

class _PersonalizationScreenState extends State<PersonalizationScreen> {
  late final TextEditingController _displayNameController;
  late final List<String> _selectedInterests;
  static const _interestOptions = [
    'XAUUSD',
    'Forex',
    'Crypto',
    'Indices',
  ];

  @override
  void initState() {
    super.initState();
    final authName = FirebaseAuth.instance.currentUser?.displayName ?? '';
    final initialName = widget.initialDisplayName.isNotEmpty
        ? widget.initialDisplayName
        : authName;
    _displayNameController = TextEditingController(text: initialName);
    _selectedInterests = <String>[];
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  void _toggleInterest(String interest) {
    if (_selectedInterests.contains(interest)) {
      setState(() => _selectedInterests.remove(interest));
      return;
    }
    if (_selectedInterests.length >= 3) {
      AppToast.info(context, 'Pick up to 3 interests.');
      return;
    }
    setState(() => _selectedInterests.add(interest));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.loading;
    return OnboardingScaffold(
      step: 2,
      title: 'Personalize',
      subtitle: 'Optional details to make your feed feel relevant.',
      body: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Display name'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      hintText: 'How should we call you?',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Interests'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interestOptions.map((interest) {
                      final selected = _selectedInterests.contains(interest);
                      return FilterChip(
                        label: Text(interest),
                        selected: selected,
                        onSelected: isLoading
                            ? null
                            : (_) => _toggleInterest(interest),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick up to 3.',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading
                ? null
                : () => widget.onContinue(
                      _displayNameController.text,
                      List<String>.from(_selectedInterests),
                    ),
            child: isLoading
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
            onPressed: isLoading ? null : widget.onSkip,
            child: const Text('Skip'),
          ),
        ),
      ],
    );
  }
}

class RolesInfoScreen extends StatelessWidget {
  const RolesInfoScreen({
    super.key,
    required this.loading,
    required this.onFinish,
    required this.onSkip,
  });

  final bool loading;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      step: 3,
      title: 'How it works',
      subtitle: 'Trading access is managed by admins. Start as a member.',
      body: Column(
        children: const [
          _RoleInfoCard(
            title: 'Member',
            items: [
              'Save tips and keep track of signals.',
              'Review outcomes after trades close.',
            ],
            icon: Icons.people_outline,
          ),
        ],
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
                : const Text('Start as Member'),
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

class _RoleInfoCard extends StatelessWidget {
  const _RoleInfoCard({
    required this.title,
    required this.items,
    required this.icon,
  });

  final String title;
  final List<String> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.check, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
