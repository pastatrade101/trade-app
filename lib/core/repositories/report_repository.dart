import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/report.dart';

class ReportRepository {
  ReportRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  Future<void> createReport(ReportItem report) {
    return _reports.add(report.toJson());
  }

  Stream<List<ReportItem>> watchReportsByStatus(String status) {
    return _reports
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ReportItem.fromJson(doc.id, doc.data()))
            .toList());
  }

  Stream<List<ReportItem>> watchOpenReports() {
    return watchReportsByStatus('open');
  }

  Future<void> closeReport(String reportId) {
    return _reports.doc(reportId).update({'status': 'closed'});
  }
}
