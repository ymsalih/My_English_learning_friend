import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ai_client.dart';
import 'ai_consent.dart';

class ChatService {
  /// Modele gönderilen en fazla geçmiş mesaj sayısı (10 soru-cevap).
  /// Geçmiş sınırsız büyürse her istek yavaşlar ve pahalanır. Sunucu da
  /// en fazla bu kadarını kabul eder.
  static const int _maxHistory = 20;

  /// Bir sonraki parça bu süre içinde gelmezse istek zaman aşımına uğrar.
  static const Duration _chunkTimeout = Duration(seconds: 25);

  static final RegExp _replyStart = RegExp(r'"reply"\s*:\s*"');

  /// Chat ekranı açılırken çağrılır: sunucu, kullanıcı ilk mesajını
  /// yazarken uyanır. (Öğretmen talimatları ve cevap biçimi sunucudadır.)
  void warmUp() => AiClient.warmUp();

  /// Mesajı gönderir ve cevabı akış halinde alır.
  ///
  /// [onPartial], cevap metni ("reply") geldikçe o ana kadarki metinle çağrılır.
  /// Dönen değer tam cevaptır: {"reply": ..., "correction": {...}}.
  Future<Map<String, dynamic>> sendMessage(
    String message,
    String mode,
    String userLevel,
    List<Map<String, Object?>> history, {
    void Function(String partialReply)? onPartial,
  }) async {
    final recent = history.length > _maxHistory
        ? history.sublist(history.length - _maxHistory)
        : history;

    for (var attempt = 0; ; attempt++) {
      var receivedText = false;
      try {
        final buffer = StringBuffer();
        var lastReply = '';
        final stream = AiClient.streamChat(
          mode: mode,
          level: userLevel,
          history: recent,
          message: message,
          chunkTimeout: _chunkTimeout,
        );
        await for (final text in stream) {
          receivedText = true;
          buffer.write(text);
          if (onPartial != null) {
            final reply = _partialReply(buffer.toString());
            if (reply != null && reply != lastReply) {
              lastReply = reply;
              onPartial(reply);
            }
          }
        }

        final raw = buffer.toString();
        if (raw.isEmpty) throw Exception("Yapay zekadan boş yanıt geldi.");
        Map<String, dynamic> result;
        try {
          result = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          // Sunucu şema kullandığı için nadirdir; yine de Markdown sarmalını temizle.
          final cleanText = raw.replaceAll('```json', '').replaceAll('```', '').trim();
          result = jsonDecode(cleanText) as Map<String, dynamic>;
        }
        return dropPunctuationOnlyCorrection(result);
      } catch (e) {
        // Kullanıcı cevabın bir kısmını gördüyse sessizce baştan başlatmayız.
        final canRetry = !receivedText &&
            attempt + 1 < AiClient.maxAttempts &&
            AiClient.isRetryable(e);
        if (!canRetry) {
          debugPrint("Chat hatası: $e");
          rethrow;
        }
        await Future.delayed(AiClient.backoff(attempt));
      }
    }
  }

  // Kesme işareti (it's / its gibi gramer farkları) korunur; diğer noktalama
  // işaretleri karşılaştırmada yok sayılır.
  static final RegExp _punctuation = RegExp(r"[^\p{L}\p{N}\s'’]", unicode: true);

  static String _withoutPunctuation(String text) =>
      text.replaceAll(_punctuation, '').replaceAll(RegExp(r'\s+'), ' ').trim();

  /// Model talimata rağmen yalnızca noktalama (virgül, nokta vb.) için
  /// düzeltme önerirse düzeltme gösterilmez.
  @visibleForTesting
  static Map<String, dynamic> dropPunctuationOnlyCorrection(Map<String, dynamic> response) {
    final correction = response['correction'];
    if (correction is! Map) return response;
    final original = (correction['original'] ?? '').toString();
    final corrected = (correction['corrected'] ?? '').toString();
    if (original.isEmpty || _withoutPunctuation(original) != _withoutPunctuation(corrected)) {
      return response;
    }
    return {
      ...response,
      'correction': {'original': '', 'corrected': '', 'explanation': ''},
    };
  }

  /// Akmakta olan JSON içinden "reply" alanının o ana kadarki değerini çözer.
  static String? _partialReply(String json) {
    final match = _replyStart.firstMatch(json);
    if (match == null) return null;
    final out = StringBuffer();
    var i = match.end;
    while (i < json.length) {
      final c = json[i];
      if (c == '"') break;
      if (c != r'\') {
        out.write(c);
        i++;
        continue;
      }
      if (i + 1 >= json.length) break; // kaçış dizisi henüz tamamlanmadı
      final e = json[i + 1];
      switch (e) {
        case 'n':
          out.write('\n');
        case 't':
          out.write('\t');
        case 'r':
          out.write('\r');
        case 'b':
          out.write('\b');
        case 'f':
          out.write('\f');
        case 'u':
          if (i + 6 > json.length) return out.toString();
          final code = int.tryParse(json.substring(i + 2, i + 6), radix: 16);
          if (code != null) out.writeCharCode(code);
          i += 6;
          continue;
        default:
          out.write(e); // \" \\ \/
      }
      i += 2;
    }
    return out.toString();
  }

  // Anlık Çeviri Fonksiyonu (Ücretsiz, API maliyeti yaratmaz)
  Future<String> translateText(String text) async {
    try {
      final translator = ConsentTranslator();
      final translation = await translator.translate(text, from: 'en', to: 'tr');
      return translation.text;
    } catch (e) {
      return 'Çeviri sırasında hata: $e';
    }
  }
}
