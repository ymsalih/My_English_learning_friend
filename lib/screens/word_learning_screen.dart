import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'tts_service.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class WordLearningScreen extends StatefulWidget {
  const WordLearningScreen({super.key});

  @override
  State<WordLearningScreen> createState() => _WordLearningScreenState();
}

class _WordLearningScreenState extends State<WordLearningScreen> {
  final TtsService _ttsService = TtsService();
  final SubscriptionService _subService = SubscriptionService();

  String _selectedLevel = 'A1';
  List<dynamic> _allWords = [];
  List<dynamic> _displayedWords = [];

  bool _isLoading = false;
  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  final ScrollController _scrollController = ScrollController();
  int _currentLimit = 20;
  bool _isFetchingMore = false;

  final LinearGradient darkPrimaryGradient = LinearGradient(
    colors: [AppColors.primary, AppColors.secondary], // Purple to Blue
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  void initState() {
    super.initState();
    _fetchWordsFromAPI();

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
          SnackBar(
            content: Text('Veri çekilirken bir hata oluştu.', style: TextStyle(color: AppColors.textPrimary)),
            backgroundColor: AppColors.dangerFill.withOpacity(0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
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
    if (!await _subService.canAddWord()) {
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallScreen()));
      }
      return;
    }

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
      await _subService.incrementWordCount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success),
                const SizedBox(width: 10),
                Expanded(child: Text('"$eng" başarıyla havuza eklendi!', style: TextStyle(color: AppColors.textPrimary))),
              ],
            ),
            backgroundColor: AppColors.surface.withOpacity(0.95), // Dark Theme SnackBar
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
              side: BorderSide(color: AppColors.success.withOpacity(0.5), width: 1.5),
            ),
            elevation: 10,
            duration: const Duration(milliseconds: 1500),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg, // Dark Space Background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Kelime Paketleri'
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground(child: SizedBox.expand())),

          SafeArea(
            child: Column(
              children: [
                // --- 1. SEVİYE SEÇİMİ ---
                Container(
                  height: 90,
                  padding: const EdgeInsets.symmetric(vertical: 20),
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
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          decoration: BoxDecoration(
                            gradient: isSelected ? darkPrimaryGradient : null,
                            color: isSelected ? null : AppColors.surface.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.white.withOpacity(0.1),
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryLight.withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
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
                                  : AppColors.textMuted,
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
                            color: AppColors.primaryLight,
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
                                color: AppColors.textPrimary.withOpacity(0.2),
                              ),
                              const SizedBox(height: 15),
                              Text(
                                'Bu seviyede kelime bulunamadı.',
                                style: TextStyle(
                                  color: AppColors.textMuted,
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
                                  padding: EdgeInsets.all(15.0),
                                  child: CircularProgressIndicator(
                                    color: AppColors.primaryLight,
                                    strokeWidth: 3,
                                  ),
                                ),
                              );
                            }

                            final word = _displayedWords[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withOpacity(0.6), // Dark Glass Panel
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: AppColors.surface,
                                  width: 1.5,
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.all(20.0),
                                  child: Row(
                                    children: [
                                      // Seviye Rozeti (Glowing)
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          gradient: darkPrimaryGradient,
                                          shape: BoxShape.circle,
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

                                      // Kelime Metinleri
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              word['eng'],
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                fontSize: 22,
                                                color: AppColors.textPrimary,
                                                letterSpacing: -0.5,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              word['tr'],
                                              style: TextStyle(
                                                color: Colors.purpleAccent.shade100,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Aksiyon Butonları (Neon)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildActionButton(
                                            icon: Icons.volume_up_rounded,
                                            iconColor: AppColors.secondary,
                                            bgColor: AppColors.secondary.withOpacity(0.15),
                                            borderColor: AppColors.secondary.withOpacity(0.3),
                                            onTap: () => _speak(word['eng']),
                                          ),
                                          const SizedBox(width: 12),
                                          _buildActionButton(
                                            icon: Icons.add_task_rounded,
                                            iconColor: AppColors.success,
                                            bgColor: AppColors.success.withOpacity(0.15),
                                            borderColor: AppColors.success.withOpacity(0.3),
                                            onTap: () => _addWordToMyPool(word['eng'], word['tr']),
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
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          splashColor: iconColor.withOpacity(0.3),
          child: Icon(icon, color: iconColor, size: 24),
        ),
      ),
    );
  }
}
