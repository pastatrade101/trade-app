import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/utils/role_helpers.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../admin/presentation/admin_shell.dart';
import '../../home/presentation/create_signal_screen.dart';
import '../../home/presentation/signal_feed_screen.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../testimonials/presentation/testimonials_screen.dart';
import '../../tips/presentation/create_tip_screen.dart';
import '../../tips/presentation/tips_screen.dart';

final homeTabProvider = StateProvider<int>((ref) => 0);

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, this.user});

  final AppUser? user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = user ?? ref.watch(currentUserProvider).value;
    if (currentUser == null) {
      return const _LoadingScreen();
    }
    final role = currentUser.role;
    if (isAdmin(role)) {
      return const AdminShell();
    }
    return UserShell(user: currentUser);
  }
}

class UserShell extends ConsumerWidget {
  const UserShell({required this.user, super.key});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabProvider);
    final isActiveTrader = user.role == 'trader' && user.traderStatus == 'active';

    final pages = [
      const SignalFeedScreen(),
      const TestimonialsScreen(),
      const TipsScreen(),
      ProfileScreen(user: user),
    ];

    return Scaffold(
      body: pages[index],
      floatingActionButton: isActiveTrader
          ? FloatingActionButton(
              onPressed: () => _openCreateOptions(context),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) =>
            ref.read(homeTabProvider.notifier).state = value,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Signals'),
          NavigationDestination(
              icon: Icon(Icons.format_quote), label: 'Testimonials'),
          NavigationDestination(icon: Icon(Icons.lightbulb), label: 'Tips'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  void _openCreateOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CreateOptionCard(
                        icon: Icons.show_chart,
                        title: 'Signal',
                        subtitle: 'Post a trade idea',
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateSignalScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _CreateOptionCard(
                        icon: Icons.lightbulb_outline,
                        title: 'Tip',
                        subtitle: 'Share one idea',
                        onTap: () {
                          Navigator.of(context).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TipCreateScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreateOptionCard extends StatelessWidget {
  const _CreateOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).colorScheme;
    return AppSectionCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: tokens.primary.withOpacity(0.12),
              child: Icon(icon, color: tokens.primary, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
