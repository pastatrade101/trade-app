import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/models/success_payment.dart';
import '../../../core/utils/time_format.dart';

class SalesReportService {
  SalesReportService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<SuccessPayment>> fetchPaidSales() async {
    final snapshot = await _firestore
        .collection('success_payment')
        .orderBy('createdAt', descending: false)
        .get();

    return snapshot.docs
        .map((doc) => SuccessPayment.fromJson(doc.id, doc.data()))
        .toList();
  }

  Excel buildSalesReport(
    List<SuccessPayment> payments, {
    DateTime? generatedAt,
  }) {
    final excel = Excel.createExcel();
    const sheetName = 'Sales Report';
    final defaultSheet = excel.getDefaultSheet();
    if (defaultSheet != null && defaultSheet != sheetName) {
      excel.rename(defaultSheet, sheetName);
    }
    excel.setDefaultSheet(sheetName);
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('Date'),
      TextCellValue('Plan'),
      TextCellValue('Amount (TZS)'),
      TextCellValue('Provider'),
      TextCellValue('Status'),
      TextCellValue('Phone'),
      TextCellValue('Internal ID'),
      TextCellValue('External ID'),
      TextCellValue('Transaction ID'),
    ]);

    double total = 0;
    for (final payment in payments) {
      final createdAt = payment.createdAt;
      final dateLabel = createdAt == null
          ? ''
          : formatTanzaniaDateTime(createdAt, pattern: 'yyyy-MM-dd HH:mm');
      total += payment.amount;

      sheet.appendRow([
        TextCellValue(dateLabel),
        TextCellValue(_planLabel(payment)),
        DoubleCellValue(payment.amount),
        TextCellValue(_providerLabel(payment.provider)),
        TextCellValue('paid'),
        TextCellValue(payment.msisdn),
        TextCellValue(payment.id),
        TextCellValue(payment.externalId ?? ''),
        TextCellValue(payment.transid ?? ''),
      ]);
    }

    sheet.appendRow([
      TextCellValue('TOTAL'),
      TextCellValue(''),
      DoubleCellValue(total),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    final timestamp = formatTanzaniaDateTime(
      generatedAt ?? DateTime.now(),
      pattern: 'yyyy-MM-dd HH:mm',
    );
    sheet.appendRow([
      TextCellValue('Generated at'),
      TextCellValue(timestamp),
    ]);

    return excel;
  }

  Future<File> saveReportFile(
    Excel excel, {
    DateTime? generatedAt,
  }) async {
    final bytes = excel.encode();
    if (bytes == null) {
      throw Exception('Failed to encode Excel report');
    }

    final directory = await getTemporaryDirectory();
    final now = generatedAt ?? DateTime.now();
    final fileName =
        'MarketResolve_TZ_Sales_Report_${now.year}_${_twoDigits(now.month)}.xlsx';
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> shareReport(File file) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'MarketResolve TZ sales report',
    );
  }

  String _planLabel(SuccessPayment payment) {
    final product = payment.productId.toLowerCase();
    if (product.contains('daily')) return 'premium_daily';
    if (product.contains('weekly')) return 'premium_weekly';
    if (product.contains('monthly')) return 'premium_monthly';

    final period = payment.billingPeriod.toLowerCase();
    if (period.isNotEmpty) {
      return 'premium_$period';
    }
    return payment.productId.isNotEmpty ? payment.productId : 'premium';
  }

  String _providerLabel(String provider) {
    if (provider.isEmpty) return '';
    return provider.trim();
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}
