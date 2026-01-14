import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/signal.dart';
import '../../home/presentation/signal_detail_screen.dart';

class SignalModerationScreen extends ConsumerWidget {
  const SignalModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hiddenSignals =
        ref.watch(signalRepositoryProvider).watchSignalsByStatus('hidden');

    return Scaffold(
      appBar: AppBar(title: const Text('Hidden signals')),
      body: StreamBuilder<List<Signal>>(
        stream: hiddenSignals,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final signals = snapshot.data!;
          if (signals.isEmpty) {
            return const Center(child: Text('No hidden signals.'));
          }
          return ListView.builder(
            itemCount: signals.length,
            itemBuilder: (context, index) {
              final signal = signals[index];
              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text('${signal.pair} ${signal.direction}'),
                  subtitle: Text('Reasoning: ${signal.reasoning}'),
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
                        child: const Text('Resolve',
                            style: TextStyle(fontSize: 12)),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'unhide') {
                            await ref
                                .read(signalRepositoryProvider)
                                .updateSignal(signal.id, {'status': 'open'});
                          } else if (value == 'resolve') {
                            final outcome = await showDialog<String>(
                              context: context,
                              builder: (_) => const _ResolveDialog(),
                            );
                            if (outcome == null) {
                              return;
                            }
                            await ref
                                .read(signalRepositoryProvider)
                                .updateSignal(
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
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'unhide', child: Text('Unhide')),
                          PopupMenuItem(
                              value: 'resolve', child: Text('Mark resolved')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ResolveDialog extends StatelessWidget {
  const _ResolveDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Final outcome'),
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
    );
  }
}
