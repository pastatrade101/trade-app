class ValidatorStats {
  final int totalVotes;
  final int correctVotes;

  const ValidatorStats({
    required this.totalVotes,
    required this.correctVotes,
  });

  double get accuracy => totalVotes == 0 ? 0 : correctVotes / totalVotes;

  factory ValidatorStats.empty() => const ValidatorStats(
        totalVotes: 0,
        correctVotes: 0,
      );

  factory ValidatorStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return ValidatorStats.empty();
    }
    return ValidatorStats(
      totalVotes: (json['totalVotes'] ?? 0).toInt(),
      correctVotes: (json['correctVotes'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalVotes': totalVotes,
      'correctVotes': correctVotes,
    };
  }
}
