import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import 'member_onboarding_screen.dart';

class RoleChoiceScreen extends ConsumerWidget {
  const RoleChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Get started')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Continue as a member',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              title: 'Member',
              description: 'View signals, learn from tips, and track outcomes.',
              benefits: const [
                'Learn from signals & tips',
                'Save signals and track outcomes',
              ],
              actionLabel: 'Continue as Member',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemberOnboardingScreen(uid: user.uid),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.description,
    required this.benefits,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final List<String> benefits;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(description),
            const SizedBox(height: 8),
            ...benefits.map((item) => Row(
                  children: [
                    const Icon(Icons.check, size: 16),
                    const SizedBox(width: 4),
                    Text(item),
                  ],
                )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onTap,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
