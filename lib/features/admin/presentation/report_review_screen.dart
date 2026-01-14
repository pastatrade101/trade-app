import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/report.dart';
import '../../../core/widgets/firestore_error_widget.dart';

class ReportReviewScreen extends ConsumerWidget {
  const ReportReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsStream =
        ref.watch(reportRepositoryProvider).watchOpenReports();

    return Scaffold(
      appBar: AppBar(title: const Text('Open reports')),
      body: StreamBuilder<List<ReportItem>>(
        stream: reportsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: FirestoreErrorWidget(
                error: snapshot.error ?? 'Unknown error',
                stackTrace: snapshot.stackTrace,
                title: 'Reports failed to load',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final reports = snapshot.data!;
          if (reports.isEmpty) {
            return const Center(child: Text('No open reports.'));
          }
          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return Card(
                margin: const EdgeInsets.all(12),
                child: ListTile(
                  title: Text('${report.targetType} - ${report.reason}'),
                  subtitle: Text(report.details),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'close') {
                        await ref
                            .read(reportRepositoryProvider)
                            .closeReport(report.id);
                      }
                      if (value == 'unhide' && report.targetType == 'signal') {
                        await ref.read(signalRepositoryProvider).updateSignal(
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
                ),
              );
            },
          );
        },
      ),
    );
  }
}
