import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_constants.dart';
import '../data/signal_feed_controller.dart';

class SignalFilters extends ConsumerWidget {
  const SignalFilters({super.key, required this.onChanged});

  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(signalFeedFilterProvider);
    final pairItems = <String?>[null, ...AppConstants.instruments];
    final pairLabels = <String>['All Pairs', ...AppConstants.instruments];
    final directionItems = <String?>[null, ...AppConstants.directionOptions];
    final directionLabels = <String>[
      'All Directions',
      ...AppConstants.directionOptions
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: filter.pair,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All Pairs',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  items: pairItems
                      .map(
                        (pair) => DropdownMenuItem(
                          value: pair,
                          child: Text(pair ?? 'All Pairs'),
                        ),
                      )
                      .toList(),
                  selectedItemBuilder: (context) => pairLabels
                      .map(
                        (label) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    ref.read(signalFeedFilterProvider.notifier).state =
                        filter.copyWith(pair: value);
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: filter.direction,
                  isExpanded: true,
                  decoration: InputDecoration(
                    hintText: 'All Directions',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  items: directionItems
                      .map(
                        (direction) => DropdownMenuItem(
                          value: direction,
                          child: Text(direction ?? 'All Directions'),
                        ),
                      )
                      .toList(),
                  selectedItemBuilder: (context) => directionLabels
                      .map(
                        (label) => Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    ref.read(signalFeedFilterProvider.notifier).state =
                        filter.copyWith(direction: value);
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
