import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Gemini API'den dönen hata.
class AiException implements Exception {
  AiException(this.message, {this.statusCode, this.status});

  final String message;
  final int? statusCode;
  final String? status;

  @override
  String toString() => 'AiException($statusCode $status): $message';
}

/// Uygulamadaki tüm Gemini çağrılarının tek giriş noktası (doğrudan REST API).
class AiClient {
  AiClient._();

  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// Sohbet: en hızlı model. Google'ın "en hızlı" olarak tanımladığı model ve
  /// düşünmeyi "minimal"e indirebilen tek seçenek.
  static const String chatModel = 'gemini-3.5-flash-lite';

  /// Hikaye üretimi: sonuç havuza kaydedildiği için nadiren çalışır; kalite
  /// için daha güçlü model.
  static const String storyModel = 'gemini-3.7-flash';

  /// Cevaptan önceki "düşünme" süresi gecikmenin en büyük kaynağı.
  static const Map<String, Object?> chatThinking = {'thinkingLevel': 'MINIMAL'};
  static const Map<String, Object?> storyThinking = {'thinkingLevel': 'LOW'};

  /// Tüm isteklerin paylaştığı HTTP bağlantısı: her mesajda yeniden DNS + TCP +
  /// TLS kurulmaz. Mesajlar arasında kullanıcı yazarken bağlantı açık kalsın
  /// diye boşta bekleme süresi uzun tutulur.
  static final http.Client _http = IOClient(
    HttpClient()..idleTimeout = const Duration(seconds: 90),
  );

  static String get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw AiException('GEMINI_API_KEY bulunamadı. Lütfen .env dosyasını kontrol edin.');
    }
    return key;
  }

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'x-goog-api-key': _apiKey,
      };

  // --- İçerik ve şema yardımcıları (Gemini REST formatı) ---

  static Map<String, Object?> userContent(String text) => {
        'role': 'user',
        'parts': [
          {'text': text},
        ],
      };

  static Map<String, Object?> modelContent(String text) => {
        'role': 'model',
        'parts': [
          {'text': text},
        ],
      };

  static Map<String, Object?> stringSchema({String? description}) => {
        'type': 'STRING',
        'description': ?description,
      };

  static Map<String, Object?> integerSchema() => {'type': 'INTEGER'};

  static Map<String, Object?> booleanSchema() => {'type': 'BOOLEAN'};

  static Map<String, Object?> arraySchema(Map<String, Object?> items) => {
        'type': 'ARRAY',
        'items': items,
      };

  /// Tüm alanlar zorunlu; alanlar yazıldığı sırayla üretilir.
  static Map<String, Object?> objectSchema(Map<String, Map<String, Object?>> properties) => {
        'type': 'OBJECT',
        'properties': properties,
        'required': properties.keys.toList(),
        'propertyOrdering': properties.keys.toList(),
      };

  // --- İstekler ---

  static Map<String, Object?> _body(
    List<Map<String, Object?>> contents,
    Map<String, Object?>? generationConfig,
    String? systemInstruction,
  ) =>
      {
        'contents': contents,
        if (systemInstruction != null)
          'systemInstruction': {
            'parts': [
              {'text': systemInstruction},
            ],
          },
        'generationConfig': ?generationConfig,
      };

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
  static String _textOf(Map<String, dynamic> response) {
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

  /// Cevabı parça parça (akış) döndürür.
  static Stream<String> streamText({
    required String model,
    required List<Map<String, Object?>> contents,
    Map<String, Object?>? generationConfig,
    String? systemInstruction,
    Duration chunkTimeout = const Duration(seconds: 25),
  }) async* {
    final request = http.Request(
      'POST',
      Uri.parse('$_baseUrl/$model:streamGenerateContent?alt=sse'),
    )
      ..headers.addAll(_headers)
      ..body = jsonEncode(_body(contents, generationConfig, systemInstruction));

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
      final text = _textOf(chunk);
      if (text.isNotEmpty) yield text;
    }
  }

  /// Cevabın tamamını tek seferde döndürür.
  static Future<String> generateText({
    required String model,
    required List<Map<String, Object?>> contents,
    Map<String, Object?>? generationConfig,
    String? systemInstruction,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final response = await _http
        .post(
          Uri.parse('$_baseUrl/$model:generateContent'),
          headers: _headers,
          body: jsonEncode(_body(contents, generationConfig, systemInstruction)),
        )
        .timeout(timeout);
    final body = utf8.decode(response.bodyBytes);
    if (response.statusCode != 200) _throwApiError(response.statusCode, body);
    return _textOf(jsonDecode(body) as Map<String, dynamic>);
  }

  static DateTime? _lastWarmUp;

  /// İlk mesajdan önce bağlantıyı (DNS + TCP + TLS) hazırlar. countTokens
  /// ücretsiz ve hafif bir istektir; ilk mesaj hazır bağlantıdan gider.
  static void warmUp(String model) {
    final now = DateTime.now();
    if (_lastWarmUp != null && now.difference(_lastWarmUp!) < const Duration(seconds: 60)) {
      return;
    }
    _lastWarmUp = now;
    unawaited(() async {
      try {
        await _http
            .post(
              Uri.parse('$_baseUrl/$model:countTokens'),
              headers: _headers,
              body: jsonEncode({
                'contents': [userContent('hi')],
              }),
            )
            .timeout(const Duration(seconds: 10));
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
    if (error is TimeoutException ||
        error is SocketException ||
        error is http.ClientException) {
      return 'Bağlantı sorunu. İnternetinizi kontrol edip tekrar deneyin.';
    }
    if (error is AiException) {
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
