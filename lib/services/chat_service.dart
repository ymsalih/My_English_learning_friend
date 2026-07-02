import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:translator/translator.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  GenerativeModel? _model;
  String _currentMode = '';
  String _currentLevel = '';

  void _initModel(String mode, String userLevel) {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY bulunamadı. Lütfen .env dosyasını kontrol edin.');
    }

    _currentMode = mode;
    _currentLevel = userLevel;

    final systemInstruction = _getSystemPrompt(mode, userLevel);

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
      systemInstruction: Content.system(systemInstruction),
    );
  }

  String _getSystemPrompt(String mode, String userLevel) {
    String baseInstructions = "You are a friendly AI English tutor. "
        "The user's English level is $userLevel. Adapt your vocabulary and grammar accordingly. "
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

  Future<Map<String, dynamic>> sendMessage(
      String message, String mode, String userLevel, List<Content> history) async {
    
    if (_model == null || _currentMode != mode || _currentLevel != userLevel) {
      _initModel(mode, userLevel);
    }

    try {
      final chatSession = _model!.startChat(
        history: history,
      );

      final response = await chatSession.sendMessage(Content.text(message));
      
      if (response.text != null && response.text!.isNotEmpty) {
         try {
           final jsonResponse = jsonDecode(response.text!);
           return jsonResponse;
         } catch(e) {
           // Bazen AI JSON yapısını bozabilir veya Markdown ```json formatında gönderebilir
           String cleanText = response.text!.replaceAll('```json', '').replaceAll('```', '').trim();
           return jsonDecode(cleanText);
         }
      } else {
        throw Exception("Yapay zekadan boş yanıt geldi.");
      }
    } catch (e) {
      throw Exception("Mesaj gönderilemedi: $e");
    }
  }

  // Mesaj geçmişini Firestore'a kaydetme
  Future<void> saveMessageToHistory(String mode, String userText, Map<String, dynamic> aiResponse) async {
    final user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).collection('chatHistory').add({
        'mode': mode,
        'userText': userText,
        'aiReply': aiResponse['reply'] ?? '',
        'correction': aiResponse['correction'] ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
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
