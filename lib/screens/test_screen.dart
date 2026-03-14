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

  @override
  void initState() {
    super.initState();
    _fetchAndShuffleWords();
  }

  // DEĞİŞEN KISIM BURASI: Aksan İngiliz (en-GB) olarak güncellendi
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
        _words.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kendimi Test Et')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _words.isEmpty
          ? const Center(
              child: Text(
                'Test bitti veya hiç kelime yok!\nLütfen havuza kelime ekle.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Çevirmek için karta dokun',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  FlipCard(
                    direction: FlipDirection.HORIZONTAL,
                    // Ön yüz (İngilizce - Ses var)
                    front: _buildCard(
                      _words[0]['eng'],
                      Colors.deepPurpleAccent,
                      showSpeak: true,
                    ),
                    // Arka yüz (Türkçe - Ses yok)
                    back: _buildCard(_words[0]['tr'], Colors.teal),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: _nextWord,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Sıradaki Kelime'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                      textStyle: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // Kart tasarımı ve ikon hizalaması
  Widget _buildCard(String text, Color color, {bool showSpeak = false}) {
    return Container(
      width: 320,
      height: 220,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      // Stack'i direkt Container'ın içine aldık ki kartın tamamını kaplasın
      child: Stack(
        children: [
          // Kelimeyi kartın tam ortasına hizalıyoruz
          Align(
            alignment: Alignment.center,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          // Ses ikonunu sağ üst köşeye sabitliyoruz
          if (showSpeak)
            Positioned(
              top: 15,
              right: 15,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white24, // Şeffaf beyaz arka plan
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.volume_up,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () => _speak(text),
                  tooltip: 'Dinle',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
