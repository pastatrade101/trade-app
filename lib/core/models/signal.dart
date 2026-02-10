import '../utils/firestore_helpers.dart';
import 'trading_session_config.dart';
import 'vote_aggregate.dart';

class EntryRange {
  final double min;
  final double max;

  const EntryRange({required this.min, required this.max});

  factory EntryRange.fromJson(Map<String, dynamic>? json) {
    return EntryRange(
      min: (json?['min'] ?? 0).toDouble(),
      max: (json?['max'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'min': min, 'max': max};
}

class Signal {
  final String id;
  final String uid;
  final String posterNameSnapshot;
  final bool posterVerifiedSnapshot;
  final String pair;
  final String direction;
  final String entryType;
  final double? entryPrice;
  final EntryRange? entryRange;
  final double stopLoss;
  final double tp1;
  final double? tp2;
  final bool premiumOnly;
  final String riskLevel;
  final String session;
  final DateTime validUntil;
  final DateTime? openedAt;
  final DateTime? votingOpensAt;
  final DateTime? votingClosesAt;
  final String reasoning;
  final List<String> tags;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String status;
  final VoteAggregate voteAgg;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final String? finalOutcome;
  final String? result;
  final double? pips;
  final double? closedPrice;
  final DateTime? closedAt;
  final bool lockVotes;
  final int likesCount;
  final int dislikesCount;

  const Signal({
    required this.id,
    required this.uid,
    required this.posterNameSnapshot,
    required this.posterVerifiedSnapshot,
    required this.pair,
    required this.direction,
    required this.entryType,
    required this.entryPrice,
    required this.entryRange,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.premiumOnly,
    required this.riskLevel,
    required this.session,
    required this.validUntil,
    this.openedAt,
    this.votingOpensAt,
    this.votingClosesAt,
    required this.reasoning,
    required this.tags,
    required this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.voteAgg,
    required this.resolvedBy,
    required this.resolvedAt,
    required this.finalOutcome,
    this.result,
    this.pips,
    this.closedPrice,
    this.closedAt,
    this.lockVotes = false,
    required this.likesCount,
    required this.dislikesCount,
  });

  factory Signal.fromJson(String id, Map<String, dynamic> json) {
    final preview =
        json['preview'] != null ? Map<String, dynamic>.from(json['preview']) : null;
    final createdAt = timestampToDate(preview?['createdAt'] ?? json['createdAt']) ??
        DateTime.now();
    final validUntil = timestampToDate(preview?['validUntil'] ?? json['validUntil']) ??
        createdAt.add(const Duration(minutes: defaultSessionDurationMinutes));
    return Signal(
      id: id,
      uid: json['uid'] ?? '',
      posterNameSnapshot: json['posterNameSnapshot'] ?? '',
      posterVerifiedSnapshot: json['posterVerifiedSnapshot'] ?? false,
      pair: preview?['pair'] ?? json['pair'] ?? '',
      direction: preview?['direction'] ?? json['direction'] ?? '',
      entryType: json['entryType'] ?? '',
      entryPrice: json['entryPrice']?.toDouble(),
      entryRange: json['entryRange'] != null
          ? EntryRange.fromJson(json['entryRange'])
          : null,
      stopLoss: (json['stopLoss'] ?? 0).toDouble(),
      tp1: (json['tp1'] ?? 0).toDouble(),
      tp2: json['tp2']?.toDouble(),
      premiumOnly: json['premiumOnly'] ?? false,
      riskLevel: json['riskLevel'] ?? '',
      session: preview?['session'] ?? json['session'] ?? '',
      validUntil: validUntil,
      openedAt: timestampToDate(json['openedAt']),
      votingOpensAt: timestampToDate(json['votingOpensAt']),
      votingClosesAt: timestampToDate(json['votingClosesAt']),
      reasoning: json['reasoning'] ?? '',
      tags: List<String>.from(json['tags'] ?? const []),
      imageUrl: json['imageUrl'],
      createdAt: createdAt,
      updatedAt: timestampToDate(json['updatedAt']) ?? DateTime.now(),
      status: json['status'] ?? 'open',
      voteAgg: VoteAggregate.fromJson(json['voteAgg']),
      resolvedBy: json['resolvedBy'],
      resolvedAt: timestampToDate(json['resolvedAt']),
      finalOutcome: json['finalOutcome'],
      result: json['result'],
      pips: (json['pips'] as num?)?.toDouble(),
      closedPrice: (json['closedPrice'] as num?)?.toDouble(),
      closedAt: timestampToDate(json['closedAt']),
      lockVotes: json['lockVotes'] ?? false,
      likesCount: (json['likesCount'] ?? 0).toInt(),
      dislikesCount: (json['dislikesCount'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'posterNameSnapshot': posterNameSnapshot,
      'posterVerifiedSnapshot': posterVerifiedSnapshot,
      'pair': pair,
      'direction': direction,
      'entryType': entryType,
      'entryPrice': entryPrice,
      'entryRange': entryRange?.toJson(),
      'stopLoss': stopLoss,
      'tp1': tp1,
      'tp2': tp2,
      'premiumOnly': premiumOnly,
      'riskLevel': riskLevel,
      'session': session,
      'validUntil': dateToTimestamp(validUntil),
      'openedAt': dateToTimestamp(openedAt),
      'votingOpensAt': dateToTimestamp(votingOpensAt),
      'votingClosesAt': dateToTimestamp(votingClosesAt),
      'reasoning': reasoning,
      'tags': tags,
      'imageUrl': imageUrl,
      'createdAt': dateToTimestamp(createdAt),
      'updatedAt': dateToTimestamp(updatedAt),
      'status': status,
      'voteAgg': voteAgg.toJson(),
      'resolvedBy': resolvedBy,
      'resolvedAt': dateToTimestamp(resolvedAt),
      'finalOutcome': finalOutcome,
      'lockVotes': lockVotes,
      'likesCount': likesCount,
      'dislikesCount': dislikesCount,
      'preview': {
        'pair': pair,
        'direction': direction,
        'session': session,
        'createdAt': dateToTimestamp(createdAt),
        'validUntil': dateToTimestamp(validUntil),
      },
    };
  }
}
