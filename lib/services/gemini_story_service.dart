import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class GeminiStoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GenerativeModel? _model;

  GeminiStoryService() {
    _initModel();
  }

  void _initModel() {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY bulunamadı. Lütfen .env dosyasını kontrol edin.');
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        responseMimeType: "application/json",
      ),
    );
  }

  /// Firestore 'global_stories' havuzunu kontrol eder, varsa oradan çeker, yoksa Gemini'dan üretip havuza kaydeder.
  Future<Map<String, dynamic>> fetchOrGenerateStoryTree(String genre, String level, {bool forceGenerate = false}) async {
    try {
      if (!forceGenerate) {
        // 1. Önce Firestore havuzunda var mı diye bak (Sıfır API maliyeti için)
        final poolSnapshot = await _firestore
            .collection('global_stories')
            .where('genre', isEqualTo: genre)
            .where('level', isEqualTo: level)
            .limit(10) 
            .get();

        if (poolSnapshot.docs.isNotEmpty) {
          final docs = poolSnapshot.docs;
          docs.shuffle();
          debugPrint("Hikaye havuzdan çekildi (Sıfır Maliyet!)");
          return docs.first.data();
        }
      }

      // 2. Havuzda yoksa veya forceGenerate true ise Gemini'den üret
      debugPrint("Gemini'ye soruluyor...");
      final generatedData = await _generateFromGemini(genre, level);

      // 3. Üretilen veriyi diğer kullanıcılar için havuza kaydet
      if (generatedData != null) {
        generatedData['genre'] = genre;
        generatedData['level'] = level;
        generatedData['createdAt'] = FieldValue.serverTimestamp();
        await _firestore.collection('global_stories').add(generatedData);
        return generatedData;
      }
      
      throw Exception('Hikaye üretilemedi.');
    } catch (e) {
      debugPrint("Hikaye servisi hatası: $e");
      throw Exception('Hikaye yüklenirken bir hata oluştu: $e');
    }
  }

  Future<Map<String, dynamic>?> _generateFromGemini(String genre, String level) async {
    if (_model == null) return null;

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
       "correctIndex": 1
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

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text != null && text.isNotEmpty) {
        return jsonDecode(text) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint("Gemini Üretim Hatası: $e");
    }
    return null;
  }
}
