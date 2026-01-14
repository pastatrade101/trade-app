import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/models/broker.dart';
import '../../core/utils/role_helpers.dart';

final activeBrokersProvider = StreamProvider<List<Broker>>((ref) {
  return ref.watch(brokerRepositoryProvider).watchActive();
});

final adminBrokersProvider = StreamProvider<List<Broker>>((ref) {
  final profile = ref.watch(currentUserProvider).value;
  if (!isAdmin(profile?.role)) {
    return const Stream<List<Broker>>.empty();
  }
  return ref.watch(brokerRepositoryProvider).watchAll();
});
