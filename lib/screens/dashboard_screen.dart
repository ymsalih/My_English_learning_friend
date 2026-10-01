import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'home_screen.dart';
import 'test_screen.dart';
import 'translation_screen.dart';
import 'video_practice_screen.dart';
import 'word_learning_screen.dart';
import 'auth_screen.dart';
import 'news_screen.dart';
import 'learned_words_screen.dart';
import 'progress_report_screen.dart';
import 'settings_screen.dart';
import 'chat_screen.dart';
import 'story_screen.dart';
import 'reading_practice_screen.dart';
import 'paywall_screen.dart';
import 'profile_screen.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = "Öğrenci";
  String _userInitial = "Ö";

  int _totalTests = 0;
  int _totalCorrect = 0;
  int _totalWrong = 0;
  int _totalLearned = 0;

  String _subscriptionPlan = 'basic';
  Map<String, Map<String, int>> _limitsSummary = {};
  int _streak = 0;
  String _appVersion = "1.0.0";

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  // Kelime sayısı yalnızca istatistikler değişince yeniden sorgulanır
  // (günlük sayaç artışları gibi alakasız değişikliklerde değil).
  Map<String, dynamic>? _lastStats;

  @override
  void initState() {
    super.initState();
    _setupUserListener();
    _initPackageInfo();
  }

  Future<void> _initPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = info.version;
      });
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _setupUserListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _fetchLearnedCount(user.uid); // İlk girişte gerçek sayıyı çek

      // 1. ANA KULLANICI VE STATS DİNLEYİCİSİ (Doğru/Yanlış oranları için)
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
            (userDoc) {
              if (userDoc.exists && userDoc.data() != null) {
                final data = userDoc.data() as Map<String, dynamic>;

                if (mounted) {
                  setState(() {
                    if (data['username'] != null) {
                      String dbName = data['username'].toString();
                      if (dbName.isNotEmpty) {
                        _userName =
                            dbName[0].toUpperCase() + dbName.substring(1);
                        _userInitial = dbName[0].toUpperCase();
                      }
                    }

                    if (data['stats'] != null) {
                      Map<String, dynamic> stats = Map<String, dynamic>.from(
                        data['stats'],
                      );
                      _totalTests = (stats['totalTests'] ?? 0).toInt();
                      _totalCorrect = (stats['totalCorrect'] ?? 0).toInt();
                      _totalWrong = (stats['totalWrong'] ?? 0).toInt();
                      // stats['totalLearned'] artık eski verilerde sıfır olabileceği için
                      // güvenilir olan _fetchLearnedCount ile alıyoruz.
                      if (_lastStats != null && !mapEquals(_lastStats, stats)) {
                        _fetchLearnedCount(user.uid);
                      }
                      _lastStats = stats;
                    }

                    _subscriptionPlan = data['subscriptionPlan'] ?? 'basic';
                    // Seri bozulduysa veritabanındaki eski değer değil 0 gösterilir.
                    _streak = SubscriptionService.effectiveStreak(data);

                    // Build real-time limits summary from snapshot
                    final limitsMap =
                        SubscriptionService.limits[_subscriptionPlan] ??
                        SubscriptionService.limits['basic']!;
                    final dailyUsage =
                        data['dailyUsage'] as Map<String, dynamic>? ?? {};
                    _limitsSummary = {
                      'words': {
                        'current': (data['lifetimeWordsAdded'] ?? 0) as int,
                        'limit': limitsMap['lifetimeWordsAdded'] as int,
                      },
                      'storyGen': {
                        'current': (dailyUsage['storyGenCount'] ?? 0) as int,
                        'limit': limitsMap['storyGenCount'] as int,
                      },
                      'storyRead': {
                        'current': (dailyUsage['storyReadCount'] ?? 0) as int,
                        'limit': limitsMap['storyReadCount'] as int,
                      },
                      'chat': {
                        'current': (dailyUsage['chatMsgCount'] ?? 0) as int,
                        'limit': limitsMap['chatMsgCount'] as int,
                      },
                      'translate': {
                        'current': (dailyUsage['translateCount'] ?? 0) as int,
                        'limit': limitsMap['translateCount'] as int,
                      },
                      'test': {
                        'current': (dailyUsage['testCount'] ?? 0) as int,
                        'limit': limitsMap['testCount'] as int,
                      },
                    };
                  });
                }
              }
            },
            onError: (e) {
              debugPrint("Veri dinleme hatası: $e");
              if (mounted) {
                String fallbackName =
                    user.displayName ?? user.email?.split('@')[0] ?? "Öğrenci";
                setState(() {
                  _userName = fallbackName.isNotEmpty
                      ? fallbackName[0].toUpperCase() +
                            fallbackName.substring(1)
                      : "Öğrenci";
                  _userInitial = fallbackName.isNotEmpty
                      ? fallbackName[0].toUpperCase()
                      : "Ö";
                });
              }
            },
          );
    }
  }

  // 🚀 O(1) Gerçek ve Güvenilir Sayım (Aggregation Query)
  Future<void> _fetchLearnedCount(String uid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('words')
          .where('isLearned', isEqualTo: true)
          .count()
          .get();

      if (mounted) {
        setState(() {
          _totalLearned = snapshot.count ?? 0;
        });
      }
    } catch (e) {
      debugPrint("Count error: $e");
    }
  }

  Future<void> _sendEmail(BuildContext context) async {
    const String myEmail = 'myenglishfriendss@gmail.com';
    const String subject = 'Uygulama Hakkında Öneri ve Şikayet';

    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: myEmail,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );

    try {
      if (await canLaunchUrl(emailLaunchUri)) {
        await launchUrl(emailLaunchUri);
      } else {
        throw 'Mail uygulaması açılamadı.';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Telefonunuzda bir mail uygulaması bulunamadı."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  void _open(Widget screen) {
    // Alt sekmesi olan ekranlar ayrı sayfa yerine sekmede açılır.
    if (screen is HomeScreen) return _selectTab(1);
    if (screen is TestScreen) return _selectTab(2);
    if (screen is ReadingPracticeScreen) return _selectTab(3);
    if (screen is ProfileScreen) return _selectTab(4);
    Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
  }

  // Alt navigasyon: 0 Ana Sayfa, 1 Kelime Havuzu, 2 Test, 3 Telaffuz, 4 Profil.
  int _tabIndex = 0;
  // Sekmeler ilk ziyarette oluşturulur (açılışta gereksiz Firestore sorgusu yok).
  final Set<int> _visitedTabs = {0};
  // Test sekmesine her girişte havuz yeniden yüklenir (yeni eklenen kelimeler görünsün).
  int _testTabGeneration = 0;

  void _selectTab(int index) {
    setState(() {
      if (index == 2 && _tabIndex != 2) _testTabGeneration++;
      _tabIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final test = _limitsSummary['test'];

    final home = AppBackground(
        child: Builder(
          builder: (context) => DashboardHomeView(
            userName: _userName,
            userInitial: _userInitial,
            streak: _streak,
            totalLearned: _totalLearned,
            totalTests: _totalTests,
            totalCorrect: _totalCorrect,
            totalWrong: _totalWrong,
            isPremium: _subscriptionPlan != 'basic',
            testUsed: test?['current'],
            testLimit: test?['limit'],
            onMenu: () => Scaffold.of(context).openDrawer(),
            onOpen: _open,
          ),
        ),
      );

    return Scaffold(
      drawer: _buildDrawer(user),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          home,
          _visitedTabs.contains(1) ? const HomeScreen() : const SizedBox.shrink(),
          _visitedTabs.contains(2) ? TestScreen(key: ValueKey(_testTabGeneration)) : const SizedBox.shrink(),
          _visitedTabs.contains(3) ? const ReadingPracticeScreen() : const SizedBox.shrink(),
          _visitedTabs.contains(4) ? const ProfileScreen(embedded: true) : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: _selectTab,
          backgroundColor: AppColors.bgBottom,
          indicatorColor: AppColors.primary.withValues(alpha: 0.22),
          surfaceTintColor: Colors.transparent,
          height: 66,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: s.contains(WidgetState.selected) ? AppColors.textPrimary : AppColors.textMuted,
            ),
          ),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.primaryLight),
              label: 'Ana Sayfa',
            ),
            NavigationDestination(
              icon: Icon(Icons.style_outlined, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.style_rounded, color: AppColors.primaryLight),
              label: 'Kelimeler',
            ),
            NavigationDestination(
              icon: Icon(Icons.quiz_outlined, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.quiz_rounded, color: AppColors.primaryLight),
              label: 'Test',
            ),
            NavigationDestination(
              icon: Icon(Icons.mic_none_rounded, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.mic_rounded, color: AppColors.primaryLight),
              label: 'Telaffuz',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.primaryLight),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(User? user) {
    return Drawer(
      child: AppBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Row(
                  children: [
                    _Avatar(initial: _userInitial, size: 56),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: AppText.heading(size: 19),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user?.email ?? "Kullanıcı",
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  children: [
                    _buildDrawerTile(
                      icon: Icons.home_rounded,
                      title: 'Ana Sayfa',
                      onTap: () {
                        Navigator.pop(context);
                        _selectTab(0);
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.person_rounded,
                      title: 'Profilim',
                      onTap: () {
                        Navigator.pop(context);
                        _selectTab(4);
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.forum_rounded,
                      title: 'Yapay Zeka Sohbet',
                      onTap: () {
                        Navigator.pop(context);
                        _open(const ChatScreen());
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.insights_rounded,
                      title: 'Gelişim Raporum',
                      onTap: () {
                        Navigator.pop(context);
                        _open(const ProgressReportScreen());
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Octopus Premium',
                      color: AppColors.gold,
                      onTap: () {
                        Navigator.pop(context);
                        _open(const PaywallScreen());
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.settings_rounded,
                      title: 'Ayarlar',
                      onTap: () {
                        Navigator.pop(context);
                        _open(const SettingsScreen());
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.mail_outline_rounded,
                      title: 'Bize Ulaşın',
                      onTap: () {
                        Navigator.pop(context);
                        _sendEmail(context);
                      },
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Divider(),
                    ),
                    _buildDrawerTile(
                      icon: Icons.logout_rounded,
                      title: 'Çıkış Yap',
                      color: AppColors.danger,
                      onTap: () {
                        Navigator.pop(context);
                        _signOut(context);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text("Sürüm $_appVersion", style: AppText.caption),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = AppColors.textSecondary,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        title,
        style: TextStyle(
          color: color == AppColors.textSecondary ? AppColors.textPrimary : color,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Ana sayfa görünümü. Yalnızca veri ve geri çağrılar alır; Firebase'e
/// doğrudan erişmez.
class DashboardHomeView extends StatelessWidget {
  const DashboardHomeView({
    super.key,
    required this.userName,
    required this.userInitial,
    required this.streak,
    required this.totalLearned,
    required this.totalTests,
    required this.totalCorrect,
    required this.totalWrong,
    required this.isPremium,
    required this.testUsed,
    required this.testLimit,
    required this.onMenu,
    required this.onOpen,
  });

  final String userName;
  final String userInitial;
  final int streak;
  final int totalLearned;
  final int totalTests;
  final int totalCorrect;
  final int totalWrong;
  final bool isPremium;
  final int? testUsed;
  final int? testLimit;
  final VoidCallback onMenu;
  final void Function(Widget screen) onOpen;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.page, AppSpacing.sm, AppSpacing.page, 40),
        children: [
          _buildTopBar(),
          const SizedBox(height: AppSpacing.xxl),
          Text("Merhaba, $userName 👋", style: AppText.display(size: 28)),
          const SizedBox(height: AppSpacing.xs),
          const Text("Bugün ne öğrenmek istersin?", style: AppText.body),
          const SizedBox(height: AppSpacing.xxl),
          _buildTutorCard(),
          const SizedBox(height: AppSpacing.lg),
          _buildProgressCard(),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader("Öğren"),
          _buildLearnGrid(),
          const SizedBox(height: AppSpacing.section),
          const SectionHeader("Pratik Yap"),
          _buildPracticeList(),
          if (!isPremium) ...[
            const SizedBox(height: AppSpacing.section),
            _buildPremiumBanner(),
          ],
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        _RoundIconButton(icon: Icons.menu_rounded, onTap: onMenu, tooltip: 'Menü'),
        const Spacer(),
        InfoPill(
          icon: Icons.local_fire_department_rounded,
          label: '$streak gün',
          color: AppColors.gold,
        ),
        const SizedBox(width: AppSpacing.sm),
        GestureDetector(
          onTap: () => onOpen(const ProfileScreen()),
          child: _Avatar(initial: userInitial, size: 40),
        ),
      ],
    );
  }

  /// Kahraman kart: rakip uygulamalarda olduğu gibi ana sayfada tek ve net bir
  /// birincil eylem (günlük kelime tekrarı).
  Widget _buildTutorCard() {
    final unlimited = (testLimit ?? 0) >= 999999;
    final String? usage = testLimit == null
        ? null
        : unlimited
            ? 'Sınırsız tekrar hakkı'
            : 'Bugün ${(testLimit! - (testUsed ?? 0)).clamp(0, testLimit!)} kelime tekrar hakkın var';

    return AppCard(
      gradient: AppColors.primaryGradient,
      borderColor: null,
      radius: AppRadius.xl,
      padding: EdgeInsets.zero,
      onTap: () => onOpen(const TestScreen()),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -22,
            child: Image.asset('assets/logo_transparent.png', width: 150, height: 150),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 104, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "GÜNLÜK TEKRAR",
                  style: AppText.overline.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text("Kelime testi zamanı", style: AppText.display(size: 24, color: Colors.white)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Düzenli tekrarla kelimeleri kalıcı olarak öğren. Günde birkaç dakika yeter.",
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          "Teste başla",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 18),
                    ],
                  ),
                ),
                if (usage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    usage,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard() {
    final answered = totalCorrect + totalWrong;
    final rate = answered > 0 ? totalCorrect / answered : 0.0;

    return AppCard(
      onTap: () => onOpen(const ProgressReportScreen()),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: answered > 0 ? rate : 0,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor: const AlwaysStoppedAnimation(AppColors.success),
                    ),
                    Center(
                      child: Text(
                        answered > 0 ? "%${(rate * 100).round()}" : "–",
                        style: AppText.heading(size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("GENEL DURUM", style: AppText.overline),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      answered > 0 ? "Harika ilerliyorsun!" : "Hemen başlayalım!",
                      style: AppText.heading(size: 18),
                    ),
                    const SizedBox(height: 2),
                    const Text("Başarı oranın ve istatistiklerin", style: AppText.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const Divider(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Stat(value: '$totalLearned', label: 'Öğrenilen'),
              _statDivider(),
              _Stat(value: '$totalTests', label: 'Test'),
              _statDivider(),
              _Stat(value: '$totalCorrect', label: 'Doğru cevap'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statDivider() => Container(width: 1, height: 32, color: AppColors.border);

  Widget _buildLearnGrid() {
    final items = [
      _Module('Kelime Havuzu', 'Kendi sözlüğün', Icons.style_rounded, const HomeScreen()),
      _Module('Kendini Test Et', 'Bilgini sına', Icons.quiz_rounded, const TestScreen()),
      _Module('Hikaye Oku', 'Etkileşimli hikayeler', Icons.auto_stories_rounded, const StoryScreen()),
      _Module('Akıllı Çeviri', 'Metin ve kamera', Icons.translate_rounded, const TranslationScreen()),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.25,
      children: [
        for (final m in items)
          AppCard(
            onTap: () => onOpen(m.screen),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconBadge(icon: m.icon),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(m.subtitle, style: AppText.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPracticeList() {
    final items = [
      _Module('Telaffuz', 'Oku, dinle ve konuş', Icons.mic_rounded, const ReadingPracticeScreen()),
      _Module('Video ile Öğren', 'İzleyerek pratik yap', Icons.play_circle_rounded, const VideoPracticeScreen()),
      _Module('Haberler', 'Güncel okuma metinleri', Icons.newspaper_rounded, const NewsScreen()),
      _Module('Kelime Paketleri', 'Hazır kelime setleri', Icons.inventory_2_rounded, const WordLearningScreen()),
      _Module('Öğrendiklerim', 'Tamamladığın kelimeler', Icons.emoji_events_rounded, const LearnedWordsScreen()),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(indent: 72),
            ListTile(
              onTap: () => onOpen(items[i].screen),
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 2),
              leading: IconBadge(icon: items[i].icon, color: AppColors.secondary, size: 40),
              title: Text(
                items[i].title,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(items[i].subtitle, style: AppText.caption),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPremiumBanner() {
    return AppCard(
      onTap: () => onOpen(const PaywallScreen()),
      borderColor: AppColors.gold.withValues(alpha: 0.45),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.goldGradient,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: AppColors.bg, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Octopus Premium", style: AppText.heading(size: 16, color: AppColors.gold)),
                const SizedBox(height: 2),
                const Text("Daha fazla sohbet, hikaye ve çeviri hakkı", style: AppText.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.gold),
        ],
      ),
    );
  }
}

class _Module {
  const _Module(this.title, this.subtitle, this.icon, this.screen);
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget screen;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppText.heading(size: 20)),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.caption,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial, required this.size});
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(initial, style: AppText.heading(size: size * 0.42, color: Colors.white)),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, required this.tooltip});
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 40, height: 40, child: Icon(icon, color: AppColors.textPrimary, size: 22)),
        ),
      ),
    );
  }
}
