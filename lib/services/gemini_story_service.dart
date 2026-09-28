import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'ai_client.dart';

class GeminiStoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // Yapıyı garanti eder: bozuk JSON yüzünden başarısız üretim (ve boşa
  // harcanan istek) olmaz.
  static final Map<String, Object?> _storySchema = AiClient.objectSchema({
    'title': AiClient.stringSchema(),
    'nodes': AiClient.arraySchema(AiClient.objectSchema({
      'id': AiClient.stringSchema(),
      'text': AiClient.stringSchema(),
      'choices': AiClient.arraySchema(AiClient.objectSchema({
        'text': AiClient.stringSchema(),
        'next_id': AiClient.stringSchema(),
      })),
      'is_ending': AiClient.booleanSchema(),
    })),
    'questions': AiClient.arraySchema(AiClient.objectSchema({
      'question': AiClient.stringSchema(),
      'options': AiClient.arraySchema(AiClient.stringSchema()),
      'correctIndex': AiClient.integerSchema(),
      'explanation': AiClient.stringSchema(),
    })),
  });

  static final Map<String, Object?> _generationConfig = {
    'temperature': 0.7,
    'responseMimeType': 'application/json',
    'responseSchema': _storySchema,
    'thinkingConfig': AiClient.storyThinking,
  };

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

  Future<Map<String, dynamic>?> _generateFromGemini(String genre, String level) async {
    final prompt = '''
You are a master storyteller for English language learners.
Generate an interactive "Choose your own adventure" story tree in English.
Genre: $genre
English Level: $level

Format the response purely as a JSON object matching this exact schema:
{
  "title": "A catchy title for the story",
  "nodes": [
    {
      "id": "1",
      "text": "Story text for this node. Keep it engaging and appropriate for $level level.",
      "choices": [
         {"text": "Choice 1 text in English...", "next_id": "2"},
         {"text": "Choice 2 text in English...", "next_id": "3"}
      ],
      "is_ending": false
    }
  ],
  "questions": [
    {
       "question": "A reading comprehension question about the story?",
       "options": ["A", "B", "C", "D"],
       "correctIndex": 1,
       "explanation": "Brief explanation in English of why this is the correct answer."
    }
  ]
}

Strict Rules:
1. Node "id": "1" is the starting point.
2. The tree MUST be exactly depth 3. So Node 1 leads to Nodes 2 and 3. Node 2 leads to 4 and 5. Node 3 leads to 6 and 7. Nodes 4,5,6,7 are endings.
3. For ending nodes (4,5,6,7), set "is_ending": true and "choices": [].
4. Keep the text simple, clear, and perfectly aligned with the CEFR $level level.
5. Create exactly 3 "questions" about the general plot or vocabulary of the story.
''';

    for (var attempt = 0; attempt < AiClient.maxAttempts; attempt++) {
      try {
        final text = await AiClient.generateText(
          model: AiClient.storyModel,
          contents: [AiClient.userContent(prompt)],
          generationConfig: _generationConfig,
        );
        if (text.isNotEmpty) {
          return jsonDecode(text) as Map<String, dynamic>;
        }
        return null;
      } catch (e) {
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
