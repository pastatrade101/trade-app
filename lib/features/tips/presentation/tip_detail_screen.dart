import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../app/app_theme.dart';
import '../../../core/models/tip.dart';
import '../../../core/widgets/app_section_card.dart';
import 'tip_widgets.dart';

class TipDetailScreen extends ConsumerWidget {
  const TipDetailScreen({
    super.key,
    required this.tipId,
    this.initialTip,
  });

  final String tipId;
  final TraderTip? initialTip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tipStream = ref.read(tipRepositoryProvider).watchTip(tipId);
    return StreamBuilder<TraderTip?>(
      stream: tipStream,
      builder: (context, snapshot) {
        final tip = snapshot.data ?? initialTip;
        if (tip == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = ref.watch(currentUserProvider).value;
        final textTheme = Theme.of(context).textTheme;
        final muted = AppThemeTokens.of(context).mutedText;
        final formattedDate = DateFormat.yMMMd().format(tip.createdAt);

        return Scaffold(
          appBar: AppBar(title: const Text('Tip details')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                tip.title,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Chip(label: tip.type),
                  ...tip.tags.map((tag) => _Chip(label: tag)),
                ],
              ),
              const SizedBox(height: 16),
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle(title: 'Idea'),
                    const SizedBox(height: 8),
                    Text(
                      tip.content,
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (tip.imageUrl != null && tip.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _showImagePreview(context, tip.imageUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      tip.imageUrl!,
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppSectionTitle(title: 'Action'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: AppThemeTokens.of(context).surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppThemeTokens.of(context).border,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.flash_on,
                            size: 18,
                            color: AppThemeTokens.of(context).warning,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tip.action,
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TipInteractionsRow(
                tip: tip,
                currentUser: user,
              ),
              const SizedBox(height: 16),
              Text(
                'By ${tip.authorName} · $formattedDate',
                style: textTheme.bodySmall?.copyWith(color: muted),
              ),
              const SizedBox(height: 8),
              const TipDisclaimer(),
            ],
          ),
        );
      },
    );
  }

  void _showImagePreview(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
