import '../utils/firestore_helpers.dart';

class SuccessPayment {
  final String id;
  final String uid;
  final String productId;
  final String billingPeriod;
  final int durationDays;
  final double amount;
  final String currency;
  final String provider;
  final String msisdn;
  final String? externalId;
  final String? transid;
  final String? mnoreference;
  final DateTime? createdAt;

  const SuccessPayment({
    required this.id,
    required this.uid,
    required this.productId,
    required this.billingPeriod,
    required this.durationDays,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.msisdn,
    required this.externalId,
    required this.transid,
    required this.mnoreference,
    required this.createdAt,
  });

  factory SuccessPayment.fromJson(String id, Map<String, dynamic> json) {
    return SuccessPayment(
      id: id,
      uid: json['uid'] ?? '',
      productId: json['productId'] ?? '',
      billingPeriod: json['billingPeriod'] ?? '',
      durationDays: (json['durationDays'] ?? 0).toInt(),
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'TZS',
      provider: json['provider'] ?? '',
      msisdn: json['msisdn'] ?? '',
      externalId: json['externalId'],
      transid: json['transid'],
      mnoreference: json['mnoreference'],
      createdAt: timestampToDate(json['createdAt']),
    );
  }
}
