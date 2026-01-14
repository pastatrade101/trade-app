class VoteAggregate {
  final int tpCount;
  final int slCount;
  final int beCount;
  final int partialCount;
  final int totalVotes;
  final double tpWeight;
  final double slWeight;
  final double beWeight;
  final double partialWeight;
  final double totalWeight;
  final String? consensusOutcome;
  final double consensusConfidence;

  const VoteAggregate({
    required this.tpCount,
    required this.slCount,
    required this.beCount,
    required this.partialCount,
    required this.totalVotes,
    required this.tpWeight,
    required this.slWeight,
    required this.beWeight,
    required this.partialWeight,
    required this.totalWeight,
    required this.consensusOutcome,
    required this.consensusConfidence,
  });

  factory VoteAggregate.empty() => const VoteAggregate(
        tpCount: 0,
        slCount: 0,
        beCount: 0,
        partialCount: 0,
        totalVotes: 0,
        tpWeight: 0,
        slWeight: 0,
        beWeight: 0,
        partialWeight: 0,
        totalWeight: 0,
        consensusOutcome: null,
        consensusConfidence: 0,
      );

  factory VoteAggregate.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return VoteAggregate.empty();
    }
    final tpCount = (json['tpCount'] ?? 0).toInt();
    final slCount = (json['slCount'] ?? 0).toInt();
    final beCount = (json['beCount'] ?? 0).toInt();
    final partialCount = (json['partialCount'] ?? 0).toInt();
    final tpWeight = (json['tpWeight'] ?? tpCount).toDouble();
    final slWeight = (json['slWeight'] ?? slCount).toDouble();
    final beWeight = (json['beWeight'] ?? beCount).toDouble();
    final partialWeight = (json['partialWeight'] ?? partialCount).toDouble();
    final totalVotes = (json['totalVotes'] ?? (tpCount + slCount + beCount + partialCount))
        .toInt();
    final totalWeight =
        (json['totalWeight'] ?? (tpWeight + slWeight + beWeight + partialWeight))
            .toDouble();
    return VoteAggregate(
      tpCount: tpCount,
      slCount: slCount,
      beCount: beCount,
      partialCount: partialCount,
      totalVotes: totalVotes,
      tpWeight: tpWeight,
      slWeight: slWeight,
      beWeight: beWeight,
      partialWeight: partialWeight,
      totalWeight: totalWeight,
      consensusOutcome: json['consensusOutcome'],
      consensusConfidence: (json['consensusConfidence'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tpCount': tpCount,
      'slCount': slCount,
      'beCount': beCount,
      'partialCount': partialCount,
      'totalVotes': totalVotes,
      'tpWeight': tpWeight,
      'slWeight': slWeight,
      'beWeight': beWeight,
      'partialWeight': partialWeight,
      'totalWeight': totalWeight,
      'consensusOutcome': consensusOutcome,
      'consensusConfidence': consensusConfidence,
    };
  }
}
