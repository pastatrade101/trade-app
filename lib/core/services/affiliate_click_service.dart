import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

class AffiliateClickService {
  AffiliateClickService({
    FirebaseAuth? auth,
    http.Client? httpClient,
    String projectId = 'asset-vista',
    String region = 'us-central1',
  })  : _auth = auth ?? FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client(),
        _projectId = projectId,
        _region = region;

  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final String _projectId;
  final String _region;

  Uri get _functionUri => Uri.https('$_region-$_projectId.cloudfunctions.net', '/recordAffiliateClick');

  Future<void> recordClick(String affiliateId) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Must be signed in to record clicks.');
    }
    final idToken = await user.getIdToken();
    final response = await _httpClient.post(
      _functionUri,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'affiliateId': affiliateId}),
    );
    if (response.statusCode != 200) {
      throw StateError('Unable to record affiliate click (${response.statusCode}): ${response.body}');
    }
  }
}
