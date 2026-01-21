import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_theme.dart';
import '../../../core/models/broker.dart';
import '../../../core/widgets/app_section_card.dart';
import '../providers.dart';
import 'package:stock_investment_flutter/app/app_icons.dart';

class PartnersTab extends ConsumerWidget {
  const PartnersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final brokersState = ref.watch(activeBrokersProvider);
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Trusted Brokers')),
      body: brokersState.when(
        data: (brokers) {
          if (brokers.isEmpty) {
            return const Center(child: Text('No brokers available yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: brokers.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == brokers.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  child: Text(
                    'Disclaimer: We may receive an affiliate commission if you register with a broker. '
                    'This is not financial advice.',
                    style: TextStyle(
                      color: tokens.mutedText,
                      fontSize: 12,
                    ),
                  ),
                );
              }
              final broker = brokers[index];
              return AppSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (broker.logoUrl != null)
                          CircleAvatar(
                            radius: 24,
                            foregroundImage: NetworkImage(broker.logoUrl!),
                            backgroundColor: Colors.transparent,
                          )
                        else
                          const CircleAvatar(
                            radius: 24,
                            child: Icon(AppIcons.business),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            broker.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      broker.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.mutedText),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: () => _openBrokerLink(context, broker),
                        child: Text('Register on ${broker.name}'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Unable to load brokers: $error')),
      ),
    );
  }

  Future<void> _openBrokerLink(BuildContext context, Broker broker) async {
    final url = broker.affiliateUrl.trim();
    Uri? uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      uri = Uri.tryParse('https://$url');
    }
    if (uri == null || uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid broker URL')),
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
}
