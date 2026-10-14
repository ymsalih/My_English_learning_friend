import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'ai_client.dart';
import 'ai_consent.dart';

class GeminiStoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Firestore 'global_stories' havuzunu kontrol eder, varsa oradan çeker, yoksa Gemini'dan üretip havuza kaydeder.
  Future<Map<String, dynamic>> fetchOrGenerateStoryTree(String genre, String level, {bool forceGenerate = false}) async {
    try {
      if (!forceGenerate) {
        // 1. Önce Firestore havuzunda var mı diye bak (Sıfır API maliyeti için)
        final query = _firestore
            .collection('global_stories')
            .where('genre', isEqualTo: genre)
            .where('level', isEqualTo: level)
            .limit(10);

        // Cihazda önbellek varsa hikaye anında açılır; havuz arka planda
        // sunucudan tazelenir ve bir sonraki açılışta yeni hikayeler gelir.
        QuerySnapshot<Map<String, dynamic>>? poolSnapshot;
        try {
          poolSnapshot = await query.get(const GetOptions(source: Source.cache));
        } catch (_) {}

        if (poolSnapshot != null && poolSnapshot.docs.isNotEmpty) {
          unawaited(query.get(const GetOptions(source: Source.server)).then(
                (_) {},
                onError: (Object e) => debugPrint("Havuz tazeleme hatası: $e"),
              ));
        } else {
          poolSnapshot = await query.get();
        }

        if (poolSnapshot.docs.isNotEmpty) {
          final docs = [...poolSnapshot.docs]..shuffle();
          debugPrint("Hikaye havuzdan çekildi (Sıfır Maliyet!)");
          return docs.first.data();
        }
      }

      // 2. Havuzda yoksa veya forceGenerate true ise Gemini'den üret
      debugPrint("Gemini'ye soruluyor...");
      final generatedData = await _generateFromGemini(genre, level);

      // 3. Üretilen veriyi diğer kullanıcılar için havuza kaydet
      if (generatedData != null) {
        final poolEntry = {
          ...generatedData,
          'genre': genre,
          'level': level,
          'createdAt': FieldValue.serverTimestamp(),
        };
        // Kullanıcı havuz yazmasının sunucu onayını beklemez.
        unawaited(_firestore.collection('global_stories').add(poolEntry).then(
              (_) {},
              onError: (Object e) => debugPrint("Havuza kaydetme hatası: $e"),
            ));
        return {...generatedData, 'genre': genre, 'level': level};
      }

      throw Exception('Hikaye üretilemedi.');
    } catch (e) {
      debugPrint("Hikaye servisi hatası: $e");
      throw Exception('Hikaye yüklenirken bir hata oluştu: $e');
    }
  }

  /// Hikayeyi sunucudaki yapay zeka işlevine ürettirir (talimat ve JSON
  /// şeması sunucuda; uygulama yalnızca tür ve seviyeyi gönderir).
  Future<Map<String, dynamic>?> _generateFromGemini(String genre, String level) async {
    for (var attempt = 0; attempt < AiClient.maxAttempts; attempt++) {
      try {
        final text = await AiClient.generateStory(genre: genre, level: level);
        if (text.isNotEmpty) {
          return jsonDecode(text) as Map<String, dynamic>;
        }
        return null;
      } catch (e) {
        if (e is AiConsentException) rethrow;
        // Günlük hak dolduysa veya oturum geçersizse tekrar denemenin anlamı yok;
        // ekran uygun mesajı göstersin.
        if (e is AiException && (e.status == 'LIMIT_REACHED' || e.status == 'UNAUTHENTICATED')) {
          rethrow;
        }
        debugPrint("Gemini Üretim Hatası: $e");
        if (!AiClient.isRetryable(e) || attempt + 1 >= AiClient.maxAttempts) {
          return null;
        }
        await Future.delayed(AiClient.backoff(attempt));
      }
    }
    return null;
  }
}
