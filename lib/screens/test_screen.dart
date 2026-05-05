import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
// 🚀 YENİ: Yerel flutter_tts silindi, Merkezi Ses Servisi içeri aktarıldı
import 'tts_service.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  // 🚀 GÜNCELLEME: Merkezi ses servisimizi tanımlıyoruz
  final TtsService _ttsService = TtsService();

  List<Map<String, dynamic>> _allAvailableWords = [];
  List<Map<String, dynamic>> _words = [];

  bool _isLoading = true;
  bool _isSetupMode = true;
  int _selectedWordCount = 10;

  GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();
  bool _isProcessing = false;

  // 🚀 PERFORMANS OPTİMİZASYONU 2: ValueNotifier kullanımı.
  // Artık sürükleme sırasında tüm ekran yenilenmeyecek, sadece bu değerleri dinleyen kart yenilenecek!
  final ValueNotifier<Offset> _swipePosition = ValueNotifier<Offset>(
    Offset.zero,
  );
  final ValueNotifier<double> _swipeAngle = ValueNotifier<double>(0.0);
  final ValueNotifier<bool> _isDragging = ValueNotifier<bool>(false);

  // --- 📊 İSTATİSTİK TAKİP DEĞİŞKENLERİ ---
  int _totalWordsInSession = 0;
  int _forgotCount = 0;
  int _rememberedCount = 0;
  int _masteredCount = 0;
  bool _testCompleted = false;

  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Colors.deepPurpleAccent, Colors.purpleAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _checkAvailableWords();
  }

  @override
  void dispose() {
    // 🚀 Bellek sızıntılarını (Memory Leak) önlemek için Notifier'ları kapatıyoruz
    _swipePosition.dispose();
    _swipeAngle.dispose();
    _isDragging.dispose();
    super.dispose();
  }

  // 🚀 GÜNCELLEME: Artık yerel ayar yapmak yerine merkezi servisi kullanarak konuşuyoruz
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

  void _startTest() {
    _allAvailableWords.sort((a, b) {
      Timestamp? t1 = a['lastReviewed'] as Timestamp?;
      Timestamp? t2 = b['lastReviewed'] as Timestamp?;

      int time1 = t1?.millisecondsSinceEpoch ?? 0;
      int time2 = t2?.millisecondsSinceEpoch ?? 0;

      return time1.compareTo(time2);
    });

    List<Map<String, dynamic>> selectedSessionWords = _allAvailableWords
        .take(_selectedWordCount)
        .toList();

    selectedSessionWords.shuffle(Random());

    setState(() {
      _words = selectedSessionWords;
      _totalWordsInSession = selectedSessionWords.length;
      _forgotCount = 0;
      _rememberedCount = 0;
      _masteredCount = 0;
      _testCompleted = false;
      _isSetupMode = false;
    });
  }

  Future<void> _saveTestResultsToFirebase(
    int correctCount,
    int wrongCount,
    int masteredCount,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      await userRef.set({
        'stats': {
          'totalTests': FieldValue.increment(1),
          'totalCorrect': FieldValue.increment(correctCount),
          'totalWrong': FieldValue.increment(wrongCount),
          'totalMastered': FieldValue.increment(masteredCount),
        },
      }, SetOptions(merge: true));

      int totalQuestions = correctCount + wrongCount;
      double successRate = totalQuestions > 0
          ? (correctCount / totalQuestions) * 100
          : 0;

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

  // 🚀 GÜNCELLENDİ: SetState Yerine ValueNotifier kullanılarak animasyon izole edildi
  Future<void> _animateAndMove(String action, Offset targetPosition) async {
    if (_isProcessing) return;
    _isProcessing = true;

    // Sadece dinleyicileri (Notifier) güncelliyoruz, tüm ekranı yeniden ÇİZDİRMİYORUZ.
    _swipePosition.value = targetPosition;
    _swipeAngle.value = targetPosition.dx > 0
        ? 30
        : (targetPosition.dx < 0 ? -30 : 0);

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

    if (user != null) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .doc(docId)
          .update(updateData);
    }

    // Kelime listesi eksildiği için burada ekranın (üstteki ilerleme çubuğunun) yenilenmesi gerek.
    setState(() {
      _words.removeAt(0);
      cardKey = GlobalKey<FlipCardState>();

      if (_words.isEmpty) {
        _testCompleted = true;
        int correctAnswers = _masteredCount + _rememberedCount;
        _saveTestResultsToFirebase(
          correctAnswers,
          _forgotCount,
          _masteredCount,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Kendini Test Et',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: primaryGradient),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.deepPurpleAccent,
                ),
              )
            : _allAvailableWords.isEmpty
            ? _buildEmptyState()
            : _isSetupMode
            ? _buildSetupScreen()
            : _testCompleted
            ? _buildResultsScreen()
            : _buildTestScreen(),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.settings_suggest_rounded,
                size: 80,
                color: Colors.deepPurpleAccent,
              ),
              const SizedBox(height: 15),
              const Text(
                "Test Ayarları",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Havuzda öğrenilmeyi bekleyen toplam\n${_allAvailableWords.length} kelimen var.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 30),

              Text(
                "$_selectedWordCount Kelime",
                style: const TextStyle(
                  fontSize: 35,
                  fontWeight: FontWeight.w900,
                  color: Colors.deepPurpleAccent,
                ),
              ),
              const SizedBox(height: 10),

              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: Colors.deepPurpleAccent,
                  inactiveTrackColor: Colors.deepPurple.withOpacity(0.2),
                  thumbColor: Colors.purpleAccent,
                  overlayColor: Colors.purpleAccent.withOpacity(0.2),
                  trackHeight: 8.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12.0,
                  ),
                ),
                child: Slider(
                  value: _selectedWordCount.toDouble(),
                  min: 1,
                  max: _allAvailableWords.length.toDouble(),
                  divisions: _allAvailableWords.length > 1
                      ? _allAvailableWords.length - 1
                      : 1,
                  onChanged: (double value) {
                    setState(() {
                      _selectedWordCount = value.toInt();
                    });
                  },
                ),
              ),
              const SizedBox(height: 15),

              Wrap(
                spacing: 10,
                alignment: WrapAlignment.center,
                children:
                    [10, 20, 50].map((count) {
                      if (count > _allAvailableWords.length)
                        return const SizedBox.shrink();
                      return ActionChip(
                        label: Text("$count"),
                        labelStyle: TextStyle(
                          color: _selectedWordCount == count
                              ? Colors.white
                              : Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                        backgroundColor: _selectedWordCount == count
                            ? Colors.deepPurpleAccent
                            : Colors.deepPurple.shade50,
                        onPressed: () {
                          setState(() {
                            _selectedWordCount = count;
                          });
                        },
                      );
                    }).toList()..add(
                      ActionChip(
                        label: const Text("Hepsi"),
                        labelStyle: TextStyle(
                          color: _selectedWordCount == _allAvailableWords.length
                              ? Colors.white
                              : Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                        backgroundColor:
                            _selectedWordCount == _allAvailableWords.length
                            ? Colors.deepPurpleAccent
                            : Colors.deepPurple.shade50,
                        onPressed: () {
                          setState(() {
                            _selectedWordCount = _allAvailableWords.length;
                          });
                        },
                      ),
                    ),
              ),

              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _startTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 5,
                ),
                child: const Text(
                  "Teste Başla",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 GÜNCELLENDİ: Artık dışarıdan Offset alarak sadece bu widget'ın yenilenmesini sağlıyor
  Widget _buildSwipeOverlay(Offset position) {
    if (position == Offset.zero && !_isProcessing)
      return const SizedBox.shrink();

    Color overlayColor = Colors.transparent;
    String actionText = "";
    IconData actionIcon = Icons.help;
    double opacity = 0.0;

    if (position.dy < -50 && position.dy.abs() > position.dx.abs()) {
      overlayColor = Colors.deepPurpleAccent;
      actionText = "Öğrendim";
      actionIcon = Icons.school_rounded;
      opacity = min(1.0, position.dy.abs() / 150);
    } else if (position.dx > 40) {
      overlayColor = Colors.pinkAccent.shade400;
      actionText = "Unuttum";
      actionIcon = Icons.cancel_rounded;
      opacity = min(1.0, position.dx.abs() / 150);
    } else if (position.dx < -40) {
      overlayColor = Colors.blueAccent;
      actionText = "Hatırladım";
      actionIcon = Icons.check_circle_rounded;
      opacity = min(1.0, position.dx.abs() / 150);
    }

    if (opacity == 0) return const SizedBox.shrink();

    return IgnorePointer(
      child: Container(
        width: 320,
        height: 220,
        decoration: BoxDecoration(
          color: overlayColor.withOpacity(opacity * 0.85),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Transform.scale(
            scale: 0.5 + (opacity * 0.5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(actionIcon, color: Colors.white, size: 80),
                const SizedBox(height: 10),
                Text(
                  actionText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
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
                      value: _totalWordsInSession == 0
                          ? 0
                          : (_totalWordsInSession - _words.length) /
                                _totalWordsInSession,
                      minHeight: 8,
                      backgroundColor: Colors.deepPurple.withOpacity(0.15),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Colors.deepPurpleAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Kalan Kelime: ${_words.length} / $_totalWordsInSession",
                    style: const TextStyle(
                      color: Colors.deepPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '👆 Öğrendim\n👈 Hatırladım  |  (Dokun: Çevir)  |  Unuttum 👉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 50),

            // 🚀 PERFORMANS OPTİMİZASYONU 2: AnimatedBuilder kullanımı.
            // Sadece bu blok (kaydırma animasyonu) dinlenir, ekranın kalanı rahat bırakılır.
            AnimatedBuilder(
              animation: Listenable.merge([
                _swipePosition,
                _swipeAngle,
                _isDragging,
              ]),
              builder: (context, child) {
                return GestureDetector(
                  onPanStart: (details) {
                    if (_isProcessing) return;
                    _isDragging.value = true;
                  },
                  onPanUpdate: (details) {
                    if (_isProcessing) return;
                    _swipePosition.value += details.delta;
                    _swipeAngle.value =
                        25 * (_swipePosition.value.dx / constraints.maxWidth);
                  },
                  onPanEnd: (details) {
                    if (_isProcessing) return;
                    _isDragging.value = false;

                    if (_swipePosition.value.dy < -80 &&
                        _swipePosition.value.dy.abs() >
                            _swipePosition.value.dx.abs()) {
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
                    duration: Duration(
                      milliseconds: _isDragging.value ? 0 : 300,
                    ),
                    curve: Curves.easeOutCubic,
                    transform: Matrix4.identity()
                      ..translate(
                        _swipePosition.value.dx,
                        _swipePosition.value.dy,
                      )
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
                        // Overlay de artık sadece position değiştiğinde tetikleniyor
                        _buildSwipeOverlay(_swipePosition.value),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 100),
          ],
        );
      },
    );
  }

  Widget _buildResultsScreen() {
    int correctAnswers = _masteredCount + _rememberedCount;
    double successRate = _totalWordsInSession > 0
        ? (correctAnswers / _totalWordsInSession) * 100
        : 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.workspace_premium_rounded,
              size: 80,
              color: Colors.orangeAccent,
            ),
            const SizedBox(height: 15),
            const Text(
              "Test Tamamlandı!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.deepPurple,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              "İşte bu çalışmadaki performans analizin:",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 35),

            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: primaryGradient,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.deepPurple.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    "BAŞARI ORANI",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "%${successRate.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 60,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: _buildResultStatCard(
                    "Hatırlanan",
                    correctAnswers.toString(),
                    Icons.check_circle_rounded,
                    Colors.teal,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: _buildResultStatCard(
                    "Unutulan",
                    _forgotCount.toString(),
                    Icons.cancel_rounded,
                    Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            _buildResultStatCard(
              "Arşive Eklenen (Öğrenilen)",
              _masteredCount.toString(),
              Icons.school_rounded,
              Colors.orange,
            ),

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
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(
                        color: Colors.deepPurple,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Tekrar Test Et",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.deepPurple,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Ana Sayfa",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          ShaderMask(
            shaderCallback: (bounds) => primaryGradient.createShader(bounds),
            child: const Icon(Icons.style, size: 100, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Havuzda Kelime Yok!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Lütfen test edilecek yeni kelimeler ekle.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(String text, bool isFront) {
    return Container(
      width: 320,
      height: 220,
      decoration: BoxDecoration(
        gradient: isFront
            ? primaryGradient
            : const LinearGradient(
                colors: [Colors.pinkAccent, Color.fromARGB(255, 164, 138, 105)],
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
              ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: isFront
                ? Colors.deepPurpleAccent.withOpacity(0.4)
                : Colors.pinkAccent.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.center,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
          if (isFront)
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: () =>
                      _speak(text), // 🚀 Artık merkezi motor tetikleniyor!
                  tooltip: 'Dinle',
                ),
              ),
            ),
          Positioned(
            bottom: 15,
            left: 20,
            child: Icon(
              isFront ? Icons.language : Icons.translate,
              color: Colors.white.withOpacity(0.4),
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}
