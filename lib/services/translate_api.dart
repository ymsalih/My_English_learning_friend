import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Akıllı Çeviri'nin servis bağlantısı. DeepL ve kelime görseli Firebase'deki
/// `translate` işlevine kullanıcının oturum kimliğiyle gider (anahtarlar
/// sunucudadır). Sözlük anlamları anahtarsız ücretsiz Google uç noktasından
/// doğrudan telefondan alınır. Cevaplar servislerin kendi biçimindedir.
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

  /// DeepL çevirisi. [texts] tek istekte çevrilir (en fazla 20; ör. örnek
  /// cümleler). Gövde DeepL'in biçiminde: `{"translations": [{"text": ...}]}`,
  /// sıra [texts] ile aynı.
  static Future<http.Response> deepl({
    required List<String> texts,
    required String sourceLang,
    required String targetLang,
  }) async =>
      http.post(
        Uri.parse('$_baseUrl/deepl'),
        headers: await _headers(),
        body: jsonEncode({
          'text': texts,
          'source_lang': sourceLang,
          'target_lang': targetLang,
          'date': _today,
        }),
      );

  /// Google sözlük anlamları ([sl] → [tl], `en` / `tr`).
  ///
  /// Anahtar gerektirmeyen ücretsiz uç nokta; sunucudan değil doğrudan
  /// telefondan çağrılır: Google, bulut sunucularından gelen bu istekleri
  /// reddediyor (429), kullanıcıların kendi bağlantısından gelenleri değil.
  /// Uygulamadaki diğer Google çevirileri (`translator` paketi) de böyle çalışır.
  static Future<http.Response> dictionary({
    required String word,
    required String sl,
    required String tl,
  }) =>
      http.get(
        Uri.https('translate.googleapis.com', '/translate_a/single', {
          'client': 'gtx',
          'sl': sl,
          'tl': tl,
          'dt': ['t', 'bd'],
          'q': word,
        }),
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
