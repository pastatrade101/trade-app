import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/models/report.dart';

class ReportDialog extends ConsumerStatefulWidget {
  const ReportDialog({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  final _detailsController = TextEditingController();
  String? _reason;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) {
      return;
    }
    if (_reason == null) {
      setState(() => _error = 'Select a reason');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final report = ReportItem(
      id: '',
      reporterUid: user.uid,
      targetType: widget.targetType,
      targetId: widget.targetId,
      reason: _reason!,
      details: _detailsController.text.trim(),
      status: 'open',
      createdAt: DateTime.now(),
    );

    try {
      await ref.read(reportRepositoryProvider).createReport(report);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _reason,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: AppConstants.reportReasons
                .map((reason) =>
                    DropdownMenuItem(value: reason, child: Text(reason)))
                .toList(),
            onChanged: (value) => setState(() => _reason = value),
          ),
          TextField(
            controller: _detailsController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Details'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child:
              _loading ? const CircularProgressIndicator() : const Text('Send'),
        ),
      ],
    );
  }
}
