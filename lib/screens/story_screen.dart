import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/gemini_story_service.dart';
import 'tts_service.dart';
import 'package:translator/translator.dart';
import '../services/subscription_service.dart';
import 'paywall_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class StoryScreen extends StatefulWidget {
  const StoryScreen({super.key});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  final GeminiStoryService _storyService = GeminiStoryService();
  final TtsService _ttsService = TtsService();
  final _translator = GoogleTranslator();
  final SubscriptionService _subService = SubscriptionService();

  String _selectedGenre = 'Macera';
  String _selectedLevel = 'A2';

  final List<String> _genres = [
    'Macera',
    'Gizem',
    'Bilim Kurgu',
    'Günlük Yaşam',
    'Fantastik',
  ];
  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  bool _isLoading = false;
  Map<String, dynamic>? _storyTree;
  Map<String, dynamic>? _currentNode;

  bool _showQuiz = false;
  int _currentQuestionIndex = 0;
  int _score = 0;
  bool _quizCompleted = false;

  int? _selectedAnswerIndex;
  String? _translatedExplanation;
  bool _isTranslatingExplanation = false;

  int _currentGenUsage = 0;
  int _currentGenLimit = 2;
  bool _isGenUnlimited = false;

  int _currentReadUsage = 0;
  int _currentReadLimit = 2;
  bool _isReadUnlimited = false;

  @override
  void initState() {
    super.initState();
    _loadUserLevel();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final genUsage = await _subService.getActionUsage('storyGenCount');
    final readUsage = await _subService.getActionUsage('storyReadCount');

    if (mounted) {
      setState(() {
        _currentGenUsage = genUsage['current'] ?? 0;
        _currentGenLimit = genUsage['limit'] ?? 2;
        _isGenUnlimited = _currentGenLimit >= 999999;

        _currentReadUsage = readUsage['current'] ?? 0;
        _currentReadLimit = readUsage['limit'] ?? 2;
        _isReadUnlimited = _currentReadLimit >= 999999;
      });
    }
  }

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _loadUserLevel() async {
    // Kullanıcı belgesi SubscriptionService önbelleğinden gelir (ek okuma yok).
    final data = await _subService.getUserData();
    if (data['level'] != null && mounted) {
      setState(() {
        _selectedLevel = data['level'];
      });
    }
  }

  Future<void> _startStory(bool forceGenerate) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Sadece kontrol ediyoruz, henüz kotayı düşmüyoruz
    if (forceGenerate) {
      if (!await _subService.canGenerateStory()) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PaywallScreen()),
          );
        }
        return;
      }
    } else {
      if (!await _subService.canReadStory()) {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PaywallScreen()),
          );
        }
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _storyTree = null;
      _currentNode = null;
      _showQuiz = false;
      _quizCompleted = false;
      _currentQuestionIndex = 0;
      _score = 0;
      _selectedAnswerIndex = null;
      _translatedExplanation = null;
      _isTranslatingExplanation = false;
    });

    try {
      final tree = await _storyService.fetchOrGenerateStoryTree(
        _selectedGenre,
        _selectedLevel,
        forceGenerate: forceGenerate,
      );

      // Hikaye başarıyla üretildi veya okundu, ŞİMDİ kotayı düşürüyoruz!
      if (forceGenerate) {
        await _subService.incrementStoryGen();
      } else {
        await _subService.incrementStoryRead();
      }
      await _loadLimits();
      if (mounted) {
        setState(() {
          _storyTree = tree;
          _currentNode = _findNodeById('1');
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMsg =
            'Beklenmeyen bir hata oluştu. Lütfen birazdan tekrar deneyin.';
        final errorString = e.toString().toLowerCase();

        if (errorString.contains('socket') ||
            errorString.contains('host lookup') ||
            errorString.contains('network') ||
            errorString.contains('clientexception')) {
          errorMsg =
              'İnternet bağlantınız koptu veya çok yavaş. Lütfen kontrol edip tekrar deneyin.';
        } else if (errorString.contains('503') ||
            errorString.contains('timeout') ||
            errorString.contains('busy') ||
            errorString.contains('quota')) {
          errorMsg =
              'Yapay zeka sunucuları şu an çok yoğun. Lütfen birkaç dakika sonra tekrar deneyin.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    errorMsg,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(15),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic>? _findNodeById(String id) {
    if (_storyTree == null) return null;
    final nodes = _storyTree!['nodes'] as List<dynamic>;
    return nodes.firstWhere((n) => n['id'] == id, orElse: () => null);
  }

  void _makeChoice(String nextId) {
    setState(() {
      _currentNode = _findNodeById(nextId);
    });
  }

  Future<String> _fallbackTranslate(String text) async {
    try {
      final translator = GoogleTranslator();
      final res = await translator.translate(text, from: 'en', to: 'tr');
      return res.text;
    } catch (e) {
      return "Hata oluştu";
    }
  }

  Future<void> _showWordTranslation(String word) async {
    final cleanWord = word.trim();
    if (cleanWord.isEmpty) return;

    // Sadece tek kelime mi diye kontrol et
    final isSingleWord = !cleanWord.contains(' ');
    // Eğer tek kelimeyse gereksiz noktalama işaretlerini sil (örn: "hello," -> "hello")
    final queryText = isSingleWord
        ? cleanWord.replaceAll(RegExp(r'[^\w\s]'), '').toLowerCase()
        : cleanWord;

    String translated = "Çevriliyor...";
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            if (translated == "Çevriliyor...") {
              if (isSingleWord) {
                FirebaseFirestore.instance
                    .collection('dictionary_cache')
                    .doc("en_$queryText")
                    .get()
                    .then((doc) async {
                      if (doc.exists) {
                        setModalState(
                          () => translated =
                              doc.data()!['mainTranslation'] ?? 'Bulunamadı',
                        );
                      } else {
                        final res = await _fallbackTranslate(queryText);
                        setModalState(() => translated = res);
                      }
                    });
              } else {
                _fallbackTranslate(queryText).then((res) {
                  setModalState(() => translated = res);
                });
              }
            }

            return Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.95),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      cleanWord.length > 30 ? "Metin Çevirisi" : cleanWord,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Text(
                          translated,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              );
          },
        );
      },
    );
  }

  Widget _buildTappableText(String text) {
    final words = text.split(' ');
    return Wrap(
      spacing: 5,
      runSpacing: 2,
      children: words.map((word) {
        return GestureDetector(
          onTap: () => _showWordTranslation(word),
          child: Text(
            word,
            style: const TextStyle(fontSize: 18, height: 1.65, color: AppColors.textPrimary),
          ),
        );
      }).toList(),
    );
  }

  /// Ağaç derinliği: 1 → 2-3 → 4-7.
  int _chapterOf(Map<String, dynamic> node) {
    final id = int.tryParse('${node['id']}') ?? 1;
    return id <= 1 ? 1 : (id <= 3 ? 2 : 3);
  }

  Widget _buildStoryContent() {
    if (_currentNode == null) return const SizedBox.shrink();

    final text = _currentNode!['text'] ?? '';
    final choices = _currentNode!['choices'] as List<dynamic>? ?? [];
    final isEnding = _currentNode!['is_ending'] ?? false;
    final chapter = _chapterOf(_currentNode!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.section),
      children: [
        Row(
          children: [
            for (var i = 1; i <= 3; i++) ...[
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i <= chapter ? AppColors.primaryLight : AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < 3) const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text("BÖLÜM $chapter / 3", style: AppText.overline),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          radius: AppRadius.xl,
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text("Bilmediğin kelimeye dokun", style: AppText.caption),
                  ),
                  IconButton(
                    icon: const Icon(Icons.translate_rounded, color: AppColors.secondary),
                    tooltip: 'Tümünü Çevir',
                    onPressed: () => _showWordTranslation(text),
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryLight),
                    tooltip: 'Seslendir (İngilizce)',
                    onPressed: () => _ttsService.speak(text),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: _buildTappableText(text),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        if (!isEnding) ...[
          Text('Ne yapmak istersin?', style: AppText.heading(size: 18)),
          const SizedBox(height: AppSpacing.xs),
          const Text('Çevirisi için seçeneğe uzun bas', style: AppText.caption),
          const SizedBox(height: AppSpacing.md),
          ...choices.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => _makeChoice(entry.value['next_id']),
                      onLongPress: () => _showWordTranslation(entry.value['text']),
                      child: Ink(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          children: [
                            _letterBadge(String.fromCharCode(65 + entry.key)),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Text(
                                entry.value['text'],
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted, size: 20),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ] else ...[
          AppCard(
            radius: AppRadius.xl,
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              children: [
                const IconBadge(icon: Icons.flag_rounded, color: AppColors.gold, size: 56),
                const SizedBox(height: AppSpacing.md),
                Text('Hikaye Sonu 🎉', style: AppText.heading(size: 22)),
                const SizedBox(height: AppSpacing.xs),
                const Text(
                  'Şimdi ne kadar anladığını test et.',
                  textAlign: TextAlign.center,
                  style: AppText.body,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _showQuiz = true),
                    icon: const Icon(Icons.quiz_rounded),
                    label: const Text('Okuma Anlama Testini Çöz'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _letterBadge(String letter, {Color color = AppColors.primaryLight, Color? fill}) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill ?? color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(letter, style: TextStyle(color: fill != null ? Colors.white : color, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildQuiz() {
    final questions = _storyTree!['questions'] as List<dynamic>? ?? [];
    if (questions.isEmpty) {
      return const Center(child: Text("Test bulunamadı.", style: AppText.body));
    }

    if (_quizCompleted) {
      final ratio = _score / questions.length;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            children: [
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 12,
                      strokeCap: StrokeCap.round,
                      valueColor: const AlwaysStoppedAnimation(AppColors.success),
                    ),
                    Center(child: Text('$_score/${questions.length}', style: AppText.display(size: 34))),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Tebrikler!', style: AppText.display(size: 28)),
              const SizedBox(height: AppSpacing.xs),
              const Text('Hikayeyi ve testi tamamladın.', style: AppText.body),
              const SizedBox(height: AppSpacing.section),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => setState(() => _storyTree = null),
                  child: const Text('Yeni Hikaye Seç'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentQ = questions[_currentQuestionIndex];
    final options = currentQ['options'] as List<dynamic>;

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.section),
      children: [
        Row(
          children: [
            Text('SORU ${_currentQuestionIndex + 1} / ${questions.length}', style: AppText.overline),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_currentQuestionIndex + 1) / questions.length,
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(currentQ['question'], style: AppText.heading(size: 21)),
        const SizedBox(height: AppSpacing.xxl),
        ...options.asMap().entries.map((entry) {
          final bool isSelected = _selectedAnswerIndex == entry.key;
          final bool isCorrect = entry.key == currentQ['correctIndex'];
          final bool showColors = _selectedAnswerIndex != null;

          Color borderColor = AppColors.border;
          Color bgColor = AppColors.surface;
          Color badgeColor = AppColors.primaryLight;
          Color? badgeFill;

          if (showColors) {
            if (isCorrect) {
              borderColor = AppColors.success;
              bgColor = AppColors.success.withValues(alpha: 0.12);
              badgeFill = AppColors.successFill;
            } else if (isSelected) {
              borderColor = AppColors.danger;
              bgColor = AppColors.danger.withValues(alpha: 0.12);
              badgeFill = AppColors.dangerFill;
            } else {
              badgeColor = AppColors.textMuted;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: _selectedAnswerIndex != null
                    ? null // Eğer zaten cevap verildiyse butonları kilitle
                    : () {
                        setState(() {
                          _selectedAnswerIndex = entry.key;
                          if (isCorrect) _score++;
                        });
                      },
                child: Ink(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: borderColor, width: showColors && (isCorrect || isSelected) ? 2 : 1),
                  ),
                  child: Row(
                    children: [
                      _letterBadge(String.fromCharCode(65 + entry.key), color: badgeColor, fill: badgeFill),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (showColors && isCorrect) const Icon(Icons.check_circle_rounded, color: AppColors.success),
                      if (showColors && isSelected && !isCorrect) const Icon(Icons.cancel_rounded, color: AppColors.danger),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
        if (_selectedAnswerIndex != null && currentQ['explanation'] != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            borderColor: AppColors.secondary.withValues(alpha: 0.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, color: AppColors.secondary, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        "AÇIKLAMA",
                        style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 1.2),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: _isTranslatingExplanation
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.translate_rounded, color: AppColors.secondary, size: 20),
                      onPressed: () async {
                        if (_translatedExplanation != null) return;
                        setState(() => _isTranslatingExplanation = true);
                        try {
                          var trans = await _translator.translate(
                            currentQ['explanation'],
                            from: 'en',
                            to: 'tr',
                          );
                          if (mounted) setState(() => _translatedExplanation = trans.text);
                        } catch (e) {
                          debugPrint("Translate error: $e");
                        } finally {
                          if (mounted) setState(() => _isTranslatingExplanation = false);
                        }
                      },
                    ),
                  ],
                ),
                Text(
                  currentQ['explanation'],
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.45),
                ),
                if (_translatedExplanation != null) ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: AppSpacing.md), child: Divider()),
                  Text(
                    _translatedExplanation!,
                    style: const TextStyle(color: AppColors.secondary, fontSize: 14, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_selectedAnswerIndex != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          FilledButton(
            onPressed: () {
              if (_currentQuestionIndex < questions.length - 1) {
                setState(() {
                  _currentQuestionIndex++;
                  _selectedAnswerIndex = null;
                  _translatedExplanation = null;
                });
              } else {
                setState(() => _quizCompleted = true);
              }
            },
            child: Text(_currentQuestionIndex < questions.length - 1 ? 'Sonraki Soru' : 'Sonuçları Gör'),
          ),
        ],
      ],
    );
  }

  static const Map<String, IconData> _genreIcons = {
    'Macera': Icons.explore_rounded,
    'Gizem': Icons.search_rounded,
    'Bilim Kurgu': Icons.rocket_launch_rounded,
    'Günlük Yaşam': Icons.coffee_rounded,
    'Fantastik': Icons.auto_fix_high_rounded,
  };

  String _remaining(bool unlimited, int usage, int limit) =>
      unlimited ? 'Sınırsız' : 'Bugün ${(limit - usage).clamp(0, limit)} hakkın var';

  Widget _buildSetupScreen() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, AppSpacing.section),
      children: [
        Text('Kendi hikayenin\nkahramanı ol', style: AppText.display(size: 26)),
        const SizedBox(height: AppSpacing.sm),
        const Text(
          'Her bölümün sonunda hikayenin gidişatına sen karar verirsin. Bilmediğin kelimeye dokun, anında çevirisini gör.',
          style: AppText.body,
        ),
        const SizedBox(height: AppSpacing.section),
        const SectionHeader('Tür'),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _genres.map((g) {
            final selected = g == _selectedGenre;
            return GestureDetector(
              onTap: () => setState(() => _selectedGenre = g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_genreIcons[g] ?? Icons.book_rounded,
                        size: 18, color: selected ? Colors.white : AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Text(
                      g,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xxl),
        const SectionHeader('Seviye'),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: _levels.map((l) {
              final selected = l == _selectedLevel;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedLevel = l),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      l,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        AppCard(
          gradient: AppColors.primaryGradient,
          borderColor: null,
          onTap: _isLoading ? null : () => _startStory(false),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu_book_rounded, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Havuzdan Oku', style: AppText.heading(size: 17, color: Colors.white)),
                    const SizedBox(height: 2),
                    Text(
                      _remaining(_isReadUnlimited, _currentReadUsage, _currentReadLimit),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          onTap: _isLoading ? null : () => _startStory(true),
          child: Row(
            children: [
              const IconBadge(icon: Icons.auto_awesome_rounded, size: 48),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Yapay Zeka ile Üret', style: AppText.heading(size: 17)),
                    const SizedBox(height: 2),
                    Text(
                      'Yepyeni bir macera · ${_remaining(_isGenUnlimited, _currentGenUsage, _currentGenLimit)}',
                      style: AppText.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
        if (_isLoading) ...[
          const SizedBox(height: AppSpacing.section),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: AppSpacing.lg),
          const Text(
            'Hikaye evrenin hazırlanıyor...',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _storyTree == null ? 'Etkileşimli Hikaye' : (_storyTree!['title'] ?? 'Hikaye'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          child: _storyTree == null
              ? _buildSetupScreen()
              : (_showQuiz ? _buildQuiz() : _buildStoryContent()),
        ),
      ),
    );
  }
}
