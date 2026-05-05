import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tts_service.dart'; // 🚀 Merkezi ses servisimizi çağırıyoruz

class WordLearningScreen extends StatefulWidget {
  const WordLearningScreen({super.key});

  @override
  State<WordLearningScreen> createState() => _WordLearningScreenState();
}

class _WordLearningScreenState extends State<WordLearningScreen> {
  // 🚀 Merkezi Servis
  final TtsService _ttsService = TtsService();

  String _selectedLevel = 'A1';
  List<dynamic> _allWords = [];
  List<dynamic> _displayedWords = [];

  bool _isLoading = false;
  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  // 🚀 PERFORMANS: Scroll dinleyici ve limitler
  final ScrollController _scrollController = ScrollController();
  int _currentLimit = 20;
  bool _isFetchingMore = false;

  // 🌅 ANA TEMA GRADYANI (Gün Batımı Turuncusu)
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.deepOrange.shade600, Colors.orange.shade400],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _fetchWordsFromAPI();

    // 🚀 SCROLL DİNLEYİCİSİ (Aşağı kaydırdıkça yükle)
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isFetchingMore) {
        _loadMoreWords();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 🚀 Merkezi motor ile konuşma
  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    await _ttsService.speak(text);
  }

  Future<void> _fetchWordsFromAPI() async {
    setState(() {
      _isLoading = true;
      _currentLimit = 20;
      _allWords = [];
      _displayedWords = [];
    });

    try {
      final url = Uri.parse(
        'https://raw.githubusercontent.com/ymsalih/english-words-api/main/$_selectedLevel.json',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _allWords = data['words'];
            _displayedWords = _allWords.take(_currentLimit).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veri çekilirken bir hata oluştu.')),
        );
      }
    }
  }

  void _loadMoreWords() {
    if (_currentLimit < _allWords.length) {
      setState(() {
        _isFetchingMore = true;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _currentLimit += 20;
            _displayedWords = _allWords.take(_currentLimit).toList();
            _isFetchingMore = false;
          });
        }
      });
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
            'isLearned': false,
            'lastReviewed': Timestamp.fromDate(
              DateTime.fromMillisecondsSinceEpoch(0),
            ),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('"$eng" başarıyla havuza eklendi!')),
              ],
            ),
            backgroundColor: Colors
                .green
                .shade600, // Eklendiğini belli eden güven veren yeşil
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF4F7FA,
      ), // Dashboard ile uyumlu çok açık gri/mavi
      appBar: AppBar(
        title: const Text(
          'Kelime Paketleri',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
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
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(vertical: 15),
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
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: BoxDecoration(
                      gradient: isSelected ? primaryGradient : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(
                        25,
                      ), // Daha yuvarlak hatlar
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.grey.shade300,
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.deepOrange.withOpacity(0.4),
                                blurRadius: 10,
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
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // --- 2. KELİME LİSTESİ ---
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: Colors.deepOrange.shade600,
                    ),
                  )
                : _allWords.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 80,
                          color: Colors.deepOrange.shade200,
                        ),
                        const SizedBox(height: 15),
                        Text(
                          'Bu seviyede kelime bulunamadı.',
                          style: TextStyle(
                            color: Colors.deepOrange.shade800,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(
                      top: 15,
                      bottom: 30,
                      left: 16,
                      right: 16,
                    ),
                    itemCount:
                        _displayedWords.length + (_isFetchingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _displayedWords.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: CircularProgressIndicator(
                              color: Colors.deepOrange.shade400,
                              strokeWidth: 3,
                            ),
                          ),
                        );
                      }

                      final word = _displayedWords[index];
                      return Container(
                        margin: const EdgeInsets.only(
                          bottom: 16,
                        ), // Kartlar arası mesafe artırıldı
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.grey.shade100,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.deepOrange.withOpacity(0.06),
                              blurRadius: 15,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.all(
                              20.0,
                            ), // İçerik boşluğu artırıldı
                            child: Row(
                              children: [
                                // 🌟 YENİ: Canlı ve Parlak Seviye Rozeti
                                Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.deepOrange.shade400,
                                        Colors.deepOrange.shade600,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.deepOrange.withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      _selectedLevel,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 18),

                                // 🌟 YENİ: Tipografik Hiyerarşi (Daha büyük ve kalın metinler)
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        word['eng'],
                                        style: const TextStyle(
                                          fontWeight:
                                              FontWeight.w900, // En kalın font
                                          fontSize:
                                              22, // Çok daha büyük İngilizce kelime
                                          color: Color(
                                            0xFF0F172A,
                                          ), // Koyu lacivert/siyah
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        word['tr'],
                                        style: TextStyle(
                                          color: Colors
                                              .deepOrange
                                              .shade700, // Tema rengiyle uyumlu, belirgin
                                          fontSize: 16,
                                          fontWeight: FontWeight
                                              .w700, // Türkçe anlamı da belirginleştirildi
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 🌟 YENİ: Belirgin ve Renkli Aksiyon Butonları
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildActionButton(
                                      icon: Icons.volume_up_rounded,
                                      iconColor: Colors.blue.shade700,
                                      bgColor: Colors.blue.shade50,
                                      onTap: () => _speak(word['eng']),
                                    ),
                                    const SizedBox(width: 10),
                                    _buildActionButton(
                                      icon: Icons.add_task_rounded,
                                      iconColor: Colors.teal.shade600,
                                      bgColor: Colors.teal.shade50,
                                      onTap: () => _addWordToMyPool(
                                        word['eng'],
                                        word['tr'],
                                      ),
                                    ),
                                  ],
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

  // Butonları daha şık çizen yardımcı metot
  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          splashColor: iconColor.withOpacity(0.2),
          child: Icon(icon, color: iconColor, size: 26),
        ),
      ),
    );
  }
}
