import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/stats_summary.dart';
import '../../../core/models/validator_stats.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../home/presentation/home_shell.dart';

class MemberOnboardingScreen extends ConsumerStatefulWidget {
  const MemberOnboardingScreen({
    super.key,
    required this.uid,
    this.lockToComplete = false,
  });

  final String uid;
  final bool lockToComplete;

  @override
  ConsumerState<MemberOnboardingScreen> createState() =>
      _MemberOnboardingScreenState();
}

class _MemberOnboardingScreenState
    extends ConsumerState<MemberOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _countryController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final userRepo = ref.read(userRepositoryProvider);
    await userRepo.ensureUserDoc(widget.uid);
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    final country = _countryController.text.trim();
    final usernameLower = username.toLowerCase();
    final email = ref.read(authStateProvider).valueOrNull?.email ??
        FirebaseAuth.instance.currentUser?.email ??
        '';
    try {
      await userRepo.claimUsername(usernameLower, widget.uid);
      final profile = AppUser(
        uid: widget.uid,
        displayName: displayName,
        username: username,
        usernameLower: usernameLower,
        avatarUrl: '',
        email: email,
        bio: '',
        country: country,
        sessions: const [],
        instruments: const [],
        strategyStyle: '',
        experienceLevel: '',
        role: 'member',
        traderStatus: 'none',
        rejectReason: null,
        socials: const {},
        socialLinks: const {},
        yearsExperience: null,
        isVerified: false,
        verifiedAt: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        statsSummary: StatsSummary.empty(),
        validatorStats: ValidatorStats.empty(),
        followerCount: 0,
        followingCount: 0,
        isBanned: false,
      );
      await userRepo.saveUserProfile(profile);
      if (mounted) {
        if (widget.lockToComplete) {
          Navigator.of(context).pop();
          return;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeShell()),
          (_) => false,
        );
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.lockToComplete,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete your profile'),
          automaticallyImplyLeading: !widget.lockToComplete,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: [
              Text(
                'Let\'s set up your profile',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add a name and username so your signals and subscriptions '
                'stay tied to the right account.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppThemeTokens.of(context).mutedText,
                    ),
              ),
              const SizedBox(height: 16),
              AppSectionCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Profile details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _displayNameController,
                        decoration:
                            const InputDecoration(labelText: 'Display name'),
                        validator: (value) =>
                            validateRequired(value, 'Display name'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(labelText: 'Username'),
                        validator: validateUsername,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'Country (optional)',
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null)
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const CircularProgressIndicator()
                              : const Text('Finish setup'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
