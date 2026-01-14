import '../utils/firestore_helpers.dart';

class PaymentIntent {
  final String id;
  final String uid;
  final String productId;
  final double amount;
  final String currency;
  final String provider;
  final String msisdn;
  final String status;
  final String? providerRef;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;

  const PaymentIntent({
    required this.id,
    required this.uid,
    required this.productId,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.msisdn,
    required this.status,
    required this.providerRef,
    required this.createdAt,
    required this.updatedAt,
    required this.expiresAt,
  });

  factory PaymentIntent.fromJson(String id, Map<String, dynamic> json) {
    return PaymentIntent(
      id: id,
      uid: json['uid'] ?? '',
      productId: json['productId'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'TZS',
      provider: json['provider'] ?? '',
      msisdn: json['msisdn'] ?? '',
      status: json['status'] ?? 'created',
      providerRef: json['providerRef'],
      createdAt: timestampToDate(json['createdAt']),
      updatedAt: timestampToDate(json['updatedAt']),
      expiresAt: timestampToDate(json['expiresAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'productId': productId,
      'amount': amount,
      'currency': currency,
      'provider': provider,
      'msisdn': msisdn,
      'status': status,
      'providerRef': providerRef,
      'createdAt': dateToTimestamp(createdAt),
      'updatedAt': dateToTimestamp(updatedAt),
      'expiresAt': dateToTimestamp(expiresAt),
    };
  }

  bool get isPending => status == 'pending' || status == 'created';
  bool get isPaid => status == 'paid';
  bool get isFailed =>
      status == 'failed' ||
      status == 'expired' ||
      status == 'cancelled' ||
      status == 'canceled';
}
