import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/testimonial.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/firestore_error_widget.dart';

class AdminTestimonialsScreen extends ConsumerWidget {
  const AdminTestimonialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Testimonials'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Published'),
              Tab(text: 'Unpublished'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _AdminTestimonialList(status: 'published'),
            _AdminTestimonialList(status: 'unpublished'),
          ],
        ),
      ),
    );
  }
}

class _AdminTestimonialList extends ConsumerWidget {
  const _AdminTestimonialList({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(testimonialRepositoryProvider);
    return StreamBuilder<List<Testimonial>>(
      stream: repo.watchByStatus(status),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return FirestoreErrorWidget(
            error: snapshot.error!,
            stackTrace: snapshot.stackTrace,
            title: 'Unable to load testimonials',
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Center(child: Text('No $status testimonials.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final testimonial = items[index];
            return _AdminTestimonialCard(
              testimonial: testimonial,
              status: status,
            );
          },
        );
      },
    );
  }
}

class _AdminTestimonialCard extends ConsumerWidget {
  const _AdminTestimonialCard({
    required this.testimonial,
    required this.status,
  });

  final Testimonial testimonial;
  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = AppThemeTokens.of(context);
    final createdText = formatTanzaniaDateTime(testimonial.createdAt);
    final proofUrl = testimonial.proofImageUrl ?? '';
    final hasProof = proofUrl.isNotEmpty;
    final repo = ref.read(testimonialRepositoryProvider);
    final admin = ref.read(currentUserProvider).value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    testimonial.title.isEmpty
                        ? 'Testimonial'
                        : testimonial.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                _StatusPill(label: status, color: _statusColor(status, tokens)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              testimonial.message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              '- ${testimonial.authorName} · $createdText',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: tokens.mutedText),
            ),
            if (hasProof) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => _openProof(context, proofUrl),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    proofUrl,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (status != 'published')
                  OutlinedButton(
                    onPressed: () async {
                      await repo.updateStatus(
                        testimonialId: testimonial.id,
                        status: 'published',
                        approvedBy: admin?.uid,
                      );
                    },
                    child: const Text('Publish'),
                  ),
                if (status == 'published')
                  OutlinedButton(
                    onPressed: () async {
                      await repo.updateStatus(
                        testimonialId: testimonial.id,
                        status: 'unpublished',
                        approvedBy: admin?.uid,
                      );
                    },
                    child: const Text('Unpublish'),
                  ),
                TextButton(
                  onPressed: () async {
                    final shouldDelete = await _confirmDelete(context);
                    if (shouldDelete != true) {
                      return;
                    }
                    await repo.delete(testimonial);
                  },
                  child: const Text('Delete'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete testimonial?'),
        content: const Text('This will permanently remove the testimonial.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _openProof(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: InteractiveViewer(
            child: Image.network(url, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Color _statusColor(String status, AppThemeTokens tokens) {
    switch (status) {
      case 'published':
        return tokens.success;
      case 'unpublished':
        return tokens.warning;
      default:
        return tokens.mutedText;
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
