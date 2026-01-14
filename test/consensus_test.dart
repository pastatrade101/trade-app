import 'package:flutter_test/flutter_test.dart';

import 'package:stock_investment_flutter/core/models/vote_aggregate.dart';
import 'package:stock_investment_flutter/core/utils/consensus.dart';

void main() {
  test('Consensus resolves when thresholds are met', () {
    final agg = VoteAggregate(
      tpCount: 4,
      slCount: 1,
      beCount: 0,
      partialCount: 0,
      totalVotes: 5,
      tpWeight: 4.0,
      slWeight: 1.0,
      beWeight: 0.0,
      partialWeight: 0.0,
      totalWeight: 5.0,
      consensusOutcome: null,
      consensusConfidence: 0,
    );

    final result = computeConsensus(agg, minWeight: 5, minAgreement: 0.7);

    expect(result.shouldResolve, true);
    expect(result.outcome, 'TP');
  });

  test('Consensus does not resolve when below min votes', () {
    final agg = VoteAggregate(
      tpCount: 2,
      slCount: 1,
      beCount: 0,
      partialCount: 0,
      totalVotes: 3,
      tpWeight: 2.0,
      slWeight: 1.0,
      beWeight: 0.0,
      partialWeight: 0.0,
      totalWeight: 3.0,
      consensusOutcome: null,
      consensusConfidence: 0,
    );

    final result = computeConsensus(agg, minWeight: 5, minAgreement: 0.7);

    expect(result.shouldResolve, false);
  });
}
