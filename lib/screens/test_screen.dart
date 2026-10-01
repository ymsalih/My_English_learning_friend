import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flip_card/flip_card.dart';
import 'tts_service.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

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
    colors: [AppColors.secondary, AppColors.primary],
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
        title: Text(_isSetupMode ? 'Kendini Test Et' : 'Öğrenme Zamanı'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: InfoPill(
              icon: Icons.quiz_outlined,
              label: _isUnlimited ? "Sınırsız" : "$_currentUsage/$_currentLimit",
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _allAvailableWords.isEmpty
                  ? _buildEmptyState()
                  : _isSetupMode
                      ? _buildSetupScreen()
                      : _testCompleted
                          ? _buildResultsScreen()
                          : _buildTestScreen(),
        ),
      ),
    );
  }

  Widget _countChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSetupScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: AppCard(
          radius: AppRadius.xl,
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const IconBadge(icon: Icons.tune_rounded, size: 64),
              const SizedBox(height: AppSpacing.lg),
              Text("Test Ayarları", style: AppText.heading(size: 22)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                "Havuzda öğrenilmeyi bekleyen toplam\n${_allAvailableWords.length} kelimen var.",
                textAlign: TextAlign.center,
                style: AppText.body,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text("$_selectedWordCount", style: AppText.display(size: 48)),
              const Text("KELİME", style: AppText.overline),
              const SizedBox(height: AppSpacing.md),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 6.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11.0),
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
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  ...[10, 20, 50].where((c) => c <= _allAvailableWords.length).map(
                        (count) => _countChip(
                          "$count",
                          _selectedWordCount == count,
                          () => setState(() => _selectedWordCount = count),
                        ),
                      ),
                  _countChip(
                    "Hepsi",
                    _selectedWordCount == _allAvailableWords.length,
                    () => setState(() => _selectedWordCount = _allAvailableWords.length),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startTest,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text("Teste Başla"),
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
      overlayColor = AppColors.goldFill;
      actionText = "Öğrendim";
      actionIcon = Icons.school_rounded;
      opacity = min(1.0, position.dy.abs() / 150);
    } else if (position.dx > 40) {
      overlayColor = AppColors.dangerFill;
      actionText = "Unuttum";
      actionIcon = Icons.close_rounded;
      opacity = min(1.0, position.dx.abs() / 150);
    } else if (position.dx < -40) {
      overlayColor = AppColors.successFill;
      actionText = "Hatırladım";
      actionIcon = Icons.check_rounded;
      opacity = min(1.0, position.dx.abs() / 150);
    }

    if (opacity == 0) return const SizedBox.shrink();
    return IgnorePointer(
      child: Container(
        width: 320,
        height: 250,
        decoration: BoxDecoration(
          color: overlayColor.withValues(alpha: opacity * 0.9),
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Center(
          child: Transform.scale(
            scale: 0.6 + (opacity * 0.4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(actionIcon, color: Colors.white, size: 56),
                const SizedBox(height: AppSpacing.sm),
                Text(actionText, style: AppText.display(size: 28, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: Column(
        children: [
          Material(
            color: color.withValues(alpha: 0.14),
            shape: CircleBorder(side: BorderSide(color: color.withValues(alpha: 0.4))),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 60, height: 60, child: Icon(icon, color: color, size: 28)),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTestScreen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final progress = _totalWordsInSession == 0
            ? 0.0
            : (_totalWordsInSession - _words.length) / _totalWordsInSession;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.md, AppSpacing.page, 0),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: progress, minHeight: 8),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    "${_totalWordsInSession - _words.length}/$_totalWordsInSession",
                    style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const Spacer(),
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
            const SizedBox(height: AppSpacing.lg),
            const Text(
              "Karta dokun: çevir  ·  Kaydır veya butonları kullan",
              style: AppText.caption,
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.page, 0, AppSpacing.page, AppSpacing.xxl),
              child: Row(
                children: [
                  _actionButton("Hatırladım", Icons.check_rounded, AppColors.success,
                      () => _animateAndMove('remembered', const Offset(-500, 0))),
                  _actionButton("Öğrendim", Icons.school_rounded, AppColors.gold,
                      () => _animateAndMove('mastered', const Offset(0, -600))),
                  _actionButton("Unuttum", Icons.close_rounded, AppColors.danger,
                      () => _animateAndMove('forgot', const Offset(500, 0))),
                ],
              ),
            ),
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
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: successRate / 100,
                    strokeWidth: 12,
                    strokeCap: StrokeCap.round,
                    valueColor: const AlwaysStoppedAnimation(AppColors.success),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("%${successRate.toStringAsFixed(0)}", style: AppText.display(size: 40)),
                        const Text("BAŞARI", style: AppText.overline),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text("Test Tamamlandı!", style: AppText.display(size: 26)),
            const SizedBox(height: AppSpacing.xs),
            const Text("İşte bu çalışmadaki performans analizin", style: AppText.body),
            const SizedBox(height: AppSpacing.xxl),
            Row(
              children: [
                Expanded(child: _buildResultStatCard("Hatırlanan", correctAnswers.toString(), Icons.check_rounded, AppColors.success)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _buildResultStatCard("Unutulan", _forgotCount.toString(), Icons.close_rounded, AppColors.danger)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _buildResultStatCard("Arşive Eklenen (Öğrenildi)", _masteredCount.toString(), Icons.school_rounded, AppColors.gold),
            const SizedBox(height: AppSpacing.section),
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
                    child: const Text("Tekrar Test Et"),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  // Alt sekmede açıldıysa kapatılacak sayfa yok: yeni teste dön.
                  child: FilledButton(
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        setState(() {
                          _isLoading = true;
                          _testCompleted = false;
                          _isSetupMode = true;
                        });
                        _checkAvailableWords();
                      }
                    },
                    child: Text(Navigator.canPop(context) ? "Ana Sayfa" : "Yeni Test"),
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
    return AppCard(
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, size: 40),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: AppText.heading(size: 20)),
                Text(title, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.section),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const IconBadge(icon: Icons.style_rounded, size: 88, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.xxl),
            Text("Havuzda Kelime Yok!", style: AppText.heading(size: 22)),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              "Lütfen test edilecek yeni kelimeler ekle.",
              textAlign: TextAlign.center,
              style: AppText.body,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String text, bool isFront) {
    double dynamicFontSize = text.length > 30 ? 22 : (text.length > 15 ? 28 : 36);
    return Container(
      width: 320,
      height: 250,
      decoration: BoxDecoration(
        gradient: isFront ? AppColors.primaryGradient : null,
        color: isFront ? null : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: isFront ? null : Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 18,
            left: 20,
            child: Text(
              isFront ? "İNGİLİZCE" : "TÜRKÇE",
              style: AppText.overline.copyWith(
                color: isFront ? Colors.white.withValues(alpha: 0.75) : AppColors.textMuted,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 50),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: AppText.display(size: dynamicFontSize, color: Colors.white),
                ),
              ),
            ),
          ),
          if (isFront)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 26),
                onPressed: () => _speak(text),
                tooltip: 'Dinle',
              ),
            ),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Icon(Icons.touch_app_rounded, color: Colors.white.withValues(alpha: 0.35), size: 22),
          ),
        ],
      ),
    );
  }
}
