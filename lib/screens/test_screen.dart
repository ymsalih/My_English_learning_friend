import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  List<Map<String, dynamic>> _words = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAndShuffleWords();
  }

  // Veritabanından kelimeleri çekip rastgele karıştırıyoruz
  Future<void> _fetchAndShuffleWords() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .get();

      final wordsList = snapshot.docs.map((doc) => doc.data()).toList();
      wordsList.shuffle(Random()); // Kelimeleri rastgele dizer

      setState(() {
        _words = wordsList;
        _isLoading = false;
      });
    }
  }

  // Sıradaki kelimeye geçme mantığı
  void _nextWord() {
    setState(() {
      if (_words.isNotEmpty) {
        // Çıkan kelimeyi anlık listeden siliyoruz ki aynı oturumda tekrar gelmesin
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
                  // Kartı arkalı önlü çevirmemizi sağlayan widget
                  FlipCard(
                    direction: FlipDirection.HORIZONTAL,
                    front: _buildCard(
                      _words[0]['eng'],
                      Colors.deepPurpleAccent,
                    ), // Ön yüz İngilizce
                    back: _buildCard(
                      _words[0]['tr'],
                      Colors.teal,
                    ), // Arka yüz Türkçe
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

  // Kartın görsel tasarımını yapan yardımcı fonksiyon
  Widget _buildCard(String text, Color color) {
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
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
