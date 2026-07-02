import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/gemini_story_service.dart';
import 'tts_service.dart';
import 'package:translator/translator.dart';
import 'dart:ui';

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final GeminiStoryService _storyService = GeminiStoryService();
  final TtsService _ttsService = TtsService();

  String _selectedGenre = 'Macera';
  String _selectedLevel = 'A2';

  final List<String> _genres = [
    'Macera',
    'Gizem',
    'Bilim Kurgu',
    'Günlük Yaşam',
    'Fantastik',
  ];
  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1'];

  bool _isLoading = false;
  Map<String, dynamic>? _storyTree;
  Map<String, dynamic>? _currentNode;

  bool _showQuiz = false;
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _quizCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadUserLevel();
  }

  Future<void> _loadUserLevel() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data()?['level'] != null && mounted) {
        setState(() {
          _selectedLevel = doc.data()!['level'];
        });
      }
    }
  }

  Future<void> _startStory(bool forceGenerate) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (forceGenerate) {
      // Limit kontrolü
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final isPro = doc.data()?['isPro'] ?? false;

      if (!isPro) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final lastStoryDate = doc.data()?['last_story_date'] ?? '';
        final storyUsageCount = doc.data()?['story_usage_count'] ?? 0;

        if (lastStoryDate == today && storyUsageCount >= 1) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Günlük "Yeni Hikaye Üretme" limitiniz doldu (1/1). Havuzdaki hikayeleri sınırsız okuyabilir veya Pro\'ya geçebilirsiniz.',
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'last_story_date': today,
              'story_usage_count': lastStoryDate == today
                  ? storyUsageCount + 1
                  : 1,
            });
      }
    }

    setState(() {
      _isLoading = true;
      _storyTree = null;
      _currentNode = null;
      _showQuiz = false;
      _quizCompleted = false;
      _currentQuestionIndex = 0;
      _score = 0;
    });

    try {
      final tree = await _storyService.fetchOrGenerateStoryTree(
        _selectedGenre,
        _selectedLevel,
        forceGenerate: forceGenerate,
      );
      if (mounted) {
        setState(() {
          _storyTree = tree;
          _currentNode = _findNodeById('1');
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic>? _findNodeById(String id) {
    if (_storyTree == null) return null;
    final nodes = _storyTree!['nodes'] as List<dynamic>;
    return nodes.firstWhere((n) => n['id'] == id, orElse: () => null);
  }

  void _makeChoice(String nextId) {
    setState(() {
      _currentNode = _findNodeById(nextId);
    });
  }

  Future<String> _fallbackTranslate(String text) async {
    try {
      final translator = GoogleTranslator();
      final res = await translator.translate(text, from: 'en', to: 'tr');
      return res.text;
    } catch (e) {
      return "Hata oluştu";
    }
  }

  Future<void> _showWordTranslation(String word) async {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) return;

    // Sadece tek kelime mi diye kontrol et
    final isSingleWord = !cleanWord.contains(' ');
    // Eğer tek kelimeyse gereksiz noktalama işaretlerini sil (örn: "hello," -> "hello")
    final queryText = isSingleWord
        ? cleanWord.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase()
        : cleanWord;

    String translated = "Çevriliyor...";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (translated == "Çevriliyor...") {
              if (isSingleWord) {
                FirebaseFirestore.instance.collection('dictionary_cache').doc("en_$queryText").get().then((doc) async {
                  if (doc.exists) {
                     setModalState(() => translated = doc.data()!['mainTranslation'] ?? 'Bulunamadı');
                  } else {
                     final res = await _fallbackTranslate(queryText);
                     setModalState(() => translated = res);
                  }
                });
              } else {
                _fallbackTranslate(queryText).then((res) {
                  setModalState(() => translated = res);
                });
              }
            }

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      cleanWord.length > 30 ? "Metin Çevirisi" : cleanWord,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.purpleAccent,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          translated,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTappableText(String text) {
    final words = text.split(' ');
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: words.map((word) {
        return GestureDetector(
          onTap: () => _showWordTranslation(word),
          child: Text(
            word,
            style: const TextStyle(
              fontSize: 18,
              height: 1.6,
              color: Colors.white,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStoryContent() {
    if (_currentNode == null) return const SizedBox.shrink();

    final text = _currentNode!['text'] ?? '';
    final choices = _currentNode!['choices'] as List<dynamic>? ?? [];
    final isEnding = _currentNode!['is_ending'] ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.menu_book, color: Colors.purpleAccent),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.g_translate,
                            color: Colors.blueAccent,
                          ),
                          tooltip: 'Tümünü Çevir',
                          onPressed: () => _showWordTranslation(text),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.volume_up,
                            color: Colors.purpleAccent,
                          ),
                          tooltip: 'Seslendir (İngilizce)',
                          onPressed: () => _ttsService.speak(text),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildTappableText(text),
              ],
            ),
          ),
          const SizedBox(height: 30),
          if (!isEnding) ...[
            Text(
              'Ne yapmak istersin?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.9),
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            ...choices.map(
              (choice) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: Colors.blueAccent.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: OutlinedButton(
                  onPressed: () => _makeChoice(choice['next_id']),
                  onLongPress: () => _showWordTranslation(choice['text']),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    backgroundColor: const Color(0xFF1E293B).withOpacity(0.8),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.blueAccent.withOpacity(0.6), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(
                    choice['text'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ] else ...[
            const Text(
              'Hikaye Sonu 🎉',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.purpleAccent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.purpleAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => setState(() => _showQuiz = true),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: const Color(0xFF8B5CF6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Okuma Anlama Testini Çöz',
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuiz() {
    final questions = _storyTree!['questions'] as List<dynamic>? ?? [];
    if (questions.isEmpty) return const Center(child: Text("Test bulunamadı.", style: TextStyle(color: Colors.white)));

    if (_quizCompleted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
            const SizedBox(height: 20),
            const Text(
              'Tebrikler!',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
              ),
              child: Text(
                'Skorun: $_score / ${questions.length}',
                style: const TextStyle(fontSize: 22, color: Colors.purpleAccent, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
                ],
              ),
              child: ElevatedButton(
                onPressed: () => setState(() => _storyTree = null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text(
                  'Yeni Hikaye Seç',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final currentQ = questions[_currentQuestionIndex];
    final options = currentQ['options'] as List<dynamic>;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Soru ${_currentQuestionIndex + 1}/${questions.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            ),
            child: Text(
              currentQ['question'],
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 30),
          ...options.asMap().entries.map((entry) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: Colors.purpleAccent.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: OutlinedButton(
                onPressed: () {
                  if (entry.key == currentQ['correctIndex']) {
                    _score++;
                  }
                  if (_currentQuestionIndex < questions.length - 1) {
                    setState(() => _currentQuestionIndex++);
                  } else {
                    setState(() => _quizCompleted = true);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(18),
                  backgroundColor: const Color(0xFF1E293B).withOpacity(0.8),
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(entry.value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSetupScreen() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // BİLGİLENDİRME KARTI (Glassmorphism + Glow)
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.purpleAccent.withOpacity(0.3), width: 1.5),
              boxShadow: [
                BoxShadow(color: Colors.purpleAccent.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_stories, size: 55, color: Colors.purpleAccent),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Kendi Hikayenin Kahramanı Ol!',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Text(
                  'Bu modülde sıradan bir okuyucu değilsiniz. Her sayfanın sonunda hikayenin gidişatına siz karar verirsiniz.\n\nHem okuma pratiği yapın, hem bilmediğiniz kelimeleri çevirin, hem de maceranızı kendiniz çizin!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.white.withOpacity(0.8), height: 1.6),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 35),
          const Text(
            '1. Tür ve Seviye Seçimi',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 15),

          // Genre Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.7),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedGenre,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E293B),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                items: _genres.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                onChanged: (v) => setState(() => _selectedGenre = v!),
              ),
            ),
          ),
          const SizedBox(height: 15),
          
          // Level Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withOpacity(0.7),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLevel,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E293B),
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                items: _levels.map((l) => DropdownMenuItem(value: l, child: Text('Seviye: $l'))).toList(),
                onChanged: (v) => setState(() => _selectedLevel = v!),
              ),
            ),
          ),

          const SizedBox(height: 35),
          const Text(
            '2. Hikayeye Başla',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 15),

          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5)),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : () => _startStory(false),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.library_books, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Havuzdan Oku', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Daha önce üretilmiş hikayeleri ücretsiz oku.', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 15),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: OutlinedButton(
              onPressed: _isLoading ? null : () => _startStory(true),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                side: BorderSide(color: const Color(0xFF3B82F6).withOpacity(0.8), width: 2),
                backgroundColor: const Color(0xFF1E293B).withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.auto_awesome, color: Colors.blueAccent),
                      SizedBox(width: 10),
                      Text('Sıfırdan Üret', style: TextStyle(fontSize: 18, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Yapay zekaya yeni bir macera yazdır. (Günde 1 kez)', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
                ],
              ),
            ),
          ),

          if (_isLoading) ...[
            const SizedBox(height: 40),
            const Center(child: CircularProgressIndicator(color: Colors.purpleAccent)),
            const SizedBox(height: 20),
            Text(
              'Yapay zeka hikaye evrenini inşa ediyor...\nLütfen bekleyin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 30),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _storyTree == null
              ? 'Etkileşimli Hikaye'
              : (_storyTree!['title'] ?? 'Hikaye'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_storyTree != null && !_showQuiz)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: "Hikayeyi Kapat",
              onPressed: () => setState(() {
                _storyTree = null;
                _showQuiz = false;
              }),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Uzay Arka Plan (Glow Effects)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Positioned(
            top: -100, left: -50,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.blueAccent.withOpacity(0.15), Colors.transparent],
                  stops: const [0.1, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50, right: -50,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.purpleAccent.withOpacity(0.15), Colors.transparent],
                  stops: const [0.1, 1.0],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: _storyTree == null
                ? _buildSetupScreen()
                : (_showQuiz ? _buildQuiz() : _buildStoryContent()),
          ),
        ],
      ),
    );
  }
}
