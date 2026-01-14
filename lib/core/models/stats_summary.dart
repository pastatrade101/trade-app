class StatsSummary {
  final double winRate30;
  final double winRate90;
  final int total30;
  final int total90;
  final double reliabilityScore;
  final double avgRR30;
  final double avgRR90;
  final int currentStreak;

  const StatsSummary({
    required this.winRate30,
    required this.winRate90,
    required this.total30,
    required this.total90,
    required this.reliabilityScore,
    required this.avgRR30,
    required this.avgRR90,
    required this.currentStreak,
  });

  factory StatsSummary.empty() => const StatsSummary(
        winRate30: 0,
        winRate90: 0,
        total30: 0,
        total90: 0,
        reliabilityScore: 0,
        avgRR30: 0,
        avgRR90: 0,
        currentStreak: 0,
      );

  factory StatsSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return StatsSummary.empty();
    }
    return StatsSummary(
      winRate30: (json['winRate30'] ?? 0).toDouble(),
      winRate90: (json['winRate90'] ?? 0).toDouble(),
      total30: (json['total30'] ?? 0).toInt(),
      total90: (json['total90'] ?? 0).toInt(),
      reliabilityScore: (json['reliabilityScore'] ?? 0).toDouble(),
      avgRR30: (json['avgRR30'] ?? 0).toDouble(),
      avgRR90: (json['avgRR90'] ?? 0).toDouble(),
      currentStreak: (json['currentStreak'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'winRate30': winRate30,
      'winRate90': winRate90,
      'total30': total30,
      'total90': total90,
      'reliabilityScore': reliabilityScore,
      'avgRR30': avgRR30,
      'avgRR90': avgRR90,
      'currentStreak': currentStreak,
    };
  }
}
