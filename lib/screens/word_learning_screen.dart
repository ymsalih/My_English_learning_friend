import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';

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
  final FlutterTts _flutterTts = FlutterTts();

  // 🌅 DAHA ZENGİN VE KALİTELİ GÜN BATIMI (SUNSET) TURUNCUSU
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.deepOrange.shade600, Colors.orange.shade400],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _fetchWordsFromAPI();
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
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
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
            content: Text(
              '✨ "$eng" başarıyla havuza eklendi!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.deepOrange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            duration: const Duration(milliseconds: 1000),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Arka planı tamamen çok açık ve temiz bir gri/beyaz tonu yaptık ki kartlar öne çıksın
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Kelime Paketleri',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: primaryGradient),
        ),
      ),
      body: Column(
        children: [
          // --- 1. SEVİYE SEÇİMİ ---
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(vertical: 15),
            color: Colors.white, // Menü arka planı temiz beyaz
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _levels.length,
              itemBuilder: (context, index) {
                final level = _levels[index];
                final isSelected = _selectedLevel == level;

                return GestureDetector(
                  onTap: () {
                    if (!isSelected) {
                      setState(() => _selectedLevel = level);
                      _fetchWordsFromAPI();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    decoration: BoxDecoration(
                      gradient: isSelected ? primaryGradient : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Colors
                                  .grey
                                  .shade300, // Seçili olmayanlar gri çerçeve
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.deepOrange.withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      level,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? Colors.white
                            : Colors.grey.shade600, // Seçilmeyen yazılar gri
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Çok hafif bir gölge çizgisi
          Container(height: 1, color: Colors.grey.shade200),

          // --- 2. KELİME LİSTESİ ---
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepOrange.shade600,
                    ),
                  )
                : _words.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 80,
                          color: Colors.deepOrange.shade300,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Bu seviyede kelime bulunamadı.',
                          style: TextStyle(
                            color: Colors.deepOrange.shade800,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(
                      top: 15,
                      bottom: 20,
                      left: 15,
                      right: 15,
                    ),
                    itemCount: _words.length,
                    itemBuilder: (context, index) {
                      final word = _words[index];
                      return Card(
                        elevation: 3,
                        color: Colors
                            .white, // KART ARKA PLANI SAF BEYAZ (Renk bozulmasını önler)
                        surfaceTintColor: Colors
                            .white, // Material 3'ün kartlara renk vermesini engeller
                        shadowColor: Colors.deepOrange.withOpacity(0.15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            leading: CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.deepOrange.shade50,
                              child: Text(
                                _selectedLevel,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.deepOrange.shade700,
                                ),
                              ),
                            ),
                            // 🌟 KELİMELER ŞİMDİ DAHA BÜYÜK VE KALIN
                            title: Text(
                              word['eng'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w900, // Çok daha kalın
                                fontSize: 20, // Daha büyük
                                letterSpacing: 0.5,
                                color: Colors.black87,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                word['tr'],
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                // Dinleme Butonu
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.volume_up_rounded,
                                      color: Colors.blue.shade700,
                                      size: 26,
                                    ),
                                    onPressed: () => _speak(word['eng']),
                                    tooltip: 'Dinle',
                                  ),
                                ),
                                // Havuza Ekleme Butonu
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.add_task_rounded,
                                      color: Colors.deepOrange.shade600,
                                      size: 26,
                                    ),
                                    onPressed: () => _addWordToMyPool(
                                      word['eng'],
                                      word['tr'],
                                    ),
                                    tooltip: 'Havuza Ekle',
                                  ),
                                ),
                              ],
                            ),
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
