import '../models/vote_aggregate.dart';
import '../config/app_constants.dart';

class ConsensusResult {
  final bool shouldResolve;
  final String? outcome;
  final double confidence;

  const ConsensusResult({
    required this.shouldResolve,
    required this.outcome,
    required this.confidence,
  });
}

ConsensusResult computeConsensus(
  VoteAggregate aggregate, {
  double minWeight = AppConstants.minConsensusWeight,
  double minAgreement = AppConstants.minConsensusAgreement,
}) {
  if (aggregate.totalWeight < minWeight) {
    return const ConsensusResult(
      shouldResolve: false,
      outcome: null,
      confidence: 0,
    );
  }

  final weights = <String, double>{
    'TP': aggregate.tpWeight,
    'SL': aggregate.slWeight,
    'BE': aggregate.beWeight,
    'PARTIAL': aggregate.partialWeight,
  };

  String? topOutcome;
  double topWeight = 0;
  weights.forEach((key, value) {
    if (value > topWeight) {
      topWeight = value;
      topOutcome = key;
    }
  });

  if (topOutcome == null || aggregate.totalWeight == 0) {
    return const ConsensusResult(
      shouldResolve: false,
      outcome: null,
      confidence: 0,
    );
  }

  final confidence = topWeight / aggregate.totalWeight;
  if (confidence >= minAgreement) {
    return ConsensusResult(
      shouldResolve: true,
      outcome: topOutcome,
      confidence: confidence,
    );
  }

  return ConsensusResult(
    shouldResolve: false,
    outcome: topOutcome,
    confidence: confidence,
  );
}
