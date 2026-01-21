import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/signal.dart';
import '../../../core/repositories/signal_repository.dart';

class SignalFeedFilter {
  final String? session;
  final String? pair;
  static const Object _unset = Object();

  const SignalFeedFilter({
    this.session,
    this.pair,
  });

  SignalFeedFilter copyWith({
    String? session,
    Object? pair = _unset,
  }) {
    return SignalFeedFilter(
      session: session ?? this.session,
      pair: pair == _unset ? this.pair : pair as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SignalFeedFilter &&
        other.session == session &&
        other.pair == pair;
  }

  @override
  int get hashCode => Object.hash(session, pair);
}

class SignalFeedState {
  final List<Signal> signals;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  final SignalFeedFilter filter;

  const SignalFeedState({
    required this.signals,
    required this.lastDoc,
    required this.hasMore,
    required this.filter,
  });

  SignalFeedState copyWith({
    List<Signal>? signals,
    DocumentSnapshot<Map<String, dynamic>>? lastDoc,
    bool? hasMore,
    SignalFeedFilter? filter,
  }) {
    return SignalFeedState(
      signals: signals ?? this.signals,
      lastDoc: lastDoc ?? this.lastDoc,
      hasMore: hasMore ?? this.hasMore,
      filter: filter ?? this.filter,
    );
  }
}

final signalFeedFilterProvider = StateProvider<SignalFeedFilter>((ref) {
  return const SignalFeedFilter();
});

final signalFeedControllerProvider = StateNotifierProvider.family<
    SignalFeedController,
    AsyncValue<SignalFeedState>,
    SignalFeedFilter>((ref, filter) {
  return SignalFeedController(
    ref.read(signalRepositoryProvider),
    filter,
  );
});

class SignalFeedController extends StateNotifier<AsyncValue<SignalFeedState>> {
  SignalFeedController(this._repository, this._filter)
      : super(const AsyncValue.loading()) {
    loadInitial();
  }

  final SignalRepository _repository;
  final SignalFeedFilter _filter;

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    try {
      final page = await _repository.fetchSignalsPage(
        limit: 20,
        session: _filter.session,
        pair: _filter.pair,
      );
      state = AsyncValue.data(SignalFeedState(
        signals: page.signals,
        lastDoc: page.lastDoc,
        hasMore: page.hasMore,
        filter: _filter,
      ));
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore) {
      return;
    }
    try {
      final page = await _repository.fetchSignalsPage(
        limit: 20,
        startAfter: current.lastDoc,
        session: _filter.session,
        pair: _filter.pair,
      );
      state = AsyncValue.data(current.copyWith(
        signals: [...current.signals, ...page.signals],
        lastDoc: page.lastDoc,
        hasMore: page.hasMore,
        filter: _filter,
      ));
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}
