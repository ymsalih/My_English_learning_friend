import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  List<Map<String, dynamic>> _words = [];
  bool _isLoading = true;
  final FlutterTts flutterTts = FlutterTts();

  // Kartı kodla döndürebilmek için gerekli anahtar
  GlobalKey<FlipCardState> cardKey = GlobalKey<FlipCardState>();
  bool _isProcessing =
      false; // Bekleme sırasında art arda tıklanmayı önlemek için

  // --- 📊 İSTATİSTİK TAKİP DEĞİŞKENLERİ ---
  int _totalWordsInSession = 0;
  int _forgotCount = 0;
  int _rememberedCount = 0;
  int _masteredCount = 0;
  bool _testCompleted = false; // Testin bittiğini anlamak için

  // 🔮 TEST EKRANI ÖZEL TEMASI
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Colors.deepPurpleAccent, Colors.purpleAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _fetchAndShuffleWords();
  }

  Future<void> _speak(String text) async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.55);
    await flutterTts.speak(text);
  }

  Future<void> _fetchAndShuffleWords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .get();

      final wordsList = snapshot.docs
          .map((doc) {
            final data = doc.data();
            data['docId'] = doc.id;
            return data;
          })
          .where((word) => word['isLearned'] != true)
          .toList();

      wordsList.shuffle(Random());

      setState(() {
        _words = wordsList;
        _totalWordsInSession = wordsList.length; // Toplam soru sayısını kaydet
        _forgotCount = 0;
        _rememberedCount = 0;
        _masteredCount = 0;
        _testCompleted = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleWordResult(String action) async {
    if (_words.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true; // İşlem başladı, diğer tıklamaları kilitle
    });

    final currentWord = _words[0];
    final String docId = currentWord['docId'];
    final user = FirebaseAuth.instance.currentUser;

    if (action == 'forgot') {
      _forgotCount++; // Unutulanları say
      // Eğer kartın ön yüzündeysek arkasını çevir
      if (cardKey.currentState != null && cardKey.currentState!.isFront) {
        cardKey.currentState!.toggleCard();
        // Kullanıcının cevabı okuması için 1.5 saniye bekle
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } else if (action == 'remembered') {
      _rememberedCount++; // Hatırlananları say
    } else if (action == 'mastered') {
      _masteredCount++; // Ustalaşılanları say
      if (user != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('words')
            .doc(docId)
            .update({'isLearned': true});
      }
    }

    // Arayüzü Güncelle ve Sonraki Karta Geç
    setState(() {
      _words.removeAt(0);

      // Animasyon çakışmasını önlemek için her yeni kelimede yeni bir anahtar üretiyoruz
      cardKey = GlobalKey<FlipCardState>();
      _isProcessing = false; // Kilidi aç

      // Eğer kelime kalmadıysa testi bitir
      if (_words.isEmpty) {
        _testCompleted = true;
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
            : _testCompleted // EĞER TEST BİTTİYSE SONUÇ EKRANINI GÖSTER
            ? _buildResultsScreen()
            : _words
                  .isEmpty // HİÇ KELİME YOKSA BOŞ EKRANI GÖSTER
            ? _buildEmptyState()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- 🏆 İLERLEME ÇUBUĞU (PROGRESS BAR) ---
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
                            backgroundColor: Colors.deepPurple.withOpacity(
                              0.15,
                            ),
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
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      ' Anlamını görmek için karta dokun',
                      style: TextStyle(
                        color: Colors.deepPurple,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder:
                        (Widget child, Animation<double> animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                    // Animasyonun karışmaması için ValueKey içeren bir Container ekledik
                    child: Container(
                      key: ValueKey<String>(_words[0]['eng']),
                      child: FlipCard(
                        key:
                            cardKey, // Kartı dışarıdan döndürebilmek için atadığımız anahtar
                        direction: FlipDirection.HORIZONTAL,
                        speed: 500,
                        front: _buildCard(_words[0]['eng'], true),
                        back: _buildCard(_words[0]['tr'], false),
                      ),
                    ),
                  ),

                  const SizedBox(height: 50),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // UNUTTUM BUTONU (Temaya uygun Pembe Tonları)
                        _buildActionButton(
                          title: "Unuttum",
                          icon: Icons.close_rounded,
                          colors: [
                            Colors.pinkAccent.shade400,
                            Colors.pink.shade300,
                          ],
                          onTap: () => _handleWordResult('forgot'),
                        ),
                        // HATIRLADIM BUTONU (Temaya uygun Mavi Tonları)
                        _buildActionButton(
                          title: "Hatırladım",
                          icon: Icons.check_rounded,
                          colors: [Colors.blueAccent, Colors.lightBlueAccent],
                          onTap: () => _handleWordResult('remembered'),
                        ),
                        // ÖĞRENDİM BUTONU (Ana temaya tam uyumlu Mor Tonları ve Şapka İkonu)
                        _buildActionButton(
                          title: "Öğrendim",
                          icon: Icons.school_rounded,
                          colors: [
                            Colors.deepPurpleAccent,
                            Colors.purpleAccent,
                          ],
                          onTap: () => _handleWordResult('mastered'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // --- 🏆 SINAV SONUÇ VE ANALİZ EKRANI ---
  Widget _buildResultsScreen() {
    // Senin formülün: Doğru bilinenler (Ustalaşılan + Hatırlanan) / Toplam * 100
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
              "İşte bugünkü performans analizin:",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            const SizedBox(height: 35),

            // Başarı Yüzdesi Kutusu
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

            // Detaylı İstatistikler (Yan Yana)
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

            // Aksiyon Butonları
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                "Ana Sayfaya Dön",
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

  // --- YARDIMCI WIDGET'LAR ---

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors[0].withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 35),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: colors[0],
              letterSpacing: 0.5,
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
                  onPressed: () => _speak(text),
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
