import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/app_user.dart';
import '../../../core/models/testimonial.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_section_card.dart';
import '../../../core/widgets/firestore_error_widget.dart';
import 'testimonial_form_screen.dart';

class TestimonialsScreen extends ConsumerWidget {
  const TestimonialsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final isTrader = user?.role == 'trader';
    final repo = ref.watch(testimonialRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('What members are saying'),
        elevation: 2,
        shadowColor: Colors.black12,
        actions: [
          if (isTrader)
            IconButton(
              tooltip: 'Submit testimonial',
              icon: const Icon(Icons.post_add),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TestimonialFormScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<List<Testimonial>>(
        stream: repo.watchPublished(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return FirestoreErrorWidget(
              error: snapshot.error!,
              stackTrace: snapshot.stackTrace,
              title: 'Unable to load testimonials',
            );
          }
          final testimonials = snapshot.data ?? [];
          final loading = snapshot.connectionState == ConnectionState.waiting;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (isTrader && user != null) ...[
                _TraderSubmissionSection(user: user),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 12),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (testimonials.isEmpty)
                const Text('No testimonials published yet.')
              else
                ...testimonials.map(
                  (testimonial) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TestimonialCard(testimonial: testimonial),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TraderSubmissionSection extends ConsumerWidget {
  const _TraderSubmissionSection({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(testimonialRepositoryProvider);
    return StreamBuilder<List<Testimonial>>(
      stream: repo.watchByAuthor(user.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        final items = snapshot.data ?? [];
        final visible = items.take(3).toList();
        return AppSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSectionTitle(title: 'Your submissions'),
              const SizedBox(height: 8),
              Text(
                'New testimonials go live immediately. Edit or delete anytime.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Text('No testimonials submitted yet.')
              else
                ...visible.map(
                  (testimonial) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TestimonialCard(
                      testimonial: testimonial,
                      showStatus: true,
                      actions: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => TestimonialFormScreen(
                                  testimonial: testimonial,
                                ),
                              ),
                            );
                          },
                          child: const Text('Edit'),
                        ),
                        TextButton(
                          onPressed: () async {
                            final shouldDelete = await _confirmDelete(context);
                            if (shouldDelete != true) {
                              return;
                            }
                            final repo =
                                ref.read(testimonialRepositoryProvider);
                            await repo.delete(testimonial);
                          },
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  const _TestimonialCard({
    required this.testimonial,
    this.showStatus = false,
    this.actions = const [],
  });

  final Testimonial testimonial;
  final bool showStatus;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final proofUrl = testimonial.proofImageUrl ?? '';
    final hasProof = proofUrl.isNotEmpty;
    final createdText = formatTanzaniaDateTime(testimonial.createdAt);
    return AppSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  testimonial.title.isEmpty
                      ? 'Testimonial'
                      : testimonial.title,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showStatus)
                _StatusPill(
                  label: testimonial.status,
                  color: _statusColor(testimonial.status, tokens),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            testimonial.message,
            style: textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '- ${testimonial.authorName}',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                createdText,
                style: textTheme.labelSmall?.copyWith(
                  color: tokens.mutedText,
                ),
              ),
            ],
          ),
          if (hasProof) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _openProof(context, proofUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  proofUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actions,
            ),
          ],
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
