import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'ai_consent.dart';

/// Yapay zeka sunucusundan dönen hata.
class AiException implements Exception {
  AiException(this.message, {this.statusCode, this.status});

  final String message;
  final int? statusCode;
  final String? status;

  @override
  String toString() => 'AiException($statusCode $status): $message';
}

/// Uygulamadaki tüm yapay zeka çağrılarının tek giriş noktası.
///
/// İstekler doğrudan Gemini'ye değil, Firebase'deki `ai` sunucu işlevine
/// gider: anahtar uygulamada değil sunucuda durur, her istek kullanıcının
/// Firebase oturumuyla doğrulanır ve paket limitine göre sunucuda sayılır.
/// Talimatlar (sohbet öğretmeni, hikaye kuralları) da sunucudadır.
class AiClient {
  AiClient._();

  static const String _baseUrl = 'https://europe-west1-ingilizce-destek-app.cloudfunctions.net/ai';

  /// Tüm isteklerin paylaştığı HTTP bağlantısı: her mesajda yeniden DNS + TCP +
  /// TLS kurulmaz. Mesajlar arasında kullanıcı yazarken bağlantı açık kalsın
  /// diye boşta bekleme süresi uzun tutulur.
  static final http.Client _http = IOClient(
    HttpClient()..idleTimeout = const Duration(seconds: 90),
  );

  /// Kullanıcının oturum kimliği (Firebase ID token). Firebase bunu bir saat
  /// önbellekte tutar ve süresi dolunca kendiliğinden yeniler.
  static Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw AiException('Giriş yapılmamış.', statusCode: 401, status: 'UNAUTHENTICATED');
    }
    final token = await user.getIdToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// Günlük hakların sıfırlandığı gün (uygulamadaki sayaçlarla aynı).
  static String get _today => DateTime.now().toIso8601String().substring(0, 10);

  // --- Sohbet geçmişi öğeleri (sunucunun beklediği biçim) ---

  static Map<String, Object?> userContent(String text) => {'role': 'user', 'text': text};

  static Map<String, Object?> modelContent(String text) => {'role': 'model', 'text': text};

  @visibleForTesting
  static Map<String, Object?> chatRequest({
    required String mode,
    required String level,
    required List<Map<String, Object?>> history,
    required String message,
    required String date,
  }) =>
      {
        'mode': mode,
        'level': level,
        'history': history,
        'message': message,
        'date': date,
      };

  // --- Cevap okuma (sunucu Gemini'nin biçimini aynen iletir) ---

  static Never _throwApiError(int statusCode, String body) {
    try {
      final error = (jsonDecode(body) as Map<String, dynamic>)['error'] as Map<String, dynamic>;
      throw AiException(
        error['message']?.toString() ?? body,
        statusCode: statusCode,
        status: error['status']?.toString(),
      );
    } on AiException {
      rethrow;
    } catch (_) {
      throw AiException(body, statusCode: statusCode);
    }
  }

  /// Bir cevap parçasındaki metni döndürür ("düşünce" parçaları hariç).
  @visibleForTesting
  static String textOf(Map<String, dynamic> response) {
    final blockReason = response['promptFeedback']?['blockReason'];
    if (blockReason != null) {
      throw AiException('İstek engellendi: $blockReason', status: 'BLOCKED');
    }
    final candidates = response['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return '';
    final parts = candidates.first['content']?['parts'] as List<dynamic>?;
    if (parts == null) return '';
    final out = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['thought'] != true && part['text'] is String) {
        out.write(part['text']);
      }
    }
    return out.toString();
  }

  // --- İstekler ---

  /// Sohbet cevabını parça parça (akış) döndürür. [history]: [userContent] /
  /// [modelContent] öğeleri.
  static Stream<String> streamChat({
    required String mode,
    required String level,
    required List<Map<String, Object?>> history,
    required String message,
    Duration chunkTimeout = const Duration(seconds: 25),
  }) async* {
    AiConsent.check();
    final request = http.Request('POST', Uri.parse('$_baseUrl/chat'))
      ..headers.addAll(await _headers())
      ..body = jsonEncode(chatRequest(
        mode: mode,
        level: level,
        history: history,
        message: message,
        date: _today,
      ));

    final response = await _http.send(request).timeout(chunkTimeout);
    if (response.statusCode != 200) {
      _throwApiError(response.statusCode, await response.stream.bytesToString());
    }

    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .timeout(chunkTimeout);
    await for (final line in lines) {
      if (!line.startsWith('data: ')) continue;
      final chunk = jsonDecode(line.substring(6)) as Map<String, dynamic>;
      if (chunk['error'] is Map) {
        final error = chunk['error'] as Map;
        throw AiException(
          error['message']?.toString() ?? 'Bilinmeyen hata',
          statusCode: error['code'] as int?,
          status: error['status']?.toString(),
        );
      }
      final text = textOf(chunk);
      if (text.isNotEmpty) yield text;
    }
  }

  /// Etkileşimli hikayenin JSON metnini döndürür.
  static Future<String> generateStory({
    required String genre,
    required String level,
    Duration timeout = const Duration(seconds: 90),
  }) async {
    AiConsent.check();
    final response = await _http
        .post(
          Uri.parse('$_baseUrl/story'),
          headers: await _headers(),
          body: jsonEncode({'genre': genre, 'level': level, 'date': _today}),
        )
        .timeout(timeout);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) _throwApiError(response.statusCode, body);
    return textOf(jsonDecode(body) as Map<String, dynamic>);
  }

  static DateTime? _lastWarmUp;

  /// Sunucuyu önceden uyandırır: sohbet/hikaye ekranı açılırken çağrılır.
  /// Sunucu bir süre kullanılmayınca uyur; ilk mesaj gelene kadar uyanmış ve
  /// bağlantı (DNS + TCP + TLS) hazır olur. Ücretsiz ve hafif bir istektir.
  static void warmUp() {
    final now = DateTime.now();
    if (_lastWarmUp != null && now.difference(_lastWarmUp!) < const Duration(seconds: 60)) {
      return;
    }
    _lastWarmUp = now;
    unawaited(() async {
      try {
        await _http.get(Uri.parse('$_baseUrl/ping')).timeout(const Duration(seconds: 15));
      } catch (e) {
        debugPrint("AI ısınma isteği başarısız: $e");
      }
    }());
  }

  // --- Hata yönetimi ---

  static const int maxAttempts = 3;

  /// Geçici hatalarda (yoğunluk, kota, ağ) tekrar denemeye değer mi?
  static bool isRetryable(Object error) {
    if (error is TimeoutException ||
        error is SocketException ||
        error is HttpException ||
        error is http.ClientException) {
      return true;
    }
    if (error is AiException) {
      const retryableCodes = {408, 429, 500, 502, 503, 504};
      return retryableCodes.contains(error.statusCode) ||
          error.status == 'UNAVAILABLE' ||
          error.status == 'RESOURCE_EXHAUSTED';
    }
    return false;
  }

  /// Üstel bekleme + rastgele sapma: binlerce istemci aynı anda hata aldığında
  /// hepsinin aynı anda yeniden denemesini (thundering herd) önler.
  static Duration backoff(int attempt) =>
      Duration(milliseconds: 500 * (1 << attempt) + Random().nextInt(400));

  /// Kullanıcıya gösterilecek Türkçe hata mesajı.
  static String userMessage(Object error) {
    if (error is AiConsentException) {
      return "Bu özellik için Ayarlar'dan yapay zeka veri paylaşımına izin vermelisin.";
    }
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException) {
      return 'Bağlantı sorunu. İnternetinizi kontrol edip tekrar deneyin.';
    }
    if (error is AiException) {
      if (error.status == 'LIMIT_REACHED') {
        return 'Bugünkü hakkın doldu. Daha fazla hak için paketini yükseltebilirsin.';
      }
      if (error.statusCode == 401 || error.status == 'UNAUTHENTICATED') {
        return 'Oturumun doğrulanamadı. Lütfen çıkış yapıp tekrar giriş yap.';
      }
      if (error.statusCode == 429 || error.status == 'RESOURCE_EXHAUSTED') {
        return 'Yapay zeka şu an çok yoğun. Lütfen birkaç saniye sonra tekrar deneyin.';
      }
      if (error.status == 'BLOCKED') {
        return 'Bu mesaja cevap verilemiyor. Lütfen farklı bir şekilde yazın.';
      }
      if (error.statusCode == 400 || error.statusCode == 403) {
        return 'Yapay zeka servisine bağlanılamadı. Lütfen daha sonra tekrar deneyin.';
      }
    }
    if (isRetryable(error)) {
      return 'Yapay zeka sunucuları şu an çok yoğun. Lütfen birkaç dakika sonra tekrar deneyin.';
    }
    return 'Mesaj gönderilemedi. Lütfen tekrar deneyin.';
  }
}
