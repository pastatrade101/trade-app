import '../utils/firestore_helpers.dart';
import 'signal.dart';

class SignalPremiumDetails {
  final String entryType;
  final double? entryPrice;
  final EntryRange? entryRange;
  final double stopLoss;
  final double tp1;
  final double? tp2;
  final String reason;
  final DateTime? updatedAt;

  const SignalPremiumDetails({
    required this.entryType,
    required this.entryPrice,
    required this.entryRange,
    required this.stopLoss,
    required this.tp1,
    required this.tp2,
    required this.reason,
    required this.updatedAt,
  });

  factory SignalPremiumDetails.fromJson(Map<String, dynamic> json) {
    return SignalPremiumDetails(
      entryType: json['entryType'] ?? '',
      entryPrice: json['entryPrice']?.toDouble(),
      entryRange: json['entryRange'] != null
          ? EntryRange.fromJson(json['entryRange'])
          : null,
      stopLoss: (json['stopLoss'] ?? 0).toDouble(),
      tp1: (json['tp1'] ?? 0).toDouble(),
      tp2: json['tp2']?.toDouble(),
      reason: json['reason'] ?? json['reasoning'] ?? '',
      updatedAt: timestampToDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'entryType': entryType,
      'entryPrice': entryPrice,
      'entryRange': entryRange?.toJson(),
      'stopLoss': stopLoss,
      'tp1': tp1,
      'tp2': tp2,
      'reason': reason,
      'updatedAt': dateToTimestamp(updatedAt),
    };
  }
}
