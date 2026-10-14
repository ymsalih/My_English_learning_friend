import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Akıllı Çeviri'nin sunucu bağlantısı (DeepL, sözlük anlamları, kelime
/// görseli). İstekler Firebase'deki `translate` işlevine kullanıcının oturum
/// kimliğiyle gider; anahtarlar sunucudadır. Cevaplar servislerin kendi
/// biçimindedir (eski vekil sunucuyla aynı).
class TranslateApi {
  TranslateApi._();

  static const String _baseUrl = 'https://europe-west1-ingilizce-destek-app.cloudfunctions.net/translate';

  /// Günlük istek sayacının günü (uygulamadaki sayaçlarla aynı).
  static String get _today => DateTime.now().toIso8601String().substring(0, 10);

  static Future<Map<String, String>> _headers() async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// DeepL çevirisi. Gövde DeepL'in biçiminde: `{"translations": [{"text": ...}]}`.
  static Future<http.Response> deepl({
    required String text,
    required String sourceLang,
    required String targetLang,
  }) async =>
      http.post(
        Uri.parse('$_baseUrl/deepl'),
        headers: await _headers(),
        body: jsonEncode({
          'text': [text],
          'source_lang': sourceLang,
          'target_lang': targetLang,
          'date': _today,
        }),
      );

  /// Google sözlük anlamları ([sl] → [tl], `en` / `tr`).
  static Future<http.Response> dictionary({
    required String word,
    required String sl,
    required String tl,
  }) async =>
      http.get(
        Uri.parse('$_baseUrl/dictionary').replace(
          queryParameters: {'sl': sl, 'tl': tl, 'word': word, 'date': _today},
        ),
        headers: await _headers(),
      );

  /// Kelime görseli (Pexels arama sonucu).
  static Future<http.Response> image(String word) async => http.get(
        Uri.parse('$_baseUrl/image').replace(
          queryParameters: {'word': word, 'date': _today},
        ),
        headers: await _headers(),
      );

  static DateTime? _lastWarmUp;

  /// Çeviri ekranı açılırken sunucuyu önceden uyandırır (ücretsiz, hafif).
  static void warmUp() {
    final now = DateTime.now();
    if (_lastWarmUp != null && now.difference(_lastWarmUp!) < const Duration(seconds: 60)) {
      return;
    }
    _lastWarmUp = now;
    unawaited(() async {
      try {
        await http.get(Uri.parse('$_baseUrl/ping')).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint("Çeviri ısınma isteği başarısız: $e");
      }
    }());
  }
}
