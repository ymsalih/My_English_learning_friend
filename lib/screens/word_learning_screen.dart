import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart'; // SES PAKETİ

class WordLearningScreen extends StatefulWidget {
  const WordLearningScreen({super.key});

  @override
  State<WordLearningScreen> createState() => _WordLearningScreenState();
}

class _WordLearningScreenState extends State<WordLearningScreen> {
  String _selectedLevel = 'A1';
  List<dynamic> _words = [];
  bool _isLoading = false;
  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];
  final FlutterTts _flutterTts = FlutterTts(); // TTS Nesnesi

  @override
  void initState() {
    super.initState();
    _fetchWordsFromAPI();
  }

  // Kelimeyi seslendiren fonksiyon
  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage(
      "en-US",
    ); // İstersen en-GB (İngiliz) yapabilirsin
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  Future<void> _fetchWordsFromAPI() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(
        'https://raw.githubusercontent.com/ymsalih/english-words-api/main/$_selectedLevel.json',
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _words = data['words'];
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Havuza ekleme fonksiyonu (Aynı kaldı)
  Future<void> _addWordToMyPool(String eng, String tr) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .add({
            'eng': eng,
            'tr': tr,
            'timestamp': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$eng" eklendi! 🎉'),
            backgroundColor: Colors.green,
            duration: const Duration(milliseconds: 500),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kelime Paketleri')),
      body: Column(
        children: [
          // Seviye Seçimi
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _levels.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(_levels[index]),
                    selected: _selectedLevel == _levels[index],
                    onSelected: (val) {
                      setState(() => _selectedLevel = _levels[index]);
                      _fetchWordsFromAPI();
                    },
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _words.length,
                    itemBuilder: (context, index) {
                      final word = _words[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: ListTile(
                          title: Text(
                            word['eng'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(word['tr']),
                          // İKİ BUTON: SES ve EKLE
                          trailing: Wrap(
                            spacing: 12,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.volume_up,
                                  color: Colors.blue,
                                ),
                                onPressed: () => _speak(word['eng']),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: Colors.orange,
                                ),
                                onPressed: () =>
                                    _addWordToMyPool(word['eng'], word['tr']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
