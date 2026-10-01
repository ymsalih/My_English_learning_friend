import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
import 'ai_client.dart';

class ChatService {
  // Mod ve seviyeye göre hazırlanan istek ayarları.
  Map<String, Object?>? _generationConfig;
  String? _systemInstruction;
  String _currentMode = '';
  String _currentLevel = '';

  /// Modele gönderilen en fazla geçmiş mesaj sayısı (10 soru-cevap).
  /// Geçmiş sınırsız büyürse her istek yavaşlar ve pahalanır.
  static const int _maxHistory = 20;

  /// Bir sonraki parça bu süre içinde gelmezse istek zaman aşımına uğrar.
  static const Duration _chunkTimeout = Duration(seconds: 25);

  // "reply" önce gelir: kullanıcı cevabı akarken okumaya başlar,
  // düzeltme en sonda tamamlanır.
  static final Map<String, Object?> _responseSchema = AiClient.objectSchema({
    'reply': AiClient.stringSchema(
      description: 'Your conversational response in English',
    ),
    'correction': AiClient.objectSchema({
      'original': AiClient.stringSchema(),
      'corrected': AiClient.stringSchema(),
      'explanation': AiClient.stringSchema(),
    }),
  });

  static final RegExp _replyStart = RegExp(r'"reply"\s*:\s*"');

  void _initModel(String mode, String userLevel) {
    _currentMode = mode;
    _currentLevel = userLevel;

    _generationConfig = {
      'responseMimeType': 'application/json',
      'responseSchema': _responseSchema,
      'thinkingConfig': AiClient.chatThinking,
    };
    _systemInstruction = _getSystemPrompt(mode, userLevel);
  }

  String _getSystemPrompt(String mode, String userLevel) {
    String baseInstructions = "You are a friendly AI English tutor. "
        "The user's English level is $userLevel. Adapt your vocabulary and grammar accordingly. "
        "Keep your reply short and natural like a real chat message: 1-3 sentences, "
        "unless the user explicitly asks for a longer answer. Keep the explanation to one short sentence. "
        "Always respond in the following JSON format ONLY, do not wrap it in markdown: "
        '{"reply": "Your conversational response in English", '
        '"correction": {"original": "The user\'s original sentence with mistakes", '
        '"corrected": "The grammatically correct version", '
        '"explanation": "Explanation of the correction in Turkish"}} '
        "If there are no grammar mistakes in the user's message, set original, corrected, and explanation fields inside correction to empty strings.";

    switch (mode) {
      case 'Gramer':
        return "$baseInstructions Focus mainly on grammar rules. Ask questions to test their grammar.";
      case 'Kelime':
        return "$baseInstructions Introduce new vocabulary words related to their level. Ask them to use new words.";
      case 'Günlük':
        return "$baseInstructions Have a casual daily conversation (small talk, hobbies, daily life).";
      case 'İş':
        return "$baseInstructions Roleplay as a colleague or business partner. Use professional business English.";
      case 'Seyahat':
        return "$baseInstructions Roleplay travel scenarios (airport, hotel, restaurant).";
      case 'Serbest':
      default:
        return "$baseInstructions Have a free-flowing conversation on any topic the user chooses.";
    }
  }

  /// Chat ekranı açılırken çağrılır: bağlantı, kullanıcı ilk mesajını
  /// yazarken hazırlanır.
  void warmUp() => AiClient.warmUp(AiClient.chatModel);

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
    if (_generationConfig == null || _currentMode != mode || _currentLevel != userLevel) {
      _initModel(mode, userLevel);
    }

    final recent = history.length > _maxHistory
        ? history.sublist(history.length - _maxHistory)
        : history;
    final contents = [...recent, AiClient.userContent(message)];

    for (var attempt = 0; ; attempt++) {
      var receivedText = false;
      try {
        final buffer = StringBuffer();
        var lastReply = '';
        final stream = AiClient.streamText(
          model: AiClient.chatModel,
          contents: contents,
          generationConfig: _generationConfig,
          systemInstruction: _systemInstruction,
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
        try {
          return jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {
          // Şema kullanıldığı için nadirdir; yine de Markdown sarmalını temizle.
          final cleanText = raw.replaceAll('```json', '').replaceAll('```', '').trim();
          return jsonDecode(cleanText) as Map<String, dynamic>;
        }
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
      final translator = GoogleTranslator();
      final translation = await translator.translate(text, from: 'en', to: 'tr');
      return translation.text;
    } catch (e) {
      return 'Çeviri sırasında hata: $e';
    }
  }
}
