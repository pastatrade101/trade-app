import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/models/signal.dart';
import '../../../core/repositories/signal_repository.dart';
import '../../../core/models/trading_session_config.dart';

class SignalFeedFilter {
  final String? session;
  final String? pair;
  final String? direction;

  const SignalFeedFilter({
    this.session,
    this.pair,
    this.direction,
  });

  SignalFeedFilter copyWith({
    String? session,
    String? pair,
    String? direction,
  }) {
    return SignalFeedFilter(
      session: session ?? this.session,
      pair: pair ?? this.pair,
      direction: direction ?? this.direction,
    );
  }
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
  return SignalFeedFilter(session: tradingSessionKeys.first);
});

final signalFeedControllerProvider =
    StateNotifierProvider<SignalFeedController, AsyncValue<SignalFeedState>>(
        (ref) {
  return SignalFeedController(
    ref.read(signalRepositoryProvider),
    ref,
  );
});

class SignalFeedController extends StateNotifier<AsyncValue<SignalFeedState>> {
  SignalFeedController(this._repository, this._ref)
      : super(const AsyncValue.loading()) {
    loadInitial();
  }

  final SignalRepository _repository;
  final Ref _ref;

  Future<void> loadInitial() async {
    state = const AsyncValue.loading();
    try {
      final filter = _ref.read(signalFeedFilterProvider);
      final page = await _repository.fetchSignalsPage(
        limit: 20,
        session: filter.session,
        pair: filter.pair,
        direction: filter.direction,
      );
      state = AsyncValue.data(SignalFeedState(
        signals: page.signals,
        lastDoc: page.lastDoc,
        hasMore: page.hasMore,
        filter: filter,
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
      final filter = _ref.read(signalFeedFilterProvider);
      final page = await _repository.fetchSignalsPage(
        limit: 20,
        startAfter: current.lastDoc,
        session: filter.session,
        pair: filter.pair,
        direction: filter.direction,
      );
      state = AsyncValue.data(current.copyWith(
        signals: [...current.signals, ...page.signals],
        lastDoc: page.lastDoc,
        hasMore: page.hasMore,
        filter: filter,
      ));
    } catch (error, stack) {
      state = AsyncValue.error(error, stack);
    }
  }
}
