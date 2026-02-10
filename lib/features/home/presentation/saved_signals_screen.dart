import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/signal.dart';
import '../../../core/widgets/app_reveal.dart';
import '../../../core/widgets/app_shimmer.dart';
import 'signal_card.dart';
import 'signal_detail_screen.dart';

class SavedSignalsScreen extends ConsumerWidget {
  const SavedSignalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view saved signals.')),
      );
    }
    if (user.role == 'admin') {
      return const Scaffold(
        body: Center(child: Text('Admins cannot save signals.')),
      );
    }

    final repo = ref.read(signalRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved signals')),
      body: StreamBuilder(
        stream: repo.watchSavedSignals(user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SavedSignalsLoading();
          }
          final saved = snapshot.data ?? const [];
          if (saved.isEmpty) {
            return const Center(child: Text('No saved signals yet.'));
          }
          final ids = saved.map((item) => item.signalId).toList();
          return FutureBuilder<List<Signal>>(
            future: repo.fetchSignalsByIds(ids),
            builder: (context, signalSnapshot) {
              if (signalSnapshot.connectionState == ConnectionState.waiting) {
                return const _SavedSignalsLoading();
              }
              final signals = signalSnapshot.data ?? const <Signal>[];
              final byId = {for (final signal in signals) signal.id: signal};
              final now = DateTime.now();
              final ordered = saved
                  .map((item) => byId[item.signalId])
                  .whereType<Signal>()
                  .where((signal) => signal.validUntil.isAfter(now))
                  .toList();
              if (ordered.isEmpty) {
                return const Center(child: Text('Saved signals not found.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                itemCount: ordered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final signal = ordered[index];
                  return AppReveal(
                    delay: Duration(milliseconds: 40 * (index % 6)),
                    child: SignalCard(
                      signal: signal,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                SignalDetailScreen(signalId: signal.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedSignalsLoading extends StatelessWidget {
  const _SavedSignalsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: const [
        AppShimmerBox(height: 140, radius: 20),
        SizedBox(height: 12),
        AppShimmerBox(height: 140, radius: 20),
        SizedBox(height: 12),
        AppShimmerBox(height: 140, radius: 20),
      ],
    );
  }
}
