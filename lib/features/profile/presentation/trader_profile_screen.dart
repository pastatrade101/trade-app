import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/signal.dart';
import '../../../core/utils/social_links.dart';
import '../../../core/utils/role_helpers.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../home/presentation/signal_detail_screen.dart';
import '../../reports/presentation/report_dialog.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

final traderProfileProvider = StreamProvider.family((ref, String uid) {
  return ref.watch(userRepositoryProvider).watchUser(uid);
});

class TraderProfileScreen extends ConsumerStatefulWidget {
  const TraderProfileScreen({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<TraderProfileScreen> createState() =>
      _TraderProfileScreenState();
}

class _TraderProfileScreenState extends ConsumerState<TraderProfileScreen> {
  bool _bannerUploading = false;

  Future<void> _pickBanner(AppUser user) async {
    if (_bannerUploading) {
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
    setState(() => _bannerUploading = true);
    final storage = ref.read(storageServiceProvider);
    final userRepo = ref.read(userRepositoryProvider);
    try {
      final result = await storage.uploadBanner(
        uid: user.uid,
        file: File(picked.path),
      );
      final bannerUrl = result.$1;
      final bannerPath = result.$2;
      try {
        await userRepo.updateBanner(
          uid: user.uid,
          bannerUrl: bannerUrl,
          bannerPath: bannerPath,
        );
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Banner uploaded, but profile update failed.',
            ),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () async {
                try {
                  await userRepo.updateBanner(
                    uid: user.uid,
                    bannerUrl: bannerUrl,
                    bannerPath: bannerPath,
                  );
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Banner update failed again.'),
                    ),
                  );
                }
              },
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Banner upload failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _bannerUploading = false);
      }
    }
  }

  Future<void> _removeBanner(AppUser user) async {
    if (_bannerUploading) {
      return;
    }
    setState(() => _bannerUploading = true);
    final storage = ref.read(storageServiceProvider);
    final userRepo = ref.read(userRepositoryProvider);
    try {
      final path = user.bannerPath ?? '';
      if (path.isNotEmpty) {
        await storage.deletePath(path);
      }
      await userRepo.clearBanner(user.uid);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to remove banner: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _bannerUploading = false);
      }
    }
  }

  void _showBannerActions(AppUser user) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final hasBanner = (user.bannerUrl ?? '').isNotEmpty;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(AppIcons.photo_library),
                  title: const Text('Upload banner'),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pickBanner(user);
                  },
                ),
                if (hasBanner)
                  ListTile(
                    leading: const Icon(AppIcons.delete_outline),
                    title: const Text('Remove banner'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _removeBanner(user);
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
                        icon: const Icon(AppIcons.close),
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

    add('twitter', AppIcons.alternate_email, 'X');
    add('telegram', AppIcons.send, 'Telegram');
    add('instagram', AppIcons.camera_alt, 'Instagram');
    add('youtube', AppIcons.ondemand_video, 'YouTube');
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
    final userState = ref.watch(traderProfileProvider(widget.uid));
    final currentUser = ref.watch(currentUserProvider).value;
    final isSelf = currentUser?.uid == widget.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Trader profile')),
      body: userState.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('User not found'));
          }
          final primaryName = user.displayName.isNotEmpty
              ? user.displayName
              : (user.username.isNotEmpty ? '@${user.username}' : 'Trader');
          final socials = user.socials.entries
              .where((entry) => entry.value.trim().isNotEmpty)
              .toList();
          final socialLinks = user.socialLinks;
          final canEditBanner = isTrader(user.role) &&
              ((isSelf && isTrader(currentUser?.role)) ||
                  (currentUser != null && isAdmin(currentUser.role)));
          final canEditSocialLinks = (currentUser != null &&
              (isAdmin(currentUser.role) ||
                  (isSelf && isTrader(currentUser.role))));
          final hasSocialLinks = socialLinks.values
              .where((value) => value.trim().isNotEmpty)
              .isNotEmpty;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _TraderBannerHeader(
                  user: user,
                  title: primaryName,
                  canEdit: canEditBanner,
                  isUploading: _bannerUploading,
                  onEdit: canEditBanner ? () => _showBannerActions(user) : null,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      AppSectionCard(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaChip(label: roleLabel(user.role)),
                            if (user.isBanned)
                              const _MetaChip(
                                label: 'Banned',
                                tone: _MetaChipTone.danger,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isTrader(user.role))
                        AppSectionCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: AppSectionTitle(title: 'Socials'),
                                  ),
                                  if (canEditSocialLinks)
                                    TextButton(
                                      onPressed: () =>
                                          _showSocialLinksEditor(user),
                                      child: const Text('Edit links'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (!hasSocialLinks)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'No social links added yet.',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                    if (canEditSocialLinks) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: OutlinedButton.icon(
                                          onPressed: () =>
                                              _showSocialLinksEditor(user),
                                          icon: const Icon(AppIcons.add),
                                          label: const Text('Add social links'),
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _buildSocialButtons(
                                    context,
                                    socialLinks,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (isTrader(user.role)) const SizedBox(height: 12),
                      AppSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppSectionTitle(title: 'Contact'),
                            const SizedBox(height: 10),
                            if (socials.isEmpty)
                              Text(
                                'No contact info provided.',
                                style: Theme.of(context).textTheme.bodySmall,
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: socials
                                    .map(
                                      (entry) => _ContactChip(
                                        label: _formatContactLabel(entry.key),
                                        value: entry.value,
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!isSelf && currentUser != null)
                        TextButton.icon(
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (_) => ReportDialog(
                                targetType: 'user',
                                targetId: widget.uid,
                              ),
                            );
                          },
                          icon: const Icon(AppIcons.flag),
                          label: const Text('Report user'),
                        ),
                      const Divider(height: 24),
                      const Text('Recent signals'),
                    ],
                  ),
                ),
              ),
              StreamBuilder<List<Signal>>(
                stream: ref
                    .watch(signalRepositoryProvider)
                    .watchUserSignals(widget.uid),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final now = DateTime.now();
                  final signals = snapshot.data!
                      .where((signal) => signal.validUntil.isAfter(now))
                      .toList();
                  if (signals.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('No recent signals'),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final signal = signals[index];
                          return ListTile(
                            title: Text('${signal.pair} ${signal.direction}'),
                            subtitle: Text('Status: ${signal.status}'),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => SignalDetailScreen(
                                    signalId: signal.id,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        childCount: signals.length,
                      ),
                    ),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}

String _formatContactLabel(String key) {
  switch (key.toLowerCase()) {
    case 'whatsapp':
      return 'WhatsApp';
    case 'telegram':
      return 'Telegram';
    case 'phone':
      return 'Phone';
    case 'email':
      return 'Email';
    default:
      if (key.isEmpty) {
        return 'Contact';
      }
      return key[0].toUpperCase() + key.substring(1);
  }
}


class _TraderBannerHeader extends StatelessWidget {
  const _TraderBannerHeader({
    required this.user,
    required this.title,
    required this.canEdit,
    required this.isUploading,
    this.onEdit,
  });

  final AppUser user;
  final String title;
  final bool canEdit;
  final bool isUploading;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final bannerUrl = user.bannerUrl ?? '';
    final hasBanner = bannerUrl.isNotEmpty;
    return AspectRatio(
      aspectRatio: 1600 / 600,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasBanner)
            Image.network(
              bannerUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _bannerFallback(tokens),
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  return child;
                }
                return _bannerFallback(tokens);
              },
            )
          else
            _bannerFallback(tokens),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.6),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _AvatarBadge(user: user),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: textTheme.titleLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.isVerified)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(
                                    AppIcons.verified,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canEdit && onEdit != null)
            Positioned(
              right: 12,
              top: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IconButton(
                  icon: const Icon(AppIcons.more_vert, color: Colors.white),
                  iconSize: 18,
                  tooltip: 'Banner options',
                  onPressed: onEdit,
                ),
              ),
            ),
          if (isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bannerFallback(AppThemeTokens tokens) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.heroStart.withOpacity(0.9),
            tokens.heroEnd.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

class _InfoStat extends StatelessWidget {
  const _InfoStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: tokens.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
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

class _ContactChip extends StatelessWidget {
  const _ContactChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        '$label: $value',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = AppThemeTokens.of(context);
    final displayName =
        user.displayName.isNotEmpty ? user.displayName : 'Trader';
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: tokens.surface,
        shape: BoxShape.circle,
        border: Border.all(color: tokens.border),
      ),
      child: CircleAvatar(
        radius: 30,
        backgroundColor: colorScheme.primary.withOpacity(0.15),
        backgroundImage:
            user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
        child: user.avatarUrl.isEmpty
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : 'T',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              )
            : null,
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  const _BannerStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

enum _MetaChipTone { neutral, danger }

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    this.tone = _MetaChipTone.neutral,
  });

  final String label;
  final _MetaChipTone tone;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final color = tone == _MetaChipTone.danger
        ? Colors.redAccent
        : tokens.mutedText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
