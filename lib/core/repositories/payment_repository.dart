import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../firebase_options.dart';
import '../models/payment_intent.dart';
import '../utils/firestore_guard.dart';

class PaymentRepository {
  PaymentRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    http.Client? httpClient,
    String? projectId,
    String region = 'us-central1',
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client(),
        _projectId =
            projectId ?? DefaultFirebaseOptions.currentPlatform.projectId,
        _region = region,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final String _projectId;
  final String _region;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> _intentDoc(String id) {
    return _firestore.collection('payment_intents').doc(id);
  }

  Stream<PaymentIntent?> watchPaymentIntent(String id) {
    return guardAuthStream(() {
      return _intentDoc(id).snapshots().map((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return PaymentIntent.fromJson(snapshot.id, snapshot.data()!);
      });
    });
  }

  Future<PaymentIntent?> fetchPaymentIntent(String id) async {
    final snapshot = await _intentDoc(id).get();
    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }
    return PaymentIntent.fromJson(snapshot.id, snapshot.data()!);
  }

  Future<TrialClaimResult> claimGlobalTrial() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Sign in required.');
    }
    try {
      final callable = _functions.httpsCallable('claimGlobalTrial');
      final response = await callable();
      final data = Map<String, dynamic>.from(response.data ?? {});
      final trialDays = (data['trialDays'] as num?)?.toInt();
      final trialExpiresAt =
          DateTime.tryParse(data['trialExpiresAt']?.toString() ?? '');
      return TrialClaimResult(
        offerLabel: data['offerLabel']?.toString(),
        trialDays: trialDays,
        trialExpiresAt: trialExpiresAt,
      );
    } on FirebaseFunctionsException catch (error) {
      throw PaymentRequestException(
        message: error.message ?? 'Unable to claim trial.',
        requestPayload: {'call': 'claimGlobalTrial'},
        responsePayload: {
          'code': error.code,
          'details': error.details,
        },
      );
    }
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
    String? appCheckToken;
    try {
      appCheckToken = await FirebaseAppCheck.instance.getToken();
    } catch (_) {
      appCheckToken = null;
    }
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
        if (appCheckToken != null && appCheckToken.isNotEmpty)
          'X-Firebase-AppCheck': appCheckToken,
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
    final bool trialActivated = data['trialActivated'] == true;
    final String? intentId = data['intentId'] as String?;
    if (!trialActivated && (intentId == null || intentId.isEmpty)) {
      throw PaymentRequestException(
        message: 'Missing payment intent reference.',
        requestPayload: requestPayload,
        responsePayload: responsePayload,
      );
    }
    final trialExpiresAt = trialActivated
        ? DateTime.tryParse(data['trialExpiresAt']?.toString() ?? '')
        : null;
    final trialDays = (data['trialDays'] as num?)?.toInt();
    final offerLabel = data['offerLabel']?.toString();
    final offerType = data['offerType']?.toString();
    final originalPrice =
        (data['originalPrice'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble();
    final discountedPrice =
        (data['discountedPrice'] as num?)?.toDouble() ?? (data['amount'] as num?)?.toDouble();
    final discountPercent = (data['discountPercent'] as num?)?.toDouble();
    return PaymentRequestResult(
      intentId: intentId,
      requestPayload: requestPayload,
      responsePayload: responsePayload,
      trialActivated: trialActivated,
      trialExpiresAt: trialExpiresAt,
      trialDays: trialDays,
      offerLabel: offerLabel,
      offerType: offerType,
      discountPercent: discountPercent,
      originalPrice: originalPrice,
      discountedPrice: discountedPrice,
    );
  }
}

class PaymentRequestResult {
  const PaymentRequestResult({
    this.intentId,
    required this.requestPayload,
    required this.responsePayload,
    this.trialActivated = false,
    this.trialExpiresAt,
    this.trialDays,
    this.offerLabel,
    this.offerType,
    this.discountPercent,
    this.originalPrice,
    this.discountedPrice,
  });

  final String? intentId;
  final Map<String, dynamic> requestPayload;
  final Object? responsePayload;
  final bool trialActivated;
  final DateTime? trialExpiresAt;
  final int? trialDays;
  final String? offerLabel;
  final String? offerType;
  final double? discountPercent;
  final double? originalPrice;
  final double? discountedPrice;
}

class TrialClaimResult {
  const TrialClaimResult({
    this.offerLabel,
    this.trialDays,
    this.trialExpiresAt,
  });

  final String? offerLabel;
  final int? trialDays;
  final DateTime? trialExpiresAt;
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
