import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../firebase_options.dart';
import '../models/payment_intent.dart';

class PaymentRepository {
  PaymentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? httpClient,
    String? projectId,
    String region = 'us-central1',
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client(),
        _projectId =
            projectId ?? DefaultFirebaseOptions.currentPlatform.projectId,
        _region = region;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final String _projectId;
  final String _region;

  DocumentReference<Map<String, dynamic>> _intentDoc(String id) {
    return _firestore.collection('payment_intents').doc(id);
  }

  Stream<PaymentIntent?> watchPaymentIntent(String id) {
    return _intentDoc(id).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }
      return PaymentIntent.fromJson(snapshot.id, snapshot.data()!);
    });
  }

  Future<PaymentIntent?> fetchPaymentIntent(String id) async {
    final snapshot = await _intentDoc(id).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return PaymentIntent.fromJson(snapshot.id, snapshot.data()!);
  }

  Future<PaymentRequestResult> createPaymentIntent({
    required String productId,
    required String provider,
    required String accountNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in required.');
    }
    final token = await user.getIdToken();
    final uri = Uri.https(
      '${_region}-${_projectId}.cloudfunctions.net',
      '/initiatePremiumCheckout',
    );
    final requestBody = {
      'jwtToken': token,
      'provider': provider,
      'accountNumber': accountNumber,
      'productId': productId,
    };
    final response = await _httpClient.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        // TODO: Add App Check token header if required by your project.
      },
      body: jsonEncode({
        ...requestBody,
      }),
    );

    final requestPayload = {
      'url': uri.toString(),
      'method': 'POST',
      'body': requestBody,
    };

    final responsePayload = _decodeResponse(response.body);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw PaymentRequestException(
        message: 'Payment intent failed: ${response.body}',
        requestPayload: requestPayload,
        responsePayload: responsePayload,
      );
    }

    final data =
        responsePayload is Map<String, dynamic> ? responsePayload : {};
    final success = data['success'] == true;
    if (!success) {
      throw PaymentRequestException(
        message: data['message'] ?? 'Payment initiation failed.',
        requestPayload: requestPayload,
        responsePayload: responsePayload,
      );
    }
    final intentId = data['intentId'] as String?;
    if (intentId == null || intentId.isEmpty) {
      throw PaymentRequestException(
        message: 'Missing payment intent reference.',
        requestPayload: requestPayload,
        responsePayload: responsePayload,
      );
    }
    return PaymentRequestResult(
      intentId: intentId,
      requestPayload: requestPayload,
      responsePayload: responsePayload,
    );
  }
}

class PaymentRequestResult {
  const PaymentRequestResult({
    required this.intentId,
    required this.requestPayload,
    required this.responsePayload,
  });

  final String intentId;
  final Map<String, dynamic> requestPayload;
  final Object? responsePayload;
}

class PaymentRequestException implements Exception {
  PaymentRequestException({
    required this.message,
    required this.requestPayload,
    required this.responsePayload,
  });

  final String message;
  final Map<String, dynamic> requestPayload;
  final Object? responsePayload;

  @override
  String toString() => message;
}

Object? _decodeResponse(String body) {
  if (body.isEmpty) {
    return {};
  }
  try {
    return jsonDecode(body);
  } catch (_) {
    return {'raw': body};
  }
}
