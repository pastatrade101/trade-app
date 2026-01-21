import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/widgets/app_section_card.dart';
import 'trader_profile_screen.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

const _createdAtField = 'createdAt';

class TraderDiscoveryScreen extends ConsumerStatefulWidget {
  const TraderDiscoveryScreen({super.key});

  @override
  ConsumerState<TraderDiscoveryScreen> createState() => _TraderDiscoveryScreenState();
}

class _TraderDiscoveryScreenState extends ConsumerState<TraderDiscoveryScreen> {
  Future<List<AppUser>>? _future;

  @override
  void initState() {
    super.initState();
    _loadTraders();
  }

  void _loadTraders() {
    final repo = ref.read(userRepositoryProvider);
    setState(() {
      _future = repo.fetchTraders(orderField: _createdAtField);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover traders'),
      ),
      body: FutureBuilder<List<AppUser>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final traders = snapshot.data ?? [];
          if (traders.isEmpty) {
            return const Center(child: Text('No traders found'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: traders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final trader = traders[index];
              return _TraderCompactTile(
                trader: trader,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          _TraderDiscoveryDetailScreen(trader: trader),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TraderDiscoveryDetailScreen extends StatelessWidget {
  const _TraderDiscoveryDetailScreen({required this.trader});

  final AppUser trader;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trader details')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _TraderDiscoveryCard(
          trader: trader,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TraderProfileScreen(uid: trader.uid),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TraderCompactTile extends StatelessWidget {
  const _TraderCompactTile({
    required this.trader,
    required this.onTap,
  });

  final AppUser trader;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayName =
        trader.displayName.isNotEmpty ? trader.displayName : 'Trader';
    final primaryName = trader.displayName.isNotEmpty
        ? trader.displayName
        : (trader.username.isNotEmpty ? '@${trader.username}' : 'Trader');

    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: colorScheme.primary.withOpacity(0.12),
                  backgroundImage: trader.avatarUrl.isNotEmpty
                      ? NetworkImage(trader.avatarUrl)
                      : null,
                  child: trader.avatarUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'T',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              primaryName,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (trader.isVerified) ...[
                            const SizedBox(width: 6),
                            Icon(
                              AppIcons.verified,
                              color: colorScheme.primary,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TraderDiscoveryCard extends StatelessWidget {
  const _TraderDiscoveryCard({
    required this.trader,
    this.onTap,
  });

  final AppUser trader;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final displayName =
        trader.displayName.isNotEmpty ? trader.displayName : 'Trader';
    final username =
        trader.username.isNotEmpty ? '@${trader.username}' : 'No username';
    final socials = trader.socials.entries
        .where((entry) => entry.value.trim().isNotEmpty)
        .toList();
    final socialLinks = trader.socialLinks;
    final hasSocialLinks = socialLinks.values
        .any((value) => value.trim().isNotEmpty);
    final detailChips = <Widget>[];
    if (trader.strategyStyle.isNotEmpty) {
      detailChips.add(
        _InfoChip(
          icon: AppIcons.bolt,
          label: trader.strategyStyle,
          color: colorScheme.primary,
        ),
      );
    }
    if (trader.experienceLevel.isNotEmpty) {
      detailChips.add(
        _InfoChip(
          icon: AppIcons.school,
          label: trader.experienceLevel,
          color: tokens.success,
        ),
      );
    }
    if (trader.sessions.isNotEmpty) {
      detailChips.add(
        _InfoChip(
          icon: AppIcons.access_time,
          label: trader.sessions.join(', '),
          color: tokens.warning,
        ),
      );
    }
    if (trader.instruments.isNotEmpty) {
      detailChips.addAll(
        trader.instruments.map(
          (instrument) => _InfoChip(
            icon: AppIcons.show_chart,
            label: instrument,
            color: colorScheme.secondary,
          ),
        ),
      );
    }

    return AppSectionCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TraderCover(
                  trader: trader,
                  displayName: displayName,
                  username: username,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (detailChips.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: detailChips,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (hasSocialLinks) ...[
                        const SizedBox(height: 16),
                        const AppSectionTitle(title: 'Socials'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              _buildSocialButtons(context, socialLinks),
                        ),
                      ],
                      if (socials.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const AppSectionTitle(title: 'Contact'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: socials
                              .map(
                                (entry) => _ContactChip(
                                  label: entry.key,
                                  value: entry.value,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TraderCover extends StatelessWidget {
  const _TraderCover({
    required this.trader,
    required this.displayName,
    required this.username,
  });

  final AppUser trader;
  final String displayName;
  final String username;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final coverGradient = LinearGradient(
      colors: [
        tokens.heroStart.withOpacity(0.85),
        tokens.heroEnd.withOpacity(0.85),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final bannerUrl = trader.bannerUrl ?? '';
    final hasBanner = bannerUrl.isNotEmpty;
    final hasAvatar = trader.avatarUrl.isNotEmpty;
    return Column(
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
                  Container(
                    decoration: BoxDecoration(
                      gradient: hasBanner ? null : coverGradient,
                      image: hasBanner
                          ? DecorationImage(
                              image: NetworkImage(bannerUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                  ),
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
                ],
              ),
            ),
            Positioned(
              left: 16,
              bottom: -24,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: tokens.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.border),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      hasAvatar ? NetworkImage(trader.avatarUrl) : null,
                  child: !hasAvatar
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : 'T',
                          style: textTheme.titleMedium?.copyWith(
                            color: tokens.heroStart,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (trader.isVerified) ...[
                      const SizedBox(width: 6),
                      Icon(
                        AppIcons.verified,
                        color: Theme.of(context).colorScheme.primary,
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (username.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              username,
              style: textTheme.bodySmall?.copyWith(
                color: tokens.mutedText,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
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
        onTap: () => _openExternalLink(context, url),
      ),
    );
  }

  add('twitter', AppIcons.alternate_email, 'X');
  add('telegram', AppIcons.send, 'Telegram');
  add('instagram', AppIcons.camera_alt, 'Instagram');
  add('youtube', AppIcons.ondemand_video, 'YouTube');
  return buttons;
}

Future<void> _openExternalLink(BuildContext context, String url) async {
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
