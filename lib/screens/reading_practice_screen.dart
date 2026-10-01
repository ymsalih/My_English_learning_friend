import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:translator/translator.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import 'tts_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

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

  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  String _selectedLevel = 'A1';

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
  
  bool _isLoadingTexts = false;
  List<Map<String, dynamic>> _categoryTexts = [];
  int _currentTextIndex = 0;

  // Hangi kelimelerin doğru/yanlış okunduğunu tutan map (Index -> isCorrect)
  Map<int, bool> _wordEvaluations = {};

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _fetchTexts();
  }

  void _fetchTexts() async {
    if (!mounted) return;
    setState(() => _isLoadingTexts = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('reading_texts')
          .where('category', isEqualTo: _selectedCategory)
          .get(const GetOptions(source: Source.serverAndCache));

      if (snap.docs.isNotEmpty) {
        // Firebase karmaşık indexleme hatası (Composite Index) vermesin diye seviyeyi cihazda filtreliyoruz
        var docs = snap.docs.where((d) => (d.data())['level'] == _selectedLevel).toList();
        
        if (docs.isNotEmpty) {
          docs.shuffle(); // Kullanıcı sıkılmasın diye metinleri rastgele karıştırıyoruz
          _categoryTexts = docs.map((d) => d.data()).toList();
          _currentTextIndex = 0;
        } else {
          _categoryTexts = [];
        }
      } else {
        _categoryTexts = [];
      }
    } catch (e) {
      debugPrint("Firebase Fetch Error: $e");
    }

    if (mounted) {
      setState(() => _isLoadingTexts = false);
    }
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
      listenFor: const Duration(minutes: 3), // 3 dakika boyunca kapanmasın
      pauseFor: const Duration(seconds: 10), // Kullanıcı 10 saniye susarsa kapansın (2 çok azdı)
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

    // Telaffuz çalışması günlük seriye sayılır.
    _subService.recordActivity();
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
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Tüm Metnin Çevirisi",
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: snapshot.connectionState == ConnectionState.waiting
                      ? Center(child: CircularProgressIndicator(color: AppColors.secondary))
                      : snapshot.hasError
                          ? Text("Çeviri yapılamadı.", style: TextStyle(color: AppColors.danger))
                          : Text(
                              snapshot.data!.text,
                              style: TextStyle(color: AppColors.secondary, fontSize: 18, height: 1.5, fontWeight: FontWeight.w500),
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
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                englishWord,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              if (snapshot.connectionState == ConnectionState.waiting)
                const CircularProgressIndicator(color: AppColors.primary)
              else if (snapshot.hasError)
                Text("Çeviri yapılamadı.", style: TextStyle(color: AppColors.danger))
              else
                Text(
                  snapshot.data!.text,
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _addWordToPool(englishWord, snapshot.data?.text ?? "Çeviri Yok", context),
                icon: Icon(Icons.add, color: AppColors.textPrimary),
                label: Text("Havuza Ekle", style: TextStyle(color: AppColors.textPrimary)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
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
          const SnackBar(content: Text('Kelime havuza eklendi!'), backgroundColor: AppColors.successFill),
        );
      }
    } catch (e) {
      debugPrint("Ekleme hatası: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Okuma & Telaffuz'),
      ),
      body: AppBackground(
        child: Column(
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
                      _fetchTexts();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textSecondary,
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
          
          const SizedBox(height: 10), // Boşluk

          // --- SEVİYE SEÇİCİ ---
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _levels.length,
              itemBuilder: (context, index) {
                final level = _levels[index];
                final isSelected = level == _selectedLevel;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedLevel = level;
                        _pronunciationState = 0; 
                        _spokenText = "";
                      });
                      _fetchTexts();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.secondary.withOpacity(0.2) : AppColors.surface,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: isSelected ? AppColors.secondary : Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          level,
                          style: TextStyle(
                            color: isSelected ? AppColors.secondary : AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 10), // Boşluk

          Expanded(
            child: _isLoadingTexts 
              ? Center(child: CircularProgressIndicator(color: AppColors.secondary))
              : _categoryTexts.isEmpty
                ? Center(
                    child: Text(
                      "Bu kategori ve seviyede henüz metin yok.\n(Firebase'den ekleyebilirsiniz)",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: _buildContentArea(
                          _categoryTexts[_currentTextIndex]['title'] ?? 'Başlıksız',
                          _categoryTexts[_currentTextIndex]['content'] ?? '',
                          _categoryTexts[_currentTextIndex]['level'] ?? 'A1',
                        ),
                      ),
                      if (_categoryTexts.length > 1)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _currentTextIndex = (_currentTextIndex + 1) % _categoryTexts.length;
                                _pronunciationState = 0;
                                _spokenText = "";
                              });
                            },
                            icon: Icon(Icons.refresh, color: AppColors.textPrimary),
                            label: Text("Farklı Bir Metin Getir", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildScoreCard() {
    final total = _wordEvaluations.length;
    if (total == 0) return const SizedBox.shrink();
    final correct = _wordEvaluations.values.where((v) => v).length;
    final score = (correct / total * 100).round();
    final color = score >= 80 ? AppColors.success : (score >= 50 ? AppColors.gold : AppColors.danger);
    return AppCard(
      borderColor: color.withValues(alpha: 0.45),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
                Center(child: Text('%$score', style: AppText.heading(size: 15))),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score >= 80 ? 'Harika telaffuz!' : (score >= 50 ? 'İyi gidiyorsun' : 'Biraz daha pratik'),
                  style: AppText.heading(size: 17),
                ),
                const SizedBox(height: 2),
                Text(
                  '$correct / $total kelime doğru. Kırmızı kelimelere dokunup dinleyebilirsin.',
                  style: AppText.caption,
                ),
              ],
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
                  style: AppText.heading(size: 22),
                ),
              ),
              IconButton(
                onPressed: () => _showFullTranslationSheet(content),
                icon: Icon(Icons.g_translate, color: AppColors.secondary),
                tooltip: "Tüm Metni Çevir",
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.secondary.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                child: Text(level, style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Wrap(
              spacing: 6,
              runSpacing: 10,
              children: List.generate(displayWords.length, (index) {
                final word = displayWords[index];
                
                Color wordColor = AppColors.textPrimary;
                TextDecoration decoration = TextDecoration.none;

                if (_pronunciationState == 2) {
                  bool isCorrect = _wordEvaluations[index] ?? false;
                  if (isCorrect) {
                    wordColor = AppColors.success;
                  } else {
                    wordColor = AppColors.danger;
                    decoration = TextDecoration.underline;
                  }
                }

                return GestureDetector(
                  onTap: () {
                    if (_pronunciationState == 2 && wordColor == AppColors.danger) {
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
                      decorationColor: AppColors.danger,
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
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mic, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Text(
                        _isListening ? "Dinliyorum..." : "İşleniyor...",
                        style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _spokenText.isEmpty ? "Konuşmaya başlayın..." : _spokenText,
                    style: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _playFullText(content),
                  icon: Icon(Icons.volume_up, color: AppColors.textPrimary),
                  label: Text('Metni Dinle', style: TextStyle(color: AppColors.textPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.3),
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
                  icon: Icon(_isListening ? Icons.stop : Icons.mic, color: AppColors.textPrimary),
                  label: Text(_isListening ? 'Bitir' : 'Okuyacağım', style: TextStyle(color: AppColors.textPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isListening ? AppColors.dangerFill : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ),
            ],
          ),

          if (_pronunciationState == 2) ...[
            const SizedBox(height: 20),
            _buildScoreCard(),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _pronunciationState = 0;
                    _spokenText = "";
                  });
                },
                icon: Icon(Icons.refresh, color: AppColors.textMuted),
                label: Text("Sıfırla", style: TextStyle(color: AppColors.textMuted)),
              ),
            )
          ]
        ],
      ),
    );
  }
}
