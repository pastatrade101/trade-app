import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Apple Sign-In checklist (iOS):
/// - Ensure the iOS bundle id matches the Firebase iOS app.
/// - Enable "Sign In with Apple" capability in Xcode.
/// - Firebase Console -> Auth -> Sign-in method -> Apple enabled with Service ID /
///   Team ID / Key ID / private key.
class AppleAuthService {
  AppleAuthService({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  OAuthCredential? _pendingCredential;
  String? _pendingEmail;
  List<String>? _pendingMethods;

  Future<UserCredential?> signInWithApple() async {
    final available = await SignInWithApple.isAvailable();
    if (!available) {
      throw FirebaseAuthException(
        code: 'apple_sign_in_unavailable',
        message: 'Apple Sign-In is not available on this device.',
      );
    }

    final rawNonce = _generateNonce();
    final hashedNonce = _sha256ofString(rawNonce);

    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = appleCredential.identityToken;
      if (idToken == null) {
        throw FirebaseAuthException(
          code: 'missing-apple-identity-token',
          message: 'Missing Apple identity token.',
        );
      }

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: idToken,
        rawNonce: rawNonce,
      );

      try {
        return await _auth.signInWithCredential(oauthCredential);
      } on FirebaseAuthException catch (error) {
        if (error.code == 'account-exists-with-different-credential') {
          final email = error.email;
          if (email == null) {
            throw FirebaseAuthException(
              code: 'account-exists-with-different-credential',
              message:
                  'An account already exists with a different sign-in method. '
                  'Please sign in and link Apple.',
            );
          }
          final methods = await _auth.fetchSignInMethodsForEmail(email);
          _pendingCredential = oauthCredential;
          _pendingEmail = email;
          _pendingMethods = methods;
          throw AppleAuthLinkRequiredException(
            email: email,
            signInMethods: methods,
          );
        }
        rethrow;
      }
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled) {
        return null;
      }
      final code = error.code.toString();
      final message = error.message ?? 'No error message provided.';
      throw FirebaseAuthException(
        code: 'apple_sign_in_failed',
        message: 'Apple sign-in failed. code=$code message=$message',
      );
    } catch (error) {
      debugPrint('Apple sign-in failed: $error');
      throw FirebaseAuthException(
        code: 'apple_sign_in_failed',
        message: 'Apple sign-in failed. error=$error',
      );
    }
  }

  Future<void> linkPendingCredentialIfNeeded() async {
    final credential = _pendingCredential;
    if (credential == null) {
      return;
    }
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }
    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code != 'provider-already-linked' &&
          error.code != 'credential-already-in-use') {
        debugPrint('Apple credential link failed: ${error.code}');
      }
    } finally {
      _clearPending();
    }
  }

  String? get pendingEmail => _pendingEmail;

  List<String>? get pendingSignInMethods => _pendingMethods;

  void _clearPending() {
    _pendingCredential = null;
    _pendingEmail = null;
    _pendingMethods = null;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}

class AppleAuthLinkRequiredException implements Exception {
  AppleAuthLinkRequiredException({
    required this.email,
    required this.signInMethods,
  });

  final String email;
  final List<String> signInMethods;

  @override
  String toString() {
    return 'Apple sign-in requires linking to an existing account.';
  }
}
