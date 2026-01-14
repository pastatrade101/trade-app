import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/affiliate.dart';

Future<void> openAffiliateLink(
  BuildContext context,
  WidgetRef ref,
  Affiliate affiliate,
) async {
  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Leaving the app'),
        content: Text(
          affiliate.disclaimer ??
              'This is a third-party partner link. We may earn a commission. '
                  'This is not financial advice.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      );
    },
  );

  if (proceed != true) {
    return;
  }

  final url = affiliate.url.trim();
  Uri? uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    uri = Uri.tryParse('https://$url');
  }
  if (uri == null || uri.host.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invalid affiliate URL')),
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
