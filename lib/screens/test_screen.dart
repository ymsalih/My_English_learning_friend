import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'tts_service.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final TtsService _ttsService = TtsService();
  final SubscriptionService _subService = SubscriptionService();

  List<Map<String, dynamic>> _allAvailableWords = [];
  List<Map<String, dynamic>> _words = [];

  bool _isLoading = true;
  bool _isSetupMode = true;
  int _selectedWordCount = 10;

  int _currentUsage = 0;
  int _currentLimit = 40;
  bool _isUnlimited = false;

  GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();
  bool _isProcessing = false;

  final ValueNotifier<Offset> _swipePosition = ValueNotifier<Offset>(Offset.zero);
  final ValueNotifier<double> _swipeAngle = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isDragging = ValueNotifier<bool>(false);

  // --- 📊 İSTATİSTİK TAKİP DEĞİŞKENLERİ ---
  int _totalWordsInSession = 0;
  int _forgotCount = 0;
  int _rememberedCount = 0;
  int _masteredCount = 0;
  bool _testCompleted = false;

  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _checkAvailableWords();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final usage = await _subService.getActionUsage('testCount');
    if (mounted) {
      setState(() {
        _currentUsage = usage['current'] ?? 0;
        _currentLimit = usage['limit'] ?? 40;
        _isUnlimited = _currentLimit >= 999999;
      });
    }
  }

  @override
  void dispose() {
    _swipePosition.dispose();
    _swipeAngle.dispose();
    _isDragging.dispose();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await _ttsService.speak(text);
  }

  Future<void> _checkAvailableWords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        QuerySnapshot snapshot;
        try {
          snapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('words')
              .get(const GetOptions(source: Source.cache));
          if (snapshot.docs.isEmpty) {
            snapshot = await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('words')
                .get(const GetOptions(source: Source.server));
          }
        } catch (e) {
          snapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('words')
              .get(const GetOptions(source: Source.server));
        }

        final wordsList = snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['docId'] = doc.id;
              return data;
            })
            .where((word) => word['isLearned'] != true)
            .toList();

        setState(() {
          _allAvailableWords = wordsList;
          if (wordsList.isNotEmpty) {
            _selectedWordCount = wordsList.length > 20 ? 20 : wordsList.length;
          }
          _isLoading = false;
        });
      } catch (e) {
        debugPrint("Kelime çekme hatası: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  void _startTest() async {
    final int remaining = await _subService.getRemainingTestCount();
    if (remaining <= 0) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallScreen()));
      }
      return;
    }
    
    await _loadLimits();
    
    setState(() {
      // Limit the test to remaining limit if needed
      if (_selectedWordCount > remaining) {
        _selectedWordCount = remaining;
      }
      
      _allAvailableWords.sort((a, b) {
        Timestamp? t1 = a['lastReviewed'] as Timestamp?;
        Timestamp? t2 = b['lastReviewed'] as Timestamp?;
        int time1 = t1?.millisecondsSinceEpoch ?? 0;
        int time2 = t2?.millisecondsSinceEpoch ?? 0;
        return time1.compareTo(time2);
      });

      List<Map<String, dynamic>> selectedSessionWords = _allAvailableWords.take(_selectedWordCount).toList();
      selectedSessionWords.shuffle(Random());

      _words = selectedSessionWords;
      _totalWordsInSession = selectedSessionWords.length;
      _forgotCount = 0;
      _rememberedCount = 0;
      _masteredCount = 0;
      _testCompleted = false;
      _isSetupMode = false;
    });
  }

  Future<void> _saveTestResultsToFirebase(int correctCount, int wrongCount, int masteredCount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    try {
      await userRef.set({
        'stats': {
          'totalTests': FieldValue.increment(1),
          'totalCorrect': FieldValue.increment(correctCount),
          'totalWrong': FieldValue.increment(wrongCount),
          'totalMastered': FieldValue.increment(masteredCount),
          'totalLearned': FieldValue.increment(masteredCount), // 🚀 O(1) Optimizasyonu
        },
      }, SetOptions(merge: true));

      int totalQuestions = correctCount + wrongCount;
      double successRate = totalQuestions > 0 ? (correctCount / totalQuestions) * 100 : 0;
      await userRef.collection('test_history').add({
        'timestamp': FieldValue.serverTimestamp(),
        'correct': correctCount,
        'wrong': wrongCount,
        'mastered': masteredCount,
        'total': totalQuestions,
        'successRate': successRate,
      });
    } catch (e) {
      debugPrint("İstatistikler kaydedilirken hata oluştu: $e");
    }
  }

  Future<void> _animateAndMove(String action, Offset targetPosition) async {
    if (_isProcessing) return;

    _isProcessing = true;
    _swipePosition.value = targetPosition;
    _swipeAngle.value = targetPosition.dx > 0 ? 30 : (targetPosition.dx < 0 ? -30 : 0);
    await Future.delayed(const Duration(milliseconds: 300));
    _handleWordResult(action);
    _swipePosition.value = Offset.zero;
    _swipeAngle.value = 0.0;
    _isProcessing = false;
  }

  void _handleWordResult(String action) {
    final currentWord = _words[0];
    final String docId = currentWord['docId'];
    final user = FirebaseAuth.instance.currentUser;

    final Map<String, dynamic> updateData = {
      'lastReviewed': FieldValue.serverTimestamp(),
    };

    if (action == 'forgot') {
      _forgotCount++;
    } else if (action == 'remembered') {
      _rememberedCount++;
    } else if (action == 'mastered') {
      _masteredCount++;
      updateData['isLearned'] = true;
    }

    // Increment word limit counter
    _subService.incrementTest();

    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .doc(docId)
          .update(updateData);
    }

    setState(() {
      if (!_isUnlimited) {
        _currentUsage++;
      }
      _words.removeAt(0);
      cardKey = GlobalKey<FlipCardState>();

      if (_words.isEmpty) {
        _testCompleted = true;
        int correctAnswers = _masteredCount + _rememberedCount;
        _saveTestResultsToFirebase(correctAnswers, _forgotCount, _masteredCount);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _isSetupMode ? 'Kendini Test Et' : 'Öğrenme Zamanı',
          style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.5)),
              ),
              child: Text(
                _isUnlimited ? "Sınırsız" : "$_currentUsage/$_currentLimit",
                style: const TextStyle(
                  color: Colors.purpleAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
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
            top: -100, right: -50,
            child: Container(
              width: 300, height: 300,
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.purpleAccent))
                : _allAvailableWords.isEmpty
                ? _buildEmptyState()
                : _isSetupMode
                ? _buildSetupScreen()
                : _testCompleted
                ? _buildResultsScreen()
                : _buildTestScreen(),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.8),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.settings_suggest_rounded, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                "Test Ayarları",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 10),
              Text(
                "Havuzda öğrenilmeyi bekleyen toplam\n${_allAvailableWords.length} kelimen var.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.6)),
              ),
              const SizedBox(height: 30),
              Text(
                "$_selectedWordCount Kelime",
                style: const TextStyle(fontSize: 35, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.indigoAccent,
                  inactiveTrackColor: Colors.white.withOpacity(0.1),
                  thumbColor: Colors.indigoAccent,
                  overlayColor: Colors.indigoAccent.withOpacity(0.2),
                  trackHeight: 6.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                ),
                child: Slider(
                  value: _selectedWordCount.toDouble(),
                  min: 1,
                  max: _allAvailableWords.length.toDouble(),
                  divisions: _allAvailableWords.length > 1 ? _allAvailableWords.length - 1 : 1,
                  onChanged: (double value) {
                    setState(() {
                      _selectedWordCount = value.toInt();
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ...[10, 20, 50].map((count) {
                    if (count > _allAvailableWords.length) return const SizedBox.shrink();
                    bool isSelected = _selectedWordCount == count;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedWordCount = count),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.indigoAccent : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? Colors.indigoAccent : Colors.transparent),
                        ),
                        child: Text("$count", style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.white70)),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () => setState(() => _selectedWordCount = _allAvailableWords.length),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _selectedWordCount == _allAvailableWords.length ? Colors.indigoAccent : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _selectedWordCount == _allAvailableWords.length ? Colors.indigoAccent : Colors.transparent),
                      ),
                      child: Text("Hepsi", style: TextStyle(fontWeight: FontWeight.bold, color: _selectedWordCount == _allAvailableWords.length ? Colors.white : Colors.white70)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 35),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 5))],
                ),
                child: ElevatedButton(
                  onPressed: _startTest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("Teste Başla", style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeOverlay(Offset position) {
    if (position == Offset.zero && !_isProcessing) return const SizedBox.shrink();
    Color overlayColor = Colors.transparent;
    String actionText = "";
    IconData actionIcon = Icons.help;
    double opacity = 0.0;
    if (position.dy < -50 && position.dy.abs() > position.dx.abs()) {
      overlayColor = Colors.orangeAccent;
      actionText = "Öğrendim";
      actionIcon = Icons.school_rounded;
      opacity = min(1.0, position.dy.abs() / 150);
    } else if (position.dx > 40) {
      overlayColor = Colors.redAccent;
      actionText = "Unuttum";
      actionIcon = Icons.cancel_rounded;
      opacity = min(1.0, position.dx.abs() / 150);
    } else if (position.dx < -40) {
      overlayColor = Colors.greenAccent;
      actionText = "Hatırladım";
      actionIcon = Icons.check_circle_rounded;
      opacity = min(1.0, position.dx.abs() / 150);
    }

    if (opacity == 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        width: 320,
        height: 250,
        decoration: BoxDecoration(
          color: overlayColor.withOpacity(opacity * 0.8),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(opacity * 0.5), width: 2),
        ),
        child: Center(
          child: Transform.scale(
            scale: 0.5 + (opacity * 0.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.2), shape: BoxShape.circle),
                  child: Icon(actionIcon, color: Colors.white, size: 50),
                ),
                const SizedBox(height: 10),
                Text(
                  actionText,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: _totalWordsInSession == 0 ? 0 : (_totalWordsInSession - _words.length) / _totalWordsInSession,
                      minHeight: 8,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Kalan Kelime: ${_words.length} / $_totalWordsInSession",
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  const Text('👆 Öğrendim', style: TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('👈 Hatırladım', style: TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 15),
                      Text('(Dokun: Çevir)', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
                      const SizedBox(width: 15),
                      const Text('Unuttum 👉', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: Listenable.merge([_swipePosition, _swipeAngle, _isDragging]),
              builder: (context, child) {
                return GestureDetector(
                  onPanStart: (details) {
                    if (_isProcessing) return;
                    _isDragging.value = true;
                  },
                  onPanUpdate: (details) {
                    if (_isProcessing) return;
                    _swipePosition.value += details.delta;
                    _swipeAngle.value = 25 * (_swipePosition.value.dx / constraints.maxWidth);
                  },
                  onPanEnd: (details) {
                    if (_isProcessing) return;
                    _isDragging.value = false;
                    if (_swipePosition.value.dy < -80 && _swipePosition.value.dy.abs() > _swipePosition.value.dx.abs()) {
                      _animateAndMove('mastered', const Offset(0, -600));
                    } else if (_swipePosition.value.dx > 80) {
                      _animateAndMove('forgot', const Offset(500, 0));
                    } else if (_swipePosition.value.dx < -80) {
                      _animateAndMove('remembered', const Offset(-500, 0));
                    } else {
                      _swipePosition.value = Offset.zero;
                      _swipeAngle.value = 0.0;
                    }
                  },
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: _isDragging.value ? 0 : 300),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.identity()
                      ..translate(_swipePosition.value.dx, _swipePosition.value.dy)
                      ..rotateZ(_swipeAngle.value * 3.14159 / 180),
                    alignment: Alignment.center,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          key: ValueKey<String>(_words[0]['eng']),
                          child: FlipCard(
                            key: cardKey,
                            direction: FlipDirection.HORIZONTAL,
                            speed: 500,
                            front: _buildCard(_words[0]['eng'], true),
                            back: _buildCard(_words[0]['tr'], false),
                          ),
                        ),
                        _buildSwipeOverlay(_swipePosition.value),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildResultsScreen() {
    int correctAnswers = _masteredCount + _rememberedCount;
    double successRate = _totalWordsInSession > 0 ? (correctAnswers / _totalWordsInSession) * 100 : 0;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.workspace_premium_rounded, size: 80, color: Colors.orangeAccent),
            ),
            const SizedBox(height: 25),
            const Text(
              "Test Tamamlandı!",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              "İşte bu çalışmadaki performans analizin:",
              style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.6)),
            ),
            const SizedBox(height: 35),
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: primaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                children: [
                  const Text("BAŞARI ORANI", style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
                  const SizedBox(height: 10),
                  Text("%${successRate.toStringAsFixed(0)}", style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(child: _buildResultStatCard("Hatırlanan", correctAnswers.toString(), Icons.check_circle_rounded, Colors.greenAccent)),
                const SizedBox(width: 15),
                Expanded(child: _buildResultStatCard("Unutulan", _forgotCount.toString(), Icons.cancel_rounded, Colors.redAccent)),
              ],
            ),
            const SizedBox(height: 15),
            _buildResultStatCard("Arşive Eklenen (Öğrenildi)", _masteredCount.toString(), Icons.school_rounded, Colors.orangeAccent),
            const SizedBox(height: 40),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _testCompleted = false;
                        _isSetupMode = true;
                      });
                      _checkAvailableWords();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: BorderSide(color: Colors.white.withOpacity(0.2), width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text("Tekrar Test Et", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 5,
                    ),
                    child: const Text("Ana Sayfa", style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(title, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(Icons.style, size: 80, color: Colors.white54),
          ),
          const SizedBox(height: 25),
          const Text("Havuzda Kelime Yok!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 10),
          Text("Lütfen test edilecek yeni kelimeler ekle.", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildCard(String text, bool isFront) {
    double dynamicFontSize = text.length > 30 ? 22 : (text.length > 15 ? 28 : 38);
    return Container(
      width: 320,
      height: 250, // Biraz daha uzun yaparak daha şık bir hissiyat verdik
      decoration: BoxDecoration(
        gradient: isFront
            ? const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)], begin: Alignment.bottomLeft, end: Alignment.topRight),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isFront ? Colors.blueAccent.withOpacity(0.5) : Colors.purpleAccent.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 50),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: dynamicFontSize, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2, height: 1.3),
                ),
              ),
            ),
          ),
          if (isFront)
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.15), shape: BoxShape.circle),
                child: IconButton(icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 28), onPressed: () => _speak(text), tooltip: 'Dinle'),
              ),
            ),
          Positioned(
            bottom: 20,
            left: 25,
            child: Icon(isFront ? Icons.language : Icons.translate, color: Colors.white.withOpacity(0.3), size: 28),
          ),
        ],
      ),
    );
  }
}
