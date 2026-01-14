import '../utils/firestore_helpers.dart';

class RevenueStats {
  final double totalRevenue;
  final int totalPayments;
  final String currency;
  final String currentMonth;
  final double currentMonthRevenue;
  final int currentMonthPayments;
  final String todayDate;
  final double todayRevenue;
  final int todayPayments;
  final DateTime? updatedAt;

  const RevenueStats({
    required this.totalRevenue,
    required this.totalPayments,
    required this.currency,
    required this.currentMonth,
    required this.currentMonthRevenue,
    required this.currentMonthPayments,
    required this.todayDate,
    required this.todayRevenue,
    required this.todayPayments,
    required this.updatedAt,
  });

  factory RevenueStats.empty() {
    return const RevenueStats(
      totalRevenue: 0,
      totalPayments: 0,
      currency: 'TZS',
      currentMonth: '',
      currentMonthRevenue: 0,
      currentMonthPayments: 0,
      todayDate: '',
      todayRevenue: 0,
      todayPayments: 0,
      updatedAt: null,
    );
  }

  factory RevenueStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return RevenueStats.empty();
    }
    return RevenueStats(
      totalRevenue: (json['totalRevenue'] ?? 0).toDouble(),
      totalPayments: (json['totalPayments'] ?? 0).toInt(),
      currency: json['currency'] ?? 'TZS',
      currentMonth: json['currentMonth'] ?? '',
      currentMonthRevenue: (json['currentMonthRevenue'] ?? 0).toDouble(),
      currentMonthPayments: (json['currentMonthPayments'] ?? 0).toInt(),
      todayDate: json['todayDate'] ?? '',
      todayRevenue: (json['todayRevenue'] ?? 0).toDouble(),
      todayPayments: (json['todayPayments'] ?? 0).toInt(),
      updatedAt: timestampToDate(json['updatedAt']),
    );
  }
}
