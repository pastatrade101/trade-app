import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/report.dart';
import '../../../core/models/revenue_stats.dart';
import '../../../core/models/signal.dart';
import '../../../core/utils/role_helpers.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/widgets/firestore_error_widget.dart';
import '../../home/presentation/signal_detail_screen.dart';
import '../../profile/presentation/settings_screen.dart';
import '../../testimonials/presentation/admin_testimonials_screen.dart';
import 'affiliate_manager_screen.dart';
import 'plan_manager_screen.dart';
import 'pending_traders_screen.dart';
import 'revenue_screen.dart';
import 'session_settings_screen.dart';

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

final _reportsStatusProvider =
    StreamProvider.family<List<ReportItem>, String>((ref, status) {
  return ref.watch(reportRepositoryProvider).watchReportsByStatus(status);
});

final _adminUsersProvider = StreamProvider<List<AppUser>>((ref) {
  return ref.watch(userRepositoryProvider).watchUsers();
});

final _revenueStatsProvider = StreamProvider<RevenueStats?>((ref) {
  return ref.watch(revenueRepositoryProvider).watchStats();
});

final _adminUserSearchQueryProvider = StateProvider<String>((ref) => '');
final _adminUserSearchActiveProvider = StateProvider<bool>((ref) => false);

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
    final isUsersTab = selectedIndex == 3;
    final searchActive = ref.watch(_adminUserSearchActiveProvider);
    const tabs = [
      AdminDashboardTab(),
      ModerateSignalsTab(),
      ReportManagementTab(),
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
          if (isUsersTab)
            IconButton(
              icon: Icon(searchActive ? Icons.close : Icons.search),
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
            icon: const Icon(Icons.settings),
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (value) {
          if (value == 0) {
            ref.read(_adminTabProvider.notifier).state = 0;
            return;
          }
          if (value == 1) {
            ref.read(_adminTabProvider.notifier).state = 4;
            return;
          }
          if (value == 2) {
            ref.read(_adminTabProvider.notifier).state = 5;
            return;
          }
          _openAdminMenu(context, ref);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(
              icon: Icon(Icons.content_copy), label: 'Content'),
          NavigationDestination(
              icon: Icon(Icons.payments_outlined), label: 'Revenue'),
          NavigationDestination(
              icon: Icon(Icons.menu), label: 'Menu'),
        ],
      ),
    );
  }

  int _navIndexForTab(int tabIndex) {
    if (tabIndex == 0) {
      return 0;
    }
    if (tabIndex == 4) {
      return 1;
    }
    if (tabIndex == 5) {
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
                leading: const Icon(Icons.shield),
                title: const Text('Moderate signals'),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(_adminTabProvider.notifier).state = 1;
                },
              ),
              ListTile(
                leading: const Icon(Icons.report),
                title: const Text('Reports'),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(_adminTabProvider.notifier).state = 2;
                },
              ),
              ListTile(
                leading: const Icon(Icons.people),
                title: const Text('Users'),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(_adminTabProvider.notifier).state = 3;
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
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
    final openSignals = ref.watch(_signalStatusProvider('open'));
    final hiddenSignals = ref.watch(_signalStatusProvider('hidden'));
    final openReports = ref.watch(_reportsStatusProvider('open'));
    final users = ref.watch(_adminUsersProvider);
    final revenueStats = ref.watch(_revenueStatsProvider);
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
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 12.0;
                  final width =
                      (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: width,
                        child: _DashboardMetricCard<Signal>(
                          label: 'Active signals',
                          state: openSignals,
                          accent: tokens.success,
                          icon: Icons.trending_up,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _DashboardMetricCard<Signal>(
                          label: 'Hidden signals',
                          state: hiddenSignals,
                          accent: tokens.warning,
                          icon: Icons.visibility_off,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _DashboardWideMetricCard<ReportItem>(
                label: 'Open reports',
                state: openReports,
                accent: colorScheme.error,
                icon: Icons.report,
              ),
              const SizedBox(height: 12),
              _RevenueSnapshotCard(state: revenueStats),
              const SizedBox(height: 16),
              _DashboardCountTile(
                label: 'Traders',
                value: traderCount,
                icon: Icons.groups,
                accent: colorScheme.primary,
                onTap: () =>
                    ref.read(_adminTabProvider.notifier).state = 3,
              ),
              const SizedBox(height: 12),
              _DashboardCountTile(
                label: 'Members',
                value: memberCount,
                icon: Icons.person_outline,
                accent: colorScheme.secondary,
                onTap: () =>
                    ref.read(_adminTabProvider.notifier).state = 3,
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
                  final width =
                      (constraints.maxWidth - spacing) / 2;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      SizedBox(
                        width: width,
                        child: _QuickActionCard(
                          label: 'Moderate signals',
                          icon: Icons.shield_outlined,
                          color: colorScheme.primary,
                          onTap: () => ref
                              .read(_adminTabProvider.notifier)
                              .state = 1,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _QuickActionCard(
                          label: 'Review reports',
                          icon: Icons.description_outlined,
                          color: colorScheme.tertiary,
                          onTap: () => ref
                              .read(_adminTabProvider.notifier)
                              .state = 2,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _QuickActionCard(
                          label: 'Manage users',
                          icon: Icons.group_outlined,
                          color: tokens.success,
                          onTap: () => ref
                              .read(_adminTabProvider.notifier)
                              .state = 3,
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _QuickActionCard(
                          label: 'Session settings',
                          icon: Icons.settings_outlined,
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
                          icon: Icons.payments_outlined,
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
              const SizedBox(height: 12),
              _PendingTradersCard(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PendingTradersScreen(),
                    ),
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
                _MetricIcon(icon: Icons.payments_outlined, color: tokens.success),
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
            const Icon(Icons.chevron_right),
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

class _PendingTradersCard extends StatelessWidget {
  const _PendingTradersCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              tokens.heroStart.withOpacity(0.95),
              tokens.heroEnd.withOpacity(0.9),
            ],
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_search, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Pending traders',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

class ModerateSignalsTab extends ConsumerWidget {
  const ModerateSignalsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Hidden'),
              Tab(text: 'Reported'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _SignalModerationList(status: 'open'),
                _SignalModerationList(status: 'hidden'),
                _ReportListTab(status: 'open'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignalModerationList extends ConsumerWidget {
  const _SignalModerationList({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signalsState = ref.watch(_signalStatusProvider(status));
    return signalsState.when(
      data: (signals) {
        if (signals.isEmpty) {
          return const Center(child: Text('No signals.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: signals.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final signal = signals[index];
            return ListTile(
              title: Text('${signal.pair} (${signal.direction})'),
              subtitle: Text('Status: ${_signalStatusLabel(signal.status)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              SignalDetailScreen(signalId: signal.id),
                        ),
                      );
                    },
                    child: const Text('Resolve'),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'view') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SignalDetailScreen(signalId: signal.id),
                          ),
                        );
                      } else if (value == 'resolve') {
                        final outcome = await _selectOutcome(context);
                        if (outcome != null) {
                          await _resolveSignal(ref, signal, outcome, context);
                        }
                      } else if (value == 'toggle') {
                        await ref.read(signalRepositoryProvider).updateSignal(
                          signal.id,
                          {
                            'status':
                                signal.status == 'hidden' ? 'open' : 'hidden',
                            'updatedAt': FieldValue.serverTimestamp(),
                          },
                        );
                      }
                    },
                    itemBuilder: (context) {
                      return [
                        const PopupMenuItem(value: 'view', child: Text('View')),
                        PopupMenuItem(value: 'resolve', child: Text('Resolve')),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(
                              signal.status == 'hidden' ? 'Unhide' : 'Hide'),
                        ),
                      ];
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: FirestoreErrorWidget(
          error: error,
          stackTrace: stack,
          title: 'Signals failed to load',
        ),
      ),
    );
  }

  Future<void> _resolveSignal(
    WidgetRef ref,
    Signal signal,
    String outcome,
    BuildContext context,
  ) async {
    try {
      await ref.read(signalRepositoryProvider).updateSignal(
        signal.id,
        {
          'status': 'resolved',
          'resolvedBy': 'admin',
          'resolvedAt': FieldValue.serverTimestamp(),
          'finalOutcome': outcome,
          'lockVotes': true,
          'voteAgg.consensusOutcome': outcome,
          'voteAgg.consensusConfidence': 1.0,
        },
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signal resolved')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to resolve: $error')),
        );
      }
    }
  }
}

class _ReportListTab extends ConsumerWidget {
  const _ReportListTab({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authStateProvider).when(
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Sign in to view reports.'));
            }
            return ref.watch(currentUserProvider).when(
                  data: (profile) {
                    if (profile == null || !isAdmin(profile.role)) {
                      return const Center(
                          child: Text('Admin access required.'));
                    }
                    final reportsState =
                        ref.watch(_reportsStatusProvider(status));
                    return reportsState.when(
                      data: (reports) {
                        if (reports.isEmpty) {
                          return const Center(child: Text('No reports.'));
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: reports.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final report = reports[index];
                            return ListTile(
                              title: Text(
                                  '${report.targetType} · ${report.reason}'),
                              subtitle: Text(report.details),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'close') {
                                    await ref
                                        .read(reportRepositoryProvider)
                                        .closeReport(report.id);
                                  } else if (value == 'unhide' &&
                                      report.targetType == 'signal') {
                                    await ref
                                        .read(signalRepositoryProvider)
                                        .updateSignal(
                                      report.targetId,
                                      {'status': 'open'},
                                    );
                                    await ref
                                        .read(reportRepositoryProvider)
                                        .closeReport(report.id);
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'close',
                                    child: Text('Close report'),
                                  ),
                                  if (report.targetType == 'signal')
                                    const PopupMenuItem(
                                      value: 'unhide',
                                      child: Text('Unhide signal'),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => Center(
                        child: FirestoreErrorWidget(
                          error: error,
                          stackTrace: stack,
                          title: 'Reports failed to load',
                        ),
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, stack) => Center(
                    child: FirestoreErrorWidget(
                      error: error,
                      stackTrace: stack,
                      title: 'Report profile failed',
                    ),
                  ),
                );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: FirestoreErrorWidget(
              error: error,
              stackTrace: stack,
              title: 'Reports access failed',
            ),
          ),
        );
  }
}

class ReportManagementTab extends ConsumerWidget {
  const ReportManagementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Open'),
              Tab(text: 'Closed'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ReportListTab(status: 'open'),
                _ReportListTab(status: 'closed'),
              ],
            ),
          ),
        ],
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
  final Set<String> _roleFilter = {};

  @override
  void dispose() {
    super.dispose();
  }

  void _toggleRole(String role) {
    setState(() {
      if (_roleFilter.contains(role)) {
        _roleFilter.remove(role);
      } else {
        _roleFilter.add(role);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(_adminUsersProvider);
    final search =
        ref.watch(_adminUserSearchQueryProvider).trim().toLowerCase();
    final tokens = AppThemeTokens.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          AppSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage users',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['member', 'trader', 'admin']
                      .map(
                        (role) => FilterChip(
                          label: Text(roleLabel(role)),
                          selected: _roleFilter.contains(role),
                          onSelected: (_) => _toggleRole(role),
                        ),
                      )
                      .toList(),
                ),
                if (_roleFilter.isNotEmpty || search.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Text(
                          'Filters active',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: tokens.mutedText,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(_adminUserSearchQueryProvider.notifier)
                                .state = '';
                            _roleFilter.clear();
                            setState(() {});
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                usersState.maybeWhen(
                  data: (users) {
                    final filtered = users.where((user) {
                      final matchesSearch = search.isEmpty ||
                          user.displayName.toLowerCase().contains(search) ||
                          user.username.toLowerCase().contains(search);
                      final matchesRole = _roleFilter.isEmpty ||
                          _roleFilter.contains(normalizeRole(user.role));
                      return matchesSearch && matchesRole;
                    }).toList();
                    final traderCount = users
                        .where((user) => normalizeRole(user.role) == 'trader')
                        .length;
                    final memberCount = users
                        .where((user) => normalizeRole(user.role) == 'member')
                        .length;
                    final adminCount = users
                        .where((user) => normalizeRole(user.role) == 'admin')
                        .length;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _UserCountChip(
                          label: 'Total',
                          value: users.length.toString(),
                        ),
                        _UserCountChip(
                          label: 'Showing',
                          value: filtered.length.toString(),
                        ),
                        _UserCountChip(
                          label: 'Traders',
                          value: traderCount.toString(),
                        ),
                        _UserCountChip(
                          label: 'Members',
                          value: memberCount.toString(),
                        ),
                        _UserCountChip(
                          label: 'Admins',
                          value: adminCount.toString(),
                        ),
                      ],
                    );
                  },
                  orElse: () => Row(
                    children: [
                      _UserCountChip(label: 'Total', value: '...'),
                      const SizedBox(width: 8),
                      _UserCountChip(label: 'Showing', value: '...'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: usersState.when(
              data: (users) {
                final filtered = users.where((user) {
                  final matchesSearch = search.isEmpty ||
                      user.displayName.toLowerCase().contains(search) ||
                      user.username.toLowerCase().contains(search);
                  final matchesRole = _roleFilter.isEmpty ||
                      _roleFilter.contains(normalizeRole(user.role));
                  return matchesSearch && matchesRole;
                }).toList();
                return filtered.isEmpty
                    ? const Center(child: Text('No users match.'))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
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

class _UserItemTile extends ConsumerWidget {
  const _UserItemTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final displayName = user.displayName.isNotEmpty ? user.displayName : 'User';
    final username = user.username.isNotEmpty ? '@${user.username}' : 'No username';
    final role = normalizeRole(user.role);
    final traderStatus =
        role == 'trader' ? user.traderStatus : null;

    return AppSectionCard(
      padding: EdgeInsets.zero,
      useShadow: false,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: CircleAvatar(
            radius: 20,
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
                  Icons.verified,
                  size: 14,
                  color: tokens.success,
                ),
              ],
              if (user.isBanned) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.block,
                  size: 14,
                  color: Colors.redAccent,
                ),
              ],
            ],
          ),
          subtitle: Text(
            '$username · ${roleLabel(role)}',
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
                      ref.read(userRepositoryProvider).updateUser(user.uid, {
                        'role': value,
                      });
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
                  icon: Icons.verified,
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
                  icon: Icons.block,
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
    final textColor =
        color == tokens.mutedText ? tokens.mutedText : color;
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
      ref.read(_adminUserSearchQueryProvider.notifier).state =
          _controller.text;
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
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
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
            trailing: const Icon(Icons.arrow_forward),
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
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const BrokerManagerScreen()),
              );
            },
          ),
        ),
        Card(
          child: ListTile(
            title: const Text('Session settings'),
            subtitle: const Text('Configure trading session durations'),
            trailing: const Icon(Icons.arrow_forward),
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

Future<String?> _selectOutcome(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Select final outcome'),
      content: Wrap(
        spacing: 8,
        children: ['TP', 'SL', 'BE', 'PARTIAL']
            .map(
              (outcome) => ElevatedButton(
                onPressed: () => Navigator.of(context).pop(outcome),
                child: Text(outcome),
              ),
            )
            .toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    ),
  );
}

String _signalStatusLabel(String status) {
  final normalized = status.toLowerCase();
  if (normalized == 'voting') {
    return 'closed';
  }
  return status.replaceAll('_', ' ');
}
