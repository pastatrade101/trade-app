import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/signal.dart';
import '../../../core/models/user_membership.dart';
import '../../../core/repositories/tip_repository.dart';
import '../../../core/utils/role_helpers.dart';
import '../../../core/utils/social_links.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../admin/presentation/admin_panel_screen.dart';
import '../../admin/presentation/highlight_manager_screen.dart';
import '../../tips/presentation/admin_tips_manager_screen.dart';
import '../../auth/presentation/member_onboarding_screen.dart';
import '../../home/presentation/signal_detail_screen.dart';
import '../../partners/presentation/partners_tab.dart';
import '../../testimonials/presentation/testimonials_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _uploadingAvatar = false;
  bool _uploadingBanner = false;

  bool get _needsProfileCompletion {
    return widget.user.username.isEmpty || widget.user.displayName.isEmpty;
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _selectAvatar() async {
    if (_uploadingAvatar) {
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 640,
    );
    if (picked == null) {
      return;
    }
    setState(() => _uploadingAvatar = true);
    try {
      final imageUrl = await ref.read(storageServiceProvider).uploadUserAvatar(
            uid: widget.user.uid,
            file: File(picked.path),
          );
      await ref.read(userRepositoryProvider).updateUser(widget.user.uid, {
        'avatarUrl': imageUrl,
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar upload failed. Try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingAvatar = false);
      }
    }
  }

  Future<void> _selectBanner() async {
    if (_uploadingBanner) {
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 92,
    );
    if (picked == null) {
      return;
    }
    setState(() => _uploadingBanner = true);
    try {
      final result = await ref.read(storageServiceProvider).uploadBanner(
            uid: widget.user.uid,
            file: File(picked.path),
          );
      await ref.read(userRepositoryProvider).updateBanner(
            uid: widget.user.uid,
            bannerUrl: result.$1,
            bannerPath: result.$2,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Banner upload failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingBanner = false);
      }
    }
  }

  Future<void> _removeBanner() async {
    if (_uploadingBanner) {
      return;
    }
    setState(() => _uploadingBanner = true);
    try {
      final path = widget.user.bannerPath ?? '';
      if (path.isNotEmpty) {
        await ref.read(storageServiceProvider).deletePath(path);
      }
      await ref.read(userRepositoryProvider).clearBanner(widget.user.uid);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Banner remove failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingBanner = false);
      }
    }
  }

  void _showBannerActions() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final hasBanner = (widget.user.bannerUrl ?? '').isNotEmpty;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Upload banner'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _selectBanner();
                  },
                ),
                if (hasBanner)
                  ListTile(
                    leading: const Icon(Icons.delete_outline),
                    title: const Text('Remove banner'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _removeBanner();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSocialLinksEditor(AppUser user) {
    final twitterController =
        TextEditingController(text: user.socialLinks['twitter'] ?? '');
    final telegramController =
        TextEditingController(text: user.socialLinks['telegram'] ?? '');
    final instagramController =
        TextEditingController(text: user.socialLinks['instagram'] ?? '');
    final youtubeController =
        TextEditingController(text: user.socialLinks['youtube'] ?? '');

    final sheet = showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        bool saving = false;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> saveLinks() async {
              if (saving) return;
              final links = <String, String>{
                'twitter': twitterController.text.trim(),
                'telegram': telegramController.text.trim(),
                'instagram': instagramController.text.trim(),
                'youtube': youtubeController.text.trim(),
              };
              for (final entry in links.entries) {
                final error = validateSocialUrl(entry.key, entry.value);
                if (error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error)),
                  );
                  return;
                }
              }
              final cleaned = sanitizeSocialLinks(links);
              setModalState(() => saving = true);
              try {
                await ref.read(userRepositoryProvider).updateSocialLinks(
                      uid: user.uid,
                      socialLinks: cleaned,
                    );
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } catch (error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Save failed: $error')),
                );
              } finally {
                if (mounted) {
                  setModalState(() => saving = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Social links',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SocialField(
                    label: 'X (Twitter)',
                    hint: 'https://x.com/username',
                    controller: twitterController,
                  ),
                  const SizedBox(height: 12),
                  _SocialField(
                    label: 'Telegram',
                    hint: 'https://t.me/username',
                    controller: telegramController,
                  ),
                  const SizedBox(height: 12),
                  _SocialField(
                    label: 'Instagram',
                    hint: 'https://instagram.com/username',
                    controller: instagramController,
                  ),
                  const SizedBox(height: 12),
                  _SocialField(
                    label: 'YouTube',
                    hint: 'https://youtube.com/@channel',
                    controller: youtubeController,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: saving ? null : saveLinks,
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Save links'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    sheet.whenComplete(() {
      twitterController.dispose();
      telegramController.dispose();
      instagramController.dispose();
      youtubeController.dispose();
    });
  }

  List<Widget> _buildSocialButtons(
    BuildContext context,
    Map<String, String> links,
  ) {
    final buttons = <Widget>[];
    void add(String key, IconData icon, String label) {
      final url = links[key];
      if (url == null || url.trim().isEmpty) {
        return;
      }
      buttons.add(
        _SocialIconButton(
          icon: icon,
          label: label,
          onTap: () => _openSocialLink(context, url),
        ),
      );
    }

    add('twitter', Icons.alternate_email, 'X');
    add('telegram', Icons.send, 'Telegram');
    add('instagram', Icons.camera_alt, 'Instagram');
    add('youtube', Icons.ondemand_video, 'YouTube');
    return buttons;
  }

  Future<void> _openSocialLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid social link')),
      );
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final isAdmin = user.role == 'admin';
    final isActiveTrader =
        user.role == 'trader' && user.traderStatus == 'active';
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = AppThemeTokens.of(context);
    final primaryColor = colorScheme.primary;
    final heroStart = tokens.heroStart;
    final heroEnd = tokens.heroEnd;
    final mutedText = tokens.mutedText;
    final surfaceAltColor = tokens.surfaceAlt;
    final borderColor = tokens.border;

    final signalsStream =
        ref.watch(signalRepositoryProvider).watchUserSignals(user.uid);
    final tipStatsStream = user.role == 'trader'
        ? ref
            .watch(tipRepositoryProvider)
            .watchTipEngagementSummary(uid: user.uid)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AdminPanelScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
              _buildAnimatedSection(
                start: 0.0,
                end: 0.5,
                child: _ProfileHeroCard(
                  user: user,
                  initials: _initialsFor(user),
                  heroStart: heroStart,
                  heroEnd: heroEnd,
                  uploadingAvatar: _uploadingAvatar,
                  onUploadTap: _selectAvatar,
                  uploadingBanner: _uploadingBanner,
                  onBannerTap: _showBannerActions,
                ),
              ),
              if (_needsProfileCompletion) ...[
                const SizedBox(height: 16),
                _buildAnimatedSection(
                  start: 0.1,
                  end: 0.7,
                  child: AppSectionCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.edit_note,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Complete your profile',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Add a username and display name so you can '
                                'track signal outcomes and personalize your profile.',
                                style: TextStyle(color: mutedText),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            MemberOnboardingScreen(uid: user.uid),
                                      ),
                                    );
                                  },
                                  child: const Text('Finish setup'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (user.role == 'member') ...[
                const SizedBox(height: 16),
                _buildAnimatedSection(
                  start: 0.18,
                  end: 0.78,
                  child: _MembershipStatusCard(
                    membership: user.membership ?? UserMembership.free(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (user.role == 'trader') ...[
                _buildAnimatedSection(
                  start: 0.28,
                  end: 0.88,
                  child: AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: AppSectionTitle(title: 'Socials'),
                            ),
                            TextButton(
                              onPressed: () => _showSocialLinksEditor(user),
                              child: const Text('Edit links'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!user.socialLinks.values
                            .any((value) => value.trim().isNotEmpty))
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No social links added yet.',
                                style: TextStyle(color: mutedText),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showSocialLinksEditor(user),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add social links'),
                                ),
                              ),
                            ],
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _buildSocialButtons(
                              context,
                              user.socialLinks,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (user.role == 'trader') ...[
                _buildAnimatedSection(
                  start: 0.32,
                  end: 0.92,
                  child: AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(title: 'Tip engagement'),
                        const SizedBox(height: 12),
                        StreamBuilder<TipEngagementSummary>(
                          stream: tipStatsStream,
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: SizedBox(
                                    height: 28,
                                    width: 28,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            final stats = snapshot.data!;
                            if (stats.totalTips == 0) {
                              return Text(
                                'No tips yet',
                                style: TextStyle(color: mutedText),
                              );
                            }
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _MetricChip(
                                  label: 'Total tips',
                                  value: stats.totalTips.toString(),
                                  backgroundColor: surfaceAltColor,
                                  borderColor: borderColor,
                                ),
                                _MetricChip(
                                  label: 'Total likes',
                                  value: stats.totalLikes.toString(),
                                  backgroundColor: surfaceAltColor,
                                  borderColor: borderColor,
                                ),
                                _MetricChip(
                                  label: 'Total saves',
                                  value: stats.totalSaves.toString(),
                                  backgroundColor: surfaceAltColor,
                                  borderColor: borderColor,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (isActiveTrader) ...[
                _buildAnimatedSection(
                  start: 0.36,
                  end: 0.96,
                  child: AppSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const AppSectionTitle(title: 'Trader tools'),
                        const SizedBox(height: 8),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.lightbulb_outline),
                          title: const Text('Tips manager'),
                          subtitle: const Text('Publish and archive your tips'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const AdminTipsManagerScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(height: 12),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.star_outline),
                          title: const Text('Daily highlight'),
                          subtitle: const Text('Pick today highlight card'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HighlightManagerScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildAnimatedSection(
                start: 0.3,
                end: 0.9,
                child: AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(title: 'Quick actions'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PartnersTab(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.handshake),
                        label: const Text('Trusted Brokers'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildAnimatedSection(
                start: 0.45,
                end: 1.0,
                child: AppSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppSectionTitle(title: 'Recent signals'),
                      const SizedBox(height: 12),
                      StreamBuilder<List<Signal>>(
                        stream: signalsStream,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }
                          final signals = snapshot.data!;
                          if (signals.isEmpty) {
                            return Text(
                              'No recent signals',
                              style: TextStyle(color: mutedText),
                            );
                          }
                          return Column(
                            children: signals
                                .map(
                                  (signal) => _SignalTile(
                                    signal: signal,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => SignalDetailScreen(
                                            signalId: signal.id,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Community-generated content. Not financial advice. '
                'No guaranteed profits.',
                style: TextStyle(
                  fontSize: 12,
                  color: mutedText,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedSection({
    required double start,
    required double end,
    required Widget child,
  }) {
    final animation = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }

  String _initialsFor(AppUser user) {
    final source = user.displayName.isNotEmpty
        ? user.displayName
        : (user.username.isNotEmpty ? user.username : 'U');
    final parts = source.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) {
      return 'U';
    }
    final buffer = StringBuffer();
    for (final part in parts.take(2)) {
      if (part.isEmpty) {
        continue;
      }
      buffer.write(part[0].toUpperCase());
    }
    return buffer.isEmpty ? 'U' : buffer.toString();
  }
}

class _ProfileHeroCard extends StatefulWidget {
  const _ProfileHeroCard({
    required this.user,
    required this.initials,
    required this.heroStart,
    required this.heroEnd,
    required this.uploadingAvatar,
    required this.onUploadTap,
    required this.uploadingBanner,
    this.onBannerTap,
  });

  final AppUser user;
  final String initials;
  final Color heroStart;
  final Color heroEnd;
  final bool uploadingAvatar;
  final VoidCallback onUploadTap;
  final bool uploadingBanner;
  final VoidCallback? onBannerTap;

  @override
  State<_ProfileHeroCard> createState() => _ProfileHeroCardState();
}

class _ProfileHeroCardState extends State<_ProfileHeroCard> {
  Color? _vibrantColor;
  String? _paletteUrl;

  @override
  void initState() {
    super.initState();
    _loadPalette();
  }

  @override
  void didUpdateWidget(covariant _ProfileHeroCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.avatarUrl != widget.user.avatarUrl) {
      _loadPalette();
    }
  }

  Future<void> _loadPalette() async {
    final url = widget.user.avatarUrl;
    if (url.isEmpty) {
      if (mounted) {
        setState(() {
          _vibrantColor = null;
          _paletteUrl = null;
        });
      }
      return;
    }
    if (_paletteUrl == url && _vibrantColor != null) {
      return;
    }
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        size: const Size(200, 200),
        maximumColorCount: 12,
      );
      final swatch = palette.vibrantColor ??
          palette.lightVibrantColor ??
          palette.dominantColor ??
          palette.darkVibrantColor;
      if (mounted) {
        setState(() {
          _paletteUrl = url;
          _vibrantColor = swatch?.color;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _paletteUrl = url;
          _vibrantColor = null;
        });
      }
    }
  }

  Color _darken(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    final darkened =
        hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = AppThemeTokens.of(context);
    final displayName =
        widget.user.displayName.isNotEmpty ? widget.user.displayName : 'New member';
    final handle =
        widget.user.username.isNotEmpty ? '@${widget.user.username}' : 'Add username';
    final statusInfo = _buildStatus(tokens);
    final bannerUrl = widget.user.bannerUrl ?? '';
    final hasBanner = bannerUrl.isNotEmpty;
    final baseColor = _vibrantColor ?? widget.heroStart;
    final endColor = _vibrantColor != null
        ? _darken(baseColor, 0.2)
        : widget.heroEnd;
    final detailChips = <Widget>[
      if (widget.user.strategyStyle.isNotEmpty)
        _HeroDetailChip(label: 'Strategy', value: widget.user.strategyStyle),
      if (widget.user.experienceLevel.isNotEmpty)
        _HeroDetailChip(label: 'Experience', value: widget.user.experienceLevel),
      if (widget.user.yearsExperience != null)
        _HeroDetailChip(label: 'Years', value: '${widget.user.yearsExperience}'),
      if (widget.user.sessions.isNotEmpty)
        _HeroDetailChip(
          label: 'Sessions',
          value: widget.user.sessions.join(', '),
        ),
      if (widget.user.instruments.isNotEmpty)
        _HeroDetailChip(
          label: 'Instruments',
          value: widget.user.instruments.join(', '),
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AspectRatio(
                aspectRatio: 1600 / 600,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    hasBanner
                        ? Image.network(
                            bannerUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _bannerFallback(baseColor, endColor),
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) {
                                return child;
                              }
                              return _bannerFallback(baseColor, endColor);
                            },
                          )
                        : _bannerFallback(baseColor, endColor),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black.withOpacity(0.45),
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                    if (widget.uploadingBanner)
                      Container(
                        color: Colors.black.withOpacity(0.35),
                        child: const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
              if (widget.onBannerTap != null)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      iconSize: 18,
                      tooltip: 'Banner options',
                      onPressed: widget.onBannerTap,
                    ),
                  ),
                ),
              Positioned(
                left: 16,
                bottom: -28,
                child: _ProfileAvatar(
                  avatarUrl: widget.user.avatarUrl,
                  initials: widget.initials,
                  baseColor: baseColor,
                  uploading: widget.uploadingAvatar,
                  onTap: widget.onUploadTap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      handle,
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.user.isVerified) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ],
                ),
                if (widget.user.bio.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.user.bio,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoChip(
                      icon: Icons.shield_outlined,
                      label: roleLabel(widget.user.role),
                      backgroundColor: tokens.surfaceAlt,
                      textColor: tokens.mutedText,
                    ),
                    if (statusInfo != null)
                      _InfoChip(
                        icon: Icons.insights,
                        label: statusInfo.label,
                        backgroundColor: statusInfo.color.withOpacity(0.16),
                        textColor: statusInfo.color,
                      ),
                    if (widget.user.country.isNotEmpty)
                      _InfoChip(
                        icon: Icons.public,
                        label: widget.user.country,
                        backgroundColor: tokens.surfaceAlt,
                        textColor: tokens.mutedText,
                      ),
                    if (widget.user.isBanned)
                      _InfoChip(
                        icon: Icons.block,
                        label: 'Banned',
                        backgroundColor: Colors.red.withOpacity(0.12),
                        textColor: Colors.redAccent,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (detailChips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: detailChips,
                  ),
                ],
                if (widget.user.role == 'trader' &&
                    widget.user.traderStatus != 'active') ...[
                  const SizedBox(height: 12),
                  if (widget.user.rejectReason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Reason: ${widget.user.rejectReason}',
                      style: textTheme.bodySmall?.copyWith(
                        color: tokens.mutedText,
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerFallback(Color start, Color end) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [start, end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  _StatusInfo? _buildStatus(AppThemeTokens tokens) {
    if (widget.user.role != 'trader') {
      return null;
    }
    if (widget.user.traderStatus == 'none') {
      return null;
    }
    switch (widget.user.traderStatus) {
      case 'active':
        return _StatusInfo(label: 'Active trader', color: tokens.success);
      case 'pending':
        return _StatusInfo(label: 'Pending review', color: tokens.warning);
      case 'rejected':
        return const _StatusInfo(label: 'Rejected', color: Colors.redAccent);
      default:
        return _StatusInfo(
          label: 'Trader ${widget.user.traderStatus}',
          color: tokens.warning,
        );
    }
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.avatarUrl,
    required this.initials,
    required this.baseColor,
    required this.uploading,
    required this.onTap,
  });

  final String avatarUrl;
  final String initials;
  final Color baseColor;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(color: tokens.border),
          ),
          child: CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white,
            backgroundImage:
                avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
            child: avatarUrl.isEmpty
                ? Text(
                    initials,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: baseColor,
                        ),
                  )
                : null,
          ),
        ),
        Positioned(
          bottom: -2,
          right: -2,
          child: InkWell(
            onTap: uploading ? null : onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tokens.border),
              ),
              child: uploading
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: baseColor,
                      ),
                    )
                  : Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: baseColor,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusInfo {
  const _StatusInfo({required this.label, required this.color});

  final String label;
  final Color color;
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = AppThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: tokens.mutedText,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HeroDetailChip extends StatelessWidget {
  const _HeroDetailChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w600,
              ),
          children: [
            TextSpan(text: '$label: '),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({
    required this.signal,
    required this.onTap,
  });

  final Signal signal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('${signal.pair} ${signal.direction}'),
          subtitle: Text('Status: ${signal.status}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}

class _SocialField extends StatelessWidget {
  const _SocialField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
      keyboardType: TextInputType.url,
    );
  }
}

class _SocialIconButton extends StatelessWidget {
  const _SocialIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tokens.border),
          ),
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }
}

class _MembershipStatusCard extends StatelessWidget {
  const _MembershipStatusCard({required this.membership});

  final UserMembership membership;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final expiresAt = membership.expiresAt;
    final isPremium = membership.tier == 'premium';
    final remaining =
        expiresAt == null ? null : expiresAt.difference(now);
    final isExpired = remaining != null && remaining.isNegative;
    final isActive = membership.status == 'active' && isPremium && !isExpired;

    final statusLabel = isActive
        ? 'Active'
        : isPremium
            ? 'Expired'
            : 'Free';
    final statusColor =
        isActive ? tokens.success : isPremium ? tokens.warning : tokens.mutedText;

    final timeLeft = isActive && remaining != null
        ? formatCountdown(remaining)
        : '--';
    final endsOn = expiresAt != null
        ? formatTanzaniaDateTime(expiresAt, pattern: 'MMM d, yyyy')
        : '--';

    final message = isActive
        ? 'Your premium access is active.'
        : isPremium
            ? 'Your premium plan has ended. Renew to keep full access.'
            : 'No active membership. Choose a plan to unlock premium signals.';

    final textColor = Colors.black87;
    final mutedColor = Colors.black54;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tokens.shadow,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: AppTheme.lightSurfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.border),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: tokens.heroStart,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Membership',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isPremium ? 'Premium plan' : 'Free plan',
                      style: textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  statusLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: textTheme.bodySmall?.copyWith(color: mutedColor),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MembershipInfoTile(
                  label: 'Time left',
                  value: timeLeft,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MembershipInfoTile(
                  label: 'Ends on',
                  value: endsOn,
                  textColor: textColor,
                  mutedColor: mutedColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MembershipInfoTile extends StatelessWidget {
  const _MembershipInfoTile({
    required this.label,
    required this.value,
    required this.textColor,
    required this.mutedColor,
  });

  final String label;
  final String value;
  final Color textColor;
  final Color mutedColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: textColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: mutedColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.titleSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final String value;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
