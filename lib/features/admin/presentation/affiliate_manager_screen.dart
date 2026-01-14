import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/broker.dart';
import '../../../core/widgets/firestore_error_widget.dart';
import '../../partners/providers.dart';
import '../../../app/providers.dart';
import 'affiliate_form_screen.dart';

class BrokerManagerScreen extends ConsumerStatefulWidget {
  const BrokerManagerScreen({super.key});

  @override
  ConsumerState<BrokerManagerScreen> createState() =>
      _BrokerManagerScreenState();
}

class _BrokerManagerScreenState extends ConsumerState<BrokerManagerScreen> {
  String _search = '';
  _VisibilityFilter _filter = _VisibilityFilter.all;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setSearch(String text) {
    setState(() => _search = text.trim());
  }

  void _openForm([Broker? broker]) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BrokerFormScreen(broker: broker),
      ),
    );
  }

  void _toggleActive(Broker broker) {
    ref.read(brokerRepositoryProvider).toggleActive(broker.id, !broker.isActive);
  }

  void _deleteBroker(Broker broker) async {
    await ref.read(brokerRepositoryProvider).deleteBroker(broker.id);
  }

  bool _matchesFilter(Broker broker) {
    final matchesSearch = _search.isEmpty ||
        broker.name.toLowerCase().contains(_search.toLowerCase()) ||
        broker.description.toLowerCase().contains(_search.toLowerCase());
    if (!matchesSearch) {
      return false;
    }
    switch (_filter) {
      case _VisibilityFilter.all:
        return true;
      case _VisibilityFilter.active:
        return broker.isActive;
      case _VisibilityFilter.inactive:
        return !broker.isActive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brokersState = ref.watch(adminBrokersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Broker manager')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _setSearch,
              decoration: const InputDecoration(
                labelText: 'Search brokers',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<_VisibilityFilter>(
                    value: _filter,
                    decoration: const InputDecoration(labelText: 'Visibility'),
                    items: _VisibilityFilter.values
                        .map((filter) => DropdownMenuItem(
                              value: filter,
                              child: Text(filter.label),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _filter = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: brokersState.when(
              data: (brokers) {
                final filtered = brokers.where(_matchesFilter).toList();
                if (filtered.isEmpty) {
                  return const Center(child: Text('No brokers match.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final broker = filtered[index];
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: broker.logoUrl != null
                                  ? CircleAvatar(
                                      foregroundImage:
                                          NetworkImage(broker.logoUrl!))
                                  : const CircleAvatar(child: Icon(Icons.business)),
                              title: Text(broker.name),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _openForm(broker);
                                  } else if (value == 'delete') {
                                    _deleteBroker(broker);
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                      value: 'edit', child: Text('Edit')),
                                  const PopupMenuItem(
                                      value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                broker.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                FilterChip(
                                  label: const Text('Active'),
                                  selected: broker.isActive,
                                  onSelected: (_) => _toggleActive(broker),
                                ),
                                const Spacer(),
                                Text('Sort ${broker.sortOrder}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ElevatedButton(
                                onPressed: () => _openForm(broker),
                                child: const Text('Edit'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: FirestoreErrorWidget(
                  error: error,
                  stackTrace: stack,
                  title: 'Brokers failed to load',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _VisibilityFilter {
  all,
  active,
  inactive,
}

extension on _VisibilityFilter {
  String get label {
    switch (this) {
      case _VisibilityFilter.all:
        return 'All';
      case _VisibilityFilter.active:
        return 'Active';
      case _VisibilityFilter.inactive:
        return 'Inactive';
    }
  }
}
