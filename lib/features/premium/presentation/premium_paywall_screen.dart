import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import 'plan_selection_screen.dart';

class PremiumPaywallScreen extends StatelessWidget {
  const PremiumPaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Premium Membership')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock premium signals',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Upgrade to see full entry, stop loss, take profits, and trader reasoning. Choose daily, weekly, or monthly access.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tokens.mutedText,
                  ),
            ),
            const SizedBox(height: 20),
            _BenefitTile(
              icon: Icons.lock_open,
              title: 'Premium signals',
              subtitle: 'View full signal details instantly.',
            ),
            const SizedBox(height: 12),
            const _BenefitTile(
              icon: Icons.notifications_active,
              title: 'Faster alerts',
              subtitle: 'Be first to see high-confidence setups.',
            ),
            const SizedBox(height: 12),
            const _BenefitTile(
              icon: Icons.lightbulb_outline,
              title: 'Premium tips',
              subtitle: 'Get extra market insights and trade ideas.',
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PlanSelectionScreen(),
                    ),
                  );
                },
                child: const Text('Upgrade'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = AppThemeTokens.of(context);
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: primaryColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      color: tokens.mutedText,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
