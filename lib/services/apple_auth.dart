import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// "Apple ile Giriş" yardımcıları. Yalnızca iOS'ta kullanılır.
///
/// Giriş ve hesap silme (yeniden doğrulama + Apple token iptali) aynı akışı
/// paylaşır; güvenlik için her istekte rastgele bir nonce üretilir.
class AppleAuth {
  AppleAuth._();

  /// Apple ile giriş yalnızca iOS'ta sunulur.
  static bool get isSupported => Platform.isIOS;

  /// Kullanıcı Apple penceresini kapattı mı?
  static bool isCancelled(Object error) =>
      error is SignInWithAppleAuthorizationException &&
      error.code == AuthorizationErrorCode.canceled;

  static String _randomNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  static String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();

  /// Apple penceresini açar; Firebase kimlik bilgisini, Apple yetkilendirme
  /// kodunu (token iptali için) ve (yalnızca ilk girişte gelen) adı döndürür.
  static Future<AppleAuthResult> authorize() async {
    final rawNonce = _randomNonce();
    final apple = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      nonce: _sha256(rawNonce),
    );

    final credential = OAuthProvider('apple.com').credential(
      idToken: apple.identityToken,
      rawNonce: rawNonce,
      accessToken: apple.authorizationCode,
    );

    final name = [apple.givenName, apple.familyName]
        .where((part) => part != null && part.trim().isNotEmpty)
        .join(' ');

    return AppleAuthResult(
      credential: credential,
      authorizationCode: apple.authorizationCode,
      fullName: name.isEmpty ? null : name,
    );
  }

  /// Kullanıcının Apple ile giriş yapmış bir hesabı var mı?
  static bool isAppleUser(User user) =>
      user.providerData.any((p) => p.providerId == 'apple.com');
}

class AppleAuthResult {
  const AppleAuthResult({
    required this.credential,
    required this.authorizationCode,
    this.fullName,
  });

  final OAuthCredential credential;
  final String authorizationCode;
  final String? fullName;
}
