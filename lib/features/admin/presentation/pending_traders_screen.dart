import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/app_theme.dart';
import '../../../core/models/app_user.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/firestore_error_widget.dart';

class PendingTradersScreen extends ConsumerWidget {
  const PendingTradersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicants =
        ref.watch(userRepositoryProvider).watchTraderApplicants();
    return Scaffold(
      appBar: AppBar(title: const Text('Pending traders')),
      body: StreamBuilder<List<AppUser>>(
        stream: applicants,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: FirestoreErrorWidget(
                error: snapshot.error ?? 'Unknown error',
                stackTrace: snapshot.stackTrace,
                title: 'Pending traders failed',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return const Center(child: Text('No pending traders.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final trader = list[index];
              return _PendingTraderTile(trader: trader);
            },
          );
        },
      ),
    );
  }
}

class _PendingTraderTile extends ConsumerWidget {
  const _PendingTraderTile({required this.trader});

  final AppUser trader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<String?>(
      future:
          ref.read(userRepositoryProvider).fetchPrivatePhoneNumber(trader.uid),
      builder: (context, snapshot) {
        final phone = snapshot.data;
        final socials = trader.socials.entries.toList();
        final appliedText = DateFormat('MMM d, yyyy').format(trader.createdAt);
        final displayName =
            trader.displayName.isNotEmpty ? trader.displayName : 'Trader';
        final username =
            trader.username.isNotEmpty ? '@${trader.username}' : 'No username';
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: tokens.surfaceAlt,
                      child: Text(
                        _initials(displayName),
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: tokens.mutedText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            username,
                            style: textTheme.bodySmall?.copyWith(
                              color: tokens.mutedText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _InfoChip(label: 'Country', value: trader.country),
                              _InfoChip(label: 'Applied', value: appliedText),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(
                      label: 'Pending',
                      color: tokens.warning,
                    ),
                  ],
                ),
                if (trader.bio.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    trader.bio,
                    style: textTheme.bodySmall?.copyWith(
                      height: 1.4,
                      color: tokens.mutedText,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _SectionLabel(title: 'Sessions'),
                const SizedBox(height: 6),
                _TagWrap(values: trader.sessions),
                const SizedBox(height: 12),
                _SectionLabel(title: 'Instruments'),
                const SizedBox(height: 6),
                _TagWrap(values: trader.instruments),
                const SizedBox(height: 12),
                _SectionLabel(title: 'Contact'),
                const SizedBox(height: 6),
                if (snapshot.connectionState == ConnectionState.waiting)
                  Text(
                    'Loading contact info…',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                    ),
                  )
                else if ((phone == null || phone.isEmpty) && socials.isEmpty)
                  Text(
                    'No contact info provided.',
                    style: textTheme.bodySmall?.copyWith(
                      color: tokens.mutedText,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (phone != null && phone.trim().isNotEmpty)
                        _InfoChip(label: 'Phone', value: phone),
                      ...socials.map(
                        (entry) => _InfoChip(
                          label: entry.key,
                          value: entry.value,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await ref.read(userRepositoryProvider).updateTraderStatus(
                                uid: trader.uid,
                                status: 'active',
                              );
                          AppToast.success(context, 'Trader approved');
                        },
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          _showRejectDialog(context, ref);
                        },
                        child: const Text('Reject'),
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

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject trader'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(userRepositoryProvider).updateTraderStatus(
                    uid: trader.uid,
                    status: 'rejected',
                    rejectReason: controller.text.trim().isEmpty
                        ? null
                        : controller.text.trim(),
                  );
              Navigator.of(context).pop();
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    if (values.isEmpty) {
      return Text(
        'None listed',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: tokens.mutedText,
            ),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: values.map((value) => Chip(label: Text(value))).toList(),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.value});

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
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: tokens.mutedText,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) {
    return '?';
  }
  if (parts.length == 1) {
    return parts.first.characters.first.toUpperCase();
  }
  return (parts[0].characters.first + parts[1].characters.first)
      .toUpperCase();
}
