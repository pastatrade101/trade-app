import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/stats_summary.dart';
import '../../../core/models/validator_stats.dart';
import '../../../core/utils/validators.dart';
import '../../home/presentation/home_shell.dart';

class TraderApplicationScreen extends ConsumerStatefulWidget {
  const TraderApplicationScreen({
    super.key,
    required this.uid,
    this.initialProfile,
  });

  final String uid;
  final AppUser? initialProfile;

  @override
  ConsumerState<TraderApplicationScreen> createState() =>
      _TraderApplicationScreenState();
}

class _TraderApplicationScreenState
    extends ConsumerState<TraderApplicationScreen> {
  static const sessions = ['Asia', 'London', 'NewYork'];
  static const instruments = ['XAUUSD', 'EURUSD', 'GBPUSD', 'USDJPY', 'BTCUSD'];
  static const strategyStyles = ['Scalper', 'Swing', 'Intraday'];
  static const experienceLevels = ['Beginner', 'Intermediate', 'Pro'];

  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _countryController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _telegramController = TextEditingController();
  final _yearsController = TextEditingController();
  String? _strategyStyle;
  String? _experienceLevel;
  final _selectedSessions = <String>{};
  final _selectedInstruments = <String>{};
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile != null) {
      _displayNameController.text = profile.displayName;
      _usernameController.text = profile.username;
      _countryController.text = profile.country;
      _bioController.text = profile.bio;
      _selectedSessions.addAll(profile.sessions);
      _selectedInstruments.addAll(profile.instruments);
      _strategyStyle =
          profile.strategyStyle.isNotEmpty ? profile.strategyStyle : null;
      _experienceLevel =
          profile.experienceLevel.isNotEmpty ? profile.experienceLevel : null;
      if (profile.yearsExperience != null) {
        _yearsController.text = profile.yearsExperience.toString();
      }
    }
    ref.read(userRepositoryProvider).fetchPrivatePhoneNumber(widget.uid).then(
      (phone) {
        if (mounted && phone != null) {
          _phoneController.text = phone;
        }
      },
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _countryController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _telegramController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSessions.isEmpty) {
      setState(() {
        _error = 'Select at least one session';
      });
      return;
    }
    if (_selectedInstruments.isEmpty) {
      setState(() {
        _error = 'Select at least one instrument';
      });
      return;
    }
    if (_strategyStyle == null || _experienceLevel == null) {
      setState(() {
        _error = 'Select strategy style and experience level';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final userRepo = ref.read(userRepositoryProvider);
    await userRepo.ensureUserDoc(widget.uid);
    final username = _usernameController.text.trim();
    final usernameLower = username.toLowerCase();
    final displayName = _displayNameController.text.trim();
    final country = _countryController.text.trim();
    final bio = _bioController.text.trim();
    final phone = _phoneController.text.trim();
    final oauthSocials = <String, String>{};
    if (_whatsappController.text.trim().isNotEmpty) {
      oauthSocials['whatsapp'] = _whatsappController.text.trim();
    }
    if (_telegramController.text.trim().isNotEmpty) {
      oauthSocials['telegram'] = _telegramController.text.trim();
    }

    try {
      await userRepo.claimUsername(usernameLower, widget.uid);
      await userRepo.savePrivateProfile(
        uid: widget.uid,
        phoneNumber: phone,
      );
      final newRole = widget.initialProfile?.role ?? 'member';
      final profile = AppUser(
        uid: widget.uid,
        displayName: displayName,
        username: username,
        usernameLower: usernameLower,
        avatarUrl: widget.initialProfile?.avatarUrl ?? '',
        bio: bio,
        country: country,
        sessions: _selectedSessions.toList(),
        instruments: _selectedInstruments.toList(),
        strategyStyle: _strategyStyle!,
        experienceLevel: _experienceLevel!,
        role: newRole,
        traderStatus: 'pending',
        rejectReason: null,
        socials: oauthSocials,
        socialLinks: const {},
        yearsExperience: int.tryParse(_yearsController.text),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Application submitted. Admin will contact you shortly.'),
          ),
        );
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

  Widget _buildMultiSelect({
    required String label,
    required List<String> options,
    required Set<String> selected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (selectedValue) {
                setState(() {
                  if (selectedValue) {
                    selected.add(option);
                  } else {
                    selected.remove(option);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trader application')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                decoration: const InputDecoration(labelText: 'Country'),
                validator: (value) => validateRequired(value, 'Country'),
              ),
              TextFormField(
                controller: _phoneController,
                decoration:
                    const InputDecoration(labelText: 'Phone (E.164 format)'),
                validator: (value) => validateRequired(value, 'Phone'),
              ),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLength: 200,
                validator: (value) => validateRequired(value, 'Bio'),
              ),
              const SizedBox(height: 12),
              _buildMultiSelect(
                  label: 'Sessions',
                  options: sessions,
                  selected: _selectedSessions),
              const SizedBox(height: 12),
              _buildMultiSelect(
                  label: 'Instruments',
                  options: instruments,
                  selected: _selectedInstruments),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _strategyStyle,
                decoration: const InputDecoration(labelText: 'Strategy style'),
                items: strategyStyles
                    .map((style) => DropdownMenuItem(
                          value: style,
                          child: Text(style),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _strategyStyle = value),
                validator: (value) =>
                    value == null ? 'Select strategy style' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _experienceLevel,
                decoration:
                    const InputDecoration(labelText: 'Experience level'),
                items: experienceLevels
                    .map((level) => DropdownMenuItem(
                          value: level,
                          child: Text(level),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => _experienceLevel = value),
                validator: (value) =>
                    value == null ? 'Select experience level' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _whatsappController,
                decoration:
                    const InputDecoration(labelText: 'WhatsApp (optional)'),
              ),
              TextFormField(
                controller: _telegramController,
                decoration:
                    const InputDecoration(labelText: 'Telegram (optional)'),
              ),
              TextFormField(
                controller: _yearsController,
                decoration: const InputDecoration(
                    labelText: 'Years of experience (optional)'),
                keyboardType: TextInputType.number,
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
                      : const Text('Submit application'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
