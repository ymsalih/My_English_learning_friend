import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:translator/translator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import 'tts_service.dart';

class ReadingPracticeScreen extends StatefulWidget {
  const ReadingPracticeScreen({super.key});

  @override
  State<ReadingPracticeScreen> createState() => _ReadingPracticeScreenState();
}

class _ReadingPracticeScreenState extends State<ReadingPracticeScreen> {
  final List<String> _categories = [
    'Daily Life',
    'Technology',
    'Science',
    'Travel',
    'Business',
    'Health',
    'Education'
  ];
  String _selectedCategory = 'Daily Life';

  final stt.SpeechToText _speech = stt.SpeechToText();
  final translator = GoogleTranslator();
  final TtsService _ttsService = TtsService();
  final SubscriptionService _subService = SubscriptionService();

  bool _isListening = false;
  bool _speechEnabled = false;
  String _spokenText = "";
  String _currentContent = "";
  
  // Telaffuz testi durumu: 0 = Normal, 1 = Okuma Modu, 2 = Sonuçlar
  int _pronunciationState = 0; 

  // Hangi kelimelerin doğru/yanlış okunduğunu tutan map (Index -> isCorrect)
  Map<int, bool> _wordEvaluations = {};

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  void _initSpeech() async {
    _speechEnabled = await _speech.initialize(
      onError: (val) => debugPrint('STT Error: ${val.errorMsg}'),
      onStatus: (val) {
        debugPrint('STT Status: $val');
        if (val == 'done' || val == 'notListening') {
          if (mounted && _isListening) {
            _stopListeningAndEvaluate(_currentContent);
          }
        }
      },
    );
    setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mikrofon izni alınamadı veya desteklenmiyor.')),
      );
      return;
    }
    
    setState(() {
      _wordEvaluations.clear();
      _spokenText = "";
      _isListening = true;
      _pronunciationState = 1;
    });

    await _speech.listen(
      onResult: (result) {
        setState(() {
          _spokenText = result.recognizedWords;
        });
      },
      localeId: "en_US",
      pauseFor: const Duration(seconds: 2),
      cancelOnError: false,
      partialResults: true,
    );
  }

  void _stopListeningAndEvaluate(String? content) async {
    await _speech.stop();
    if (!mounted) return;
    setState(() {
      _isListening = false;
    });
    if (content != null) {
      _evaluatePronunciation(content);
    }
  }

  void _evaluatePronunciation(String originalText) {
    if (_spokenText.isEmpty) {
      setState(() {
        _pronunciationState = 2; // Sonuç modu ama boş
      });
      return;
    }

    List<String> originalWords = _cleanAndSplit(originalText);
    List<String> spokenWords = _cleanAndSplit(_spokenText);

    Map<int, bool> evaluations = {};
    int spokenIndex = 0;

    for (int i = 0; i < originalWords.length; i++) {
      String targetWord = originalWords[i].toLowerCase();
      bool found = false;

      int searchLimit = spokenIndex + 5;
      if (searchLimit > spokenWords.length) searchLimit = spokenWords.length;

      for (int j = spokenIndex; j < searchLimit; j++) {
        String spokenWord = spokenWords[j].toLowerCase();
        if (spokenWord == targetWord || targetWord.contains(spokenWord) || spokenWord.contains(targetWord)) {
          found = true;
          spokenIndex = j + 1;
          break;
        }
      }

      evaluations[i] = found;
    }

    setState(() {
      _wordEvaluations = evaluations;
      _pronunciationState = 2; 
    });
  }

  List<String> _cleanAndSplit(String text) {
    String cleaned = text.replaceAll(RegExp(r'[^\w\s]'), '').trim();
    if (cleaned.isEmpty) return [];
    return cleaned.split(RegExp(r'\s+'));
  }

  void _playFullText(String text) {
    _ttsService.speak(text);
  }

  Future<void> _showWordTranslationSheet(String word) async {
    final cleanWord = word.replaceAll(RegExp(r'[^\w\s]'), '').trim().toLowerCase();
    if (cleanWord.isEmpty) return;

    // Kelimenin üstüne basılınca hem çeviriyi aç hem seslendir
    _ttsService.speak(cleanWord);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildTranslationSheet(cleanWord),
    );
  }

  Future<void> _showFullTranslationSheet(String fullText) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildFullTranslationSheet(fullText),
    );
  }

  Widget _buildFullTranslationSheet(String text) {
    return FutureBuilder(
      future: translator.translate(text, from: 'en', to: 'tr'),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7), // En fazla %70 kaplar ama metin kısaysa küçülür
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Tüm Metnin Çevirisi",
                    style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                      : snapshot.hasError
                          ? const Text("Çeviri yapılamadı.", style: TextStyle(color: Colors.redAccent))
                          : Text(
                              snapshot.data!.text,
                              style: const TextStyle(color: Colors.cyanAccent, fontSize: 18, height: 1.5, fontWeight: FontWeight.w500),
                            ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTranslationSheet(String englishWord) {
    return FutureBuilder(
      future: translator.translate(englishWord, from: 'en', to: 'tr'),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                englishWord,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const CircularProgressIndicator(color: Colors.deepPurpleAccent)
              else if (snapshot.hasError)
                const Text("Çeviri yapılamadı.", style: TextStyle(color: Colors.redAccent))
              else
                Text(
                  snapshot.data!.text,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _addWordToPool(englishWord, snapshot.data?.text ?? "Çeviri Yok", context),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text("Havuza Ekle", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addWordToPool(String english, String turkish, BuildContext bottomSheetContext) async {
    if (!await _subService.canAddWord()) {
      if (mounted) {
        Navigator.pop(bottomSheetContext); // Close bottom sheet
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallScreen()));
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .add({
        'eng': english,
        'tr': turkish,
        'isLearned': false,
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _subService.incrementWordCount();
      
      if (mounted) {
        Navigator.pop(bottomSheetContext);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kelime havuza eklendi!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Ekleme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Okuma & Telaffuz', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = cat == _selectedCategory;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat;
                        _pronunciationState = 0; 
                        _spokenText = "";
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.deepPurpleAccent : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.deepPurpleAccent : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reading_texts')
                  .where('category', isEqualTo: _selectedCategory)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        "Firebase Hatası:\n${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                      ),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      "Bu kategoride henüz metin yok.\n(Firebase'den ekleyebilirsiniz)",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                    ),
                  );
                }

                final doc = snapshot.data!.docs.first;
                final data = doc.data() as Map<String, dynamic>;
                final title = data['title'] ?? 'Başlıksız';
                final content = data['content'] ?? '';
                final level = data['level'] ?? 'A1';

                return _buildContentArea(title, content, level);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentArea(String title, String content, String level) {
    // İçeriği güncelle ki dinleme otomatik durduğunda bunu bilsin
    if (_currentContent != content) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentContent = content;
          });
        }
      });
    }

    List<String> displayWords = content.split(RegExp(r'\s+'));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => _showFullTranslationSheet(content),
                icon: const Icon(Icons.g_translate, color: Colors.cyanAccent),
                tooltip: "Tüm Metni Çevir",
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(level, style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 10,
              children: List.generate(displayWords.length, (index) {
                final word = displayWords[index];
                
                Color wordColor = Colors.white70;
                TextDecoration decoration = TextDecoration.none;

                if (_pronunciationState == 2) {
                  bool isCorrect = _wordEvaluations[index] ?? false;
                  if (isCorrect) {
                    wordColor = Colors.greenAccent;
                  } else {
                    wordColor = Colors.redAccent;
                    decoration = TextDecoration.underline;
                  }
                }

                return GestureDetector(
                  onTap: () {
                    if (_pronunciationState == 2 && wordColor == Colors.redAccent) {
                      final clean = word.replaceAll(RegExp(r'[^\w\s]'), '');
                      _ttsService.speak(clean);
                    } else {
                      _showWordTranslationSheet(word);
                    }
                  },
                  child: Text(
                    word,
                    style: TextStyle(
                      color: wordColor,
                      fontSize: 18,
                      height: 1.5,
                      decoration: decoration,
                      decorationColor: Colors.redAccent,
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 30),

          if (_pronunciationState == 1)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.deepPurpleAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mic, color: Colors.deepPurpleAccent),
                      const SizedBox(width: 10),
                      Text(
                        _isListening ? "Dinliyorum..." : "İşleniyor...",
                        style: const TextStyle(color: Colors.deepPurpleAccent, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _spokenText.isEmpty ? "Konuşmaya başlayın..." : _spokenText,
                    style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _playFullText(content),
                  icon: const Icon(Icons.volume_up, color: Colors.white),
                  label: const Text('Metni Dinle', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.cyan.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_isListening) {
                      _stopListeningAndEvaluate(content);
                    } else {
                      _startListening();
                    }
                  },
                  icon: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white),
                  label: Text(_isListening ? 'Bitir' : 'Okuyacağım', style: const TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? Colors.redAccent : Colors.deepPurpleAccent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
          ),

          if (_pronunciationState == 2) ...[
            const SizedBox(height: 20),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _pronunciationState = 0;
                    _spokenText = "";
                  });
                },
                icon: const Icon(Icons.refresh, color: Colors.white54),
                label: const Text("Sıfırla", style: TextStyle(color: Colors.white54)),
              ),
            )
          ]
        ],
      ),
    );
  }
}
