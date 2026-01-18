import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/revenue_stats.dart';
import '../../../core/models/signal.dart';
import '../../../core/utils/role_helpers.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/firestore_error_widget.dart';
import '../../profile/presentation/settings_screen.dart';
import '../../testimonials/presentation/admin_testimonials_screen.dart';
import 'affiliate_manager_screen.dart';
import 'plan_manager_screen.dart';
import 'revenue_screen.dart';
import '../services/sales_report_service.dart';
import 'session_settings_screen.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

final _adminTabProvider = StateProvider<int>((ref) => 0);

final _signalStatusProvider =
    StreamProvider.family<List<Signal>, String>((ref, status) {
  if (status == 'open') {
    return ref
        .watch(signalRepositoryProvider)
        .watchSignalsByStatuses(['open', 'voting']);
  }
  return ref.watch(signalRepositoryProvider).watchSignalsByStatus(status);
});

final _adminUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchUsers();
});

final _revenueStatsProvider = StreamProvider<RevenueStats?>((ref) {
  return ref.watch(revenueRepositoryProvider).watchStats();
});

final _adminUserSearchQueryProvider = StateProvider<String>((ref) => '');
final _adminUserSearchActiveProvider = StateProvider<bool>((ref) => false);
final _revenueReportBusyProvider = StateProvider<bool>((ref) => false);

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(currentUserProvider);
    return profileState.when(
      data: (profile) {
        if (profile == null) {
          return const _AdminLoadingScaffold(message: 'Loading profile…');
        }
        if (!isAdmin(profile.role)) {
          return const _AdminAccessDeniedScreen();
        }
        return _AdminShellContent(admin: profile);
      },
      loading: () => const _AdminLoadingScaffold(),
      error: (error, stack) => Scaffold(
        body: Center(
          child: FirestoreErrorWidget(
            error: error,
            stackTrace: stack,
            title: 'Unable to load admin profile',
          ),
        ),
      ),
    );
  }
}

class _AdminShellContent extends ConsumerWidget {
  const _AdminShellContent({required this.admin, super.key});

  final AppUser admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(_adminTabProvider);
    final navIndex = _navIndexForTab(selectedIndex);
    final isUsersTab = selectedIndex == 1;
    final searchActive = ref.watch(_adminUserSearchActiveProvider);
    final reportBusy = ref.watch(_revenueReportBusyProvider);
    const tabs = [
      AdminDashboardTab(),
      UserManagementTab(),
      ContentManagementTab(),
      RevenueScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: isUsersTab && searchActive
            ? const _AdminUserSearchField()
            : const Text('Admin panel'),
        actions: [
          if (selectedIndex == 3)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed:
                    reportBusy ? null : () => _downloadReport(context, ref),
                icon: reportBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(AppIcons.download),
                label:
                    Text(reportBusy ? 'Preparing...' : 'Download sales report'),
              ),
            ),
          if (isUsersTab)
            IconButton(
              icon: Icon(searchActive ? AppIcons.close : AppIcons.search),
              tooltip: searchActive ? 'Close search' : 'Search users',
              onPressed: () {
                final notifier =
                    ref.read(_adminUserSearchActiveProvider.notifier);
                final nextState = !notifier.state;
                notifier.state = nextState;
                if (!nextState) {
                  ref.read(_adminUserSearchQueryProvider.notifier).state = '';
                }
              },
            ),
          IconButton(
            icon: const Icon(AppIcons.settings),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: KeyedSubtree(
        key: ValueKey(selectedIndex),
        child: tabs[selectedIndex],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddBroker(context),
        child: const Icon(AppIcons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (value) {
          if (value == 0) {
            ref.read(_adminTabProvider.notifier).state = 0;
            return;
          }
          if (value == 1) {
            ref.read(_adminTabProvider.notifier).state = 2;
            return;
          }
          if (value == 2) {
            ref.read(_adminTabProvider.notifier).state = 3;
            return;
          }
          _openAdminMenu(context, ref);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(AppIcons.dashboard), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(AppIcons.content_copy), label: 'Content'),
          NavigationDestination(
              icon: Icon(AppIcons.payments_outlined), label: 'Revenue'),
          NavigationDestination(icon: Icon(AppIcons.menu), label: 'Menu'),
        ],
      ),
    );
  }

  int _navIndexForTab(int tabIndex) {
    if (tabIndex == 0) {
      return 0;
    }
    if (tabIndex == 2) {
      return 1;
    }
    if (tabIndex == 3) {
      return 2;
    }
    return 3;
  }

  void _openAdminMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(AppIcons.people),
                title: const Text('Users'),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(_adminTabProvider.notifier).state = 1;
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.payments_outlined),
                title: const Text('Publish plans'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlanManagerScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(AppIcons.settings_outlined),
                title: const Text('Session settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SessionSettingsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _openAddBroker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(AppIcons.handshake),
                title: const Text('Add broker'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BrokerManagerScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadReport(BuildContext context, WidgetRef ref) async {
    if (ref.read(_revenueReportBusyProvider)) {
      return;
    }
    ref.read(_revenueReportBusyProvider.notifier).state = true;
    try {
      final profile = ref.read(currentUserProvider).valueOrNull;
      if (profile == null || !isAdmin(profile.role)) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only admins can download sales reports.'),
          ),
        );
        return;
      }

      final service = SalesReportService();
      final payments = await service.fetchPaidSales();
      final excel = service.buildSalesReport(payments);
      final file = await service.saveReportFile(excel);
      await service.shareReport(file);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to generate sales report.'),
        ),
      );
    } finally {
      ref.read(_revenueReportBusyProvider.notifier).state = false;
    }
  }
}

class _AdminLoadingScaffold extends StatelessWidget {
  const _AdminLoadingScaffold({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 12),
              Text(message!),
            ]
          ],
        ),
      ),
    );
  }
}

class _AdminAccessDeniedScreen extends StatelessWidget {
  const _AdminAccessDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Admin access required.'),
      ),
    );
  }
}

class AdminDashboardTab extends ConsumerWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(_adminUsersProvider);
    final tokens = AppThemeTokens.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final traderCount = users.maybeWhen(
      data: (list) => list.where((user) => isTrader(user.role)).length,
      orElse: () => 0,
    );
    final memberCount = users.maybeWhen(
      data: (list) => list.where((user) => isMember(user.role)).length,
      orElse: () => 0,
    );

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Admin dashboard',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _DashboardMetricCard<Signal>(
                label: 'Active signals',
                state: ref.watch(_signalStatusProvider('open')),
                accent: tokens.success,
                icon: AppIcons.trending_up,
              ),
              const SizedBox(height: 12),
              _RevenueSnapshotCard(state: ref.watch(_revenueStatsProvider)),
              const SizedBox(height: 16),
              _DashboardCountTile(
                label: 'Traders',
                value: traderCount,
                icon: AppIcons.groups,
                accent: colorScheme.primary,
                onTap: () => ref.read(_adminTabProvider.notifier).state = 1,
              ),
              const SizedBox(height: 12),
              _DashboardCountTile(
                label: 'Members',
                value: memberCount,
                icon: AppIcons.person_outline,
                accent: colorScheme.secondary,
                onTap: () => ref.read(_adminTabProvider.notifier).state = 1,
              ),
              const SizedBox(height: 24),
              Text(
                'Quick actions',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tokens.mutedText,
                ),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  final width = (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: width,
                        child: _QuickActionCard(
                          label: 'Manage users',
                          icon: AppIcons.group_outlined,
                          color: tokens.success,
                          onTap: () =>
                              ref.read(_adminTabProvider.notifier).state = 1,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _QuickActionCard(
                          label: 'Session settings',
                          icon: AppIcons.settings_outlined,
                          color: tokens.warning,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SessionSettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _QuickActionCard(
                          label: 'Publish plans',
                          icon: AppIcons.payments_outlined,
                          color: colorScheme.primary,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PlanManagerScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMetricCard<T> extends StatelessWidget {
  const _DashboardMetricCard({
    required this.label,
    required this.state,
    required this.accent,
    required this.icon,
  });

  final String label;
  final AsyncValue<List<T>> state;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = AppThemeTokens.of(context);
    return Card(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 120),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: state.when(
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _MetricIcon(icon: icon, color: accent),
                    Text(
                      items.length.toString(),
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(label, style: textTheme.bodyMedium),
                Text(
                  '${items.length} items',
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.mutedText,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => FirestoreErrorWidget(
              error: error,
              stackTrace: stack,
              title: '$label failed to load',
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardWideMetricCard<T> extends StatelessWidget {
  const _DashboardWideMetricCard({
    required this.label,
    required this.state,
    required this.accent,
    required this.icon,
  });

  final String label;
  final AsyncValue<List<T>> state;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final tokens = AppThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          data: (items) {
            return Row(
              children: [
                _MetricIcon(icon: icon, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: textTheme.bodyMedium),
                      Text(
                        '${items.length} items',
                        style: textTheme.labelSmall?.copyWith(
                          color: tokens.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  items.length.toString(),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => FirestoreErrorWidget(
            error: error,
            stackTrace: stack,
            title: '$label failed to load',
          ),
        ),
      ),
    );
  }
}

class _RevenueSnapshotCard extends StatelessWidget {
  const _RevenueSnapshotCard({required this.state});

  final AsyncValue<RevenueStats?> state;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: state.when(
          data: (stats) {
            final data = stats ?? RevenueStats.empty();
            return Row(
              children: [
                _MetricIcon(
                    icon: AppIcons.payments_outlined, color: tokens.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revenue',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        'This month: ${data.currentMonthRevenue.toStringAsFixed(0)} ${data.currency}',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: tokens.mutedText),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${data.totalRevenue.toStringAsFixed(0)} ${data.currency}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: tokens.success,
                      ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => FirestoreErrorWidget(
            error: error,
            stackTrace: stack,
            title: 'Revenue failed to load',
          ),
        ),
      ),
    );
  }
}

class _MetricIcon extends StatelessWidget {
  const _MetricIcon({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _DashboardCountTile extends StatelessWidget {
  const _DashboardCountTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _MetricIcon(icon: icon, color: accent),
        title: Text(label),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.toString(),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            const Icon(AppIcons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class UserManagementTab extends ConsumerStatefulWidget {
  const UserManagementTab({super.key});

  @override
  ConsumerState<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends ConsumerState<UserManagementTab> {
  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(_adminUsersProvider);
    final search =
        ref.watch(_adminUserSearchQueryProvider).trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        children: [
          Expanded(
            child: usersState.when(
              data: (users) {
                final filtered = users.where((user) {
                  final matchesSearch = search.isEmpty ||
                      user.displayName.toLowerCase().contains(search) ||
                      user.username.toLowerCase().contains(search);
                  return matchesSearch;
                }).toList();
                return filtered.isEmpty
                    ? const Center(child: Text('No users match.'))
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = filtered[index];
                          return _UserItemTile(user: user);
                        },
                      );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: FirestoreErrorWidget(
                  error: error,
                  stackTrace: stack,
                  title: 'Users failed to load',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserItemTile extends ConsumerStatefulWidget {
  const _UserItemTile({required this.user});

  final AppUser user;

  @override
  ConsumerState<_UserItemTile> createState() => _UserItemTileState();
}

class _UserItemTileState extends ConsumerState<_UserItemTile> {
  bool _trialTestLoading = false;
  bool _purchaseTestLoading = false;

  Future<void> _sendTrialTest() async {
    setState(() => _trialTestLoading = true);
    try {
      await ref.read(adminNotificationServiceProvider).testTrialNotification(
            memberName: widget.user.displayName.isNotEmpty
                ? widget.user.displayName
                : 'Member',
            memberUid: widget.user.uid,
          );
      AppToast.success(context, 'Trial notification sent.');
    } catch (error) {
      AppToast.error(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _trialTestLoading = false);
      }
    }
  }

  Future<void> _sendPurchaseTest() async {
    setState(() => _purchaseTestLoading = true);
    try {
      await ref.read(adminNotificationServiceProvider).testPurchaseNotification(
            memberName: widget.user.displayName.isNotEmpty
                ? widget.user.displayName
                : 'Member',
            memberUid: widget.user.uid,
          );
      AppToast.success(context, 'Purchase notification sent.');
    } catch (error) {
      AppToast.error(context, error.toString());
    } finally {
      if (mounted) {
        setState(() => _purchaseTestLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = user.displayName.isNotEmpty ? user.displayName : 'User';
    final username =
        user.username.isNotEmpty ? '@${user.username}' : 'No username';
    final email = user.email.isNotEmpty ? user.email : null;
    final role = normalizeRole(user.role);
    final traderStatus = isTrader(role) ? user.traderStatus : null;
    final subtitleParts = <String>[
      if (email != null) email,
      username,
      roleLabel(role),
    ];

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ListTileTheme(
        dense: true,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(68, 4, 12, 12),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: colorScheme.primary.withOpacity(0.12),
            backgroundImage:
                user.avatarUrl.isNotEmpty ? NetworkImage(user.avatarUrl) : null,
            child: user.avatarUrl.isEmpty
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.primary,
                    ),
                  )
                : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: 6),
                Icon(
                  AppIcons.verified,
                  size: 14,
                  color: tokens.success,
                ),
              ],
              if (user.isBanned) ...[
                const SizedBox(width: 6),
                const Icon(
                  AppIcons.block,
                  size: 14,
                  color: Colors.redAccent,
                ),
              ],
            ],
          ),
          subtitle: Text(
            subtitleParts.join(' · '),
            style: textTheme.bodySmall?.copyWith(
              color: tokens.mutedText,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (traderStatus != null && traderStatus != 'none')
                  _UserTag(
                    label: traderStatus == 'active'
                        ? 'Active trader'
                        : 'Trader ${traderStatus.toString()}',
                    color: traderStatus == 'active'
                        ? tokens.success
                        : tokens.warning,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'Role',
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.mutedText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                _RoleDropdown(
                  value: role,
                  onChanged: (value) {
                    if (value != null && value != normalizeRole(user.role)) {
                      final update = <String, dynamic>{'role': value};
                      if (value == 'trader' || value == 'trader_admin') {
                        update['traderStatus'] = 'active';
                        update['rejectReason'] = null;
                      } else {
                        update['traderStatus'] = 'none';
                      }
                      ref.read(userRepositoryProvider).updateUser(
                            user.uid,
                            update,
                          );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _UserToggleChip(
                  label: 'Verified',
                  icon: AppIcons.verified,
                  color: tokens.success,
                  selected: user.isVerified,
                  onSelected: (value) {
                    ref.read(userRepositoryProvider).updateUser(user.uid, {
                      'isVerified': value,
                    });
                  },
                ),
                _UserToggleChip(
                  label: 'Banned',
                  icon: AppIcons.block,
                  color: Colors.redAccent,
                  selected: user.isBanned,
                  onSelected: (value) {
                    ref.read(userRepositoryProvider).updateUser(user.uid, {
                      'isBanned': value,
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (user.membership?.source == 'trial' &&
                user.membership?.expiresAt != null &&
                user.membership!.isPremiumActive()) ...[
              Text(
                'Trial ends ${formatTanzaniaDateTime(user.membership!.expiresAt!)}',
                style: textTheme.bodySmall?.copyWith(
                  color: tokens.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _trialTestLoading ? null : _sendTrialTest,
                  icon: _trialTestLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.timer),
                  label: const Text('Test trial notice'),
                ),
                FilledButton.icon(
                  onPressed: _purchaseTestLoading ? null : _sendPurchaseTest,
                  icon: _purchaseTestLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(AppIcons.payments_outlined),
                  label: const Text('Test purchase notice'),
                ),
              ],
            ),
            if (user.rejectReason != null && user.rejectReason!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reject reason: ${user.rejectReason}',
                style: textTheme.bodySmall?.copyWith(
                  color: tokens.mutedText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'member', child: Text('Member')),
            DropdownMenuItem(value: 'trader', child: Text('Trader')),
            DropdownMenuItem(
                value: 'trader_admin', child: Text('Trader Admin')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _UserTag extends StatelessWidget {
  const _UserTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final textColor = color == tokens.mutedText ? tokens.mutedText : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UserToggleChip extends StatelessWidget {
  const _UserToggleChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final foreground = selected ? color : tokens.mutedText;
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      selectedColor: color.withOpacity(0.2),
      backgroundColor: tokens.surfaceAlt,
      side: BorderSide(color: tokens.border),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    );
  }
}

class _UserCountChip extends StatelessWidget {
  const _UserCountChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
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
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminUserSearchField extends ConsumerStatefulWidget {
  const _AdminUserSearchField();

  @override
  ConsumerState<_AdminUserSearchField> createState() =>
      _AdminUserSearchFieldState();
}

class _AdminUserSearchFieldState extends ConsumerState<_AdminUserSearchField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(_adminUserSearchQueryProvider),
    );
    _controller.addListener(() {
      ref.read(_adminUserSearchQueryProvider.notifier).state = _controller.text;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (context, value, _) {
        return TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search users',
            prefixIcon: const Icon(AppIcons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(AppIcons.close),
                    tooltip: 'Clear',
                    onPressed: () => _controller.clear(),
                  ),
            filled: true,
            fillColor: tokens.surfaceAlt,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tokens.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: tokens.border),
            ),
          ),
        );
      },
    );
  }
}

class ContentManagementTab extends StatelessWidget {
  const ContentManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Content tools',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            title: const Text('Testimonials'),
            subtitle: const Text('Review or unpublish curated proof'),
            trailing: const Icon(AppIcons.arrow_forward),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminTestimonialsScreen(),
                ),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Brokers'),
            subtitle: const Text('Manage trusted broker list'),
            trailing: const Icon(AppIcons.arrow_forward),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BrokerManagerScreen()),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Session settings'),
            subtitle: const Text('Configure trading session durations'),
            trailing: const Icon(AppIcons.arrow_forward),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SessionSettingsScreen(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
