import 'package:cloud_firestore/cloud_firestore.dart';

class IosPaywallOffer {
  const IosPaywallOffer({
    required this.enabled,
    required this.trialDays,
    required this.promoText,
    required this.badgeText,
    required this.updatedAt,
  });

  final bool enabled;
  final int trialDays;
  final String promoText;
  final String badgeText;
  final DateTime? updatedAt;

  bool get hasPromo => promoText.trim().isNotEmpty || badgeText.trim().isNotEmpty;

  factory IosPaywallOffer.fromMap(Map<String, dynamic> data) {
    return IosPaywallOffer(
      enabled: data['enabled'] == true,
      trialDays: (data['trialDays'] as num?)?.toInt() ?? 0,
      promoText: data['promoText']?.toString() ?? '',
      badgeText: data['badgeText']?.toString() ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
