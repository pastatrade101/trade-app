import 'package:cloud_firestore/cloud_firestore.dart';

enum GlobalOfferType { trial, discount }

class GlobalOffer {
  const GlobalOffer({
    required this.label,
    required this.type,
    required this.isActive,
    required this.trialDays,
    required this.discountPercent,
    required this.startsAt,
    required this.endsAt,
    required this.updatedAt,
  });

  final String label;
  final GlobalOfferType type;
  final bool isActive;
  final int trialDays;
  final double discountPercent;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final DateTime? updatedAt;

  bool get isTrial => type == GlobalOfferType.trial;
  bool get isDiscount => type == GlobalOfferType.discount;

  bool get isCurrentlyActive {
    if (!isActive) {
      return false;
    }
    final now = DateTime.now();
    if (startsAt != null && now.isBefore(startsAt!)) {
      return false;
    }
    if (endsAt != null && now.isAfter(endsAt!)) {
      return false;
    }
    if (isTrial && trialDays <= 0) {
      return false;
    }
    if (isDiscount && (discountPercent <= 0 || discountPercent > 100)) {
      return false;
    }
    return true;
  }

  factory GlobalOffer.fromMap(Map<String, dynamic> data) {
    final rawType = data['type']?.toString().toLowerCase();
    final type =
        rawType == 'discount' ? GlobalOfferType.discount : GlobalOfferType.trial;
    final startsAt = (data['startsAt'] as Timestamp?)?.toDate();
    final endsAt = (data['endsAt'] as Timestamp?)?.toDate();
    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
    return GlobalOffer(
      label: data['label']?.toString() ?? '',
      type: type,
      isActive: data['isActive'] == true,
      trialDays: (data['trialDays'] as num?)?.toInt() ?? 0,
      discountPercent: (data['discountPercent'] as num?)?.toDouble() ?? 0,
      startsAt: startsAt,
      endsAt: endsAt,
      updatedAt: updatedAt,
    );
  }
}
