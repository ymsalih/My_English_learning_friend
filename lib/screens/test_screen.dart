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

  // 🔮 TEST EKRANI ÖZEL TEMASI (Mor Geçiş)
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
    await flutterTts.setLanguage("en-GB");
    await flutterTts.setSpeechRate(0.5);
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

      final wordsList = snapshot.docs.map((doc) => doc.data()).toList();
      wordsList.shuffle(Random());

      setState(() {
        _words = wordsList;
        _isLoading = false;
      });
    }
  }

  void _nextWord() {
    setState(() {
      if (_words.isNotEmpty) {
        // Eski manuel çevirme kodunu sildik, sadece kelimeyi listeden atıyoruz.
        // AnimatedSwitcher yeni anahtar (ValueKey) gördüğü an yepyeni bir kart yaratıp önüne dönecek!
        _words.removeAt(0);
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
            : _words.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          primaryGradient.createShader(bounds),
                      child: const Icon(
                        Icons.style,
                        size: 100,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Test bitti veya kelime yok!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Lütfen havuza yeni kelimeler ekle.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                      child: FlipCard(
                        // Sadece bu ValueKey kalıyor, hatalı cardKey kısmını uçurduk!
                        key: ValueKey<String>(_words[0]['eng']),
                        direction: FlipDirection.HORIZONTAL,
                        speed: 500,
                        front: _buildCard(_words[0]['eng'], true),
                        back: _buildCard(_words[0]['tr'], false),
                      ),
                    ),
                    const SizedBox(height: 40),

                    Container(
                      decoration: BoxDecoration(
                        gradient: primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurpleAccent.withOpacity(0.4),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _nextWord,
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        label: const Text(
                          'Sıradaki Kelime',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 35,
                            vertical: 15,
                          ),
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
                  tooltip: 'İngiliz Aksanıyla Dinle',
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
