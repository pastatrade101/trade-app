import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/stats_summary.dart';
import '../../../core/models/validator_stats.dart';
import '../../../core/utils/validators.dart';
import '../../home/presentation/home_shell.dart';

class MemberOnboardingScreen extends ConsumerStatefulWidget {
  const MemberOnboardingScreen({super.key, required this.uid});

  final String uid;

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
    try {
      await userRepo.claimUsername(usernameLower, widget.uid);
      final profile = AppUser(
        uid: widget.uid,
        displayName: displayName,
        username: username,
        usernameLower: usernameLower,
        avatarUrl: '',
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
    return Scaffold(
      appBar: AppBar(title: const Text('Member onboarding')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _displayNameController,
                decoration: const InputDecoration(labelText: 'Display name'),
                validator: (value) => validateRequired(value, 'Display name'),
              ),
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(labelText: 'Username'),
                validator: validateUsername,
              ),
              TextFormField(
                controller: _countryController,
                decoration:
                    const InputDecoration(labelText: 'Country (optional)'),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Finish'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
