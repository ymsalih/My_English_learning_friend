import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  bool _isPro = false;
  int _streak = 0;

  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _setupUserListener();
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
                      _fetchLearnedCount(user.uid);
                    }

                    _isPro = data['isPro'] ?? false;
                    _streak = data['streak'] ?? 0;
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: _buildPremiumDrawer(user),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'Owlish',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          if (_streak > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_streak',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Premium Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                  Color(0xFF312E81),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Animated Aura circles
          Positioned(
            top: -50,
            left: -50,
            child: _buildAura(Colors.purpleAccent.withOpacity(0.3), 300),
          ),
          Positioned(
            top: 200,
            right: -100,
            child: _buildAura(Colors.blueAccent.withOpacity(0.2), 400),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Merhaba, $_userName \ud83d\udc4b",
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Öğrenme serüvenine nereden devam edelim?",
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 30),

                        _buildPremiumStatCard(context),

                        const SizedBox(height: 40),
                        const Text(
                          "Ana Modüller",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 15),

                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.9,
                          children: [
                            _buildGlassCard(
                              context,
                              'Kelime Havuzu',
                              'Sözlüğün',
                              Icons.auto_awesome_motion,
                              Colors.blueAccent,
                              const HomeScreen(),
                            ),
                            _buildGlassCard(
                              context,
                              'Kendini Test Et',
                              'Bilgini Sına',
                              Icons.psychology,
                              Colors.purpleAccent,
                              const TestScreen(),
                            ),
                            _buildGlassCard(
                              context,
                              'Hikaye Oku',
                              'Etkileşimli',
                              Icons.auto_stories,
                              Colors.pinkAccent,
                              const StoryScreen(),
                            ),
                            _buildGlassCard(
                              context,
                              'Yapay Zeka',
                              'Sohbet Et',
                              Icons.forum,
                              Colors.tealAccent,
                              const ChatScreen(),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),
                        const Text(
                          "Pratik & Araçlar",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 15),

                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 1.1,
                          children: [
                            _buildGlassCard(
                              context,
                              'Çeviri',
                              'Akıllı',
                              Icons.g_translate,
                              Colors.greenAccent,
                              const TranslationScreen(),
                            ),
                            _buildGlassCard(
                              context,
                              'Öğrendiklerim',
                              'Arşiv',
                              Icons.workspace_premium,
                              Colors.amberAccent,
                              const LearnedWordsScreen(),
                            ),
                            _buildGlassCard(
                              context,
                              'Paketler',
                              'Hazır Setler',
                              Icons.inventory_2,
                              Colors.orangeAccent,
                              const WordLearningScreen(),
                            ),
                            _buildGlassCard(
                              context,
                              'Haberler',
                              'Güncel Okuma',
                              Icons.menu_book,
                              Colors.cyanAccent,
                              const NewsScreen(),
                            ),
                            _buildGlassCard(
                              context,
                              'Video',
                              'İzleyerek Öğren',
                              Icons.play_circle_fill,
                              Colors.redAccent,
                              const VideoPracticeScreen(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAura(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withOpacity(0.0)],
          stops: const [0.2, 1.0],
        ),
      ),
    );
  }

  Widget _buildPremiumStatCard(BuildContext context) {
    int totalAnswered = _totalCorrect + _totalWrong;
    double successRate = totalAnswered > 0
        ? (_totalCorrect / totalAnswered)
        : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProgressReportScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(
            0xFF1E293B,
          ).withOpacity(0.7), // Blur yerine düz hafif saydam renk
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "GENEL DURUM",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    totalAnswered > 0
                        ? "Harika İlerliyorsun!"
                        : "Hemen Başlayalım!",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (totalAnswered > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.orangeAccent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_totalLearned' " kelime tamamlandı",
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (totalAnswered > 0)
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: successRate,
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        successRate > 0.7
                            ? Colors.greenAccent
                            : Colors.amberAccent,
                      ),
                    ),
                    Center(
                      child: Text(
                        "%" '${(successRate * 100).toInt()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              const Icon(Icons.rocket_launch, color: Colors.white, size: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    Widget destination,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => destination),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(
            0xFF1E293B,
          ).withOpacity(0.5), // Blur yerine performanslı saydam arka plan
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: iconColor.withOpacity(0.3), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: iconColor.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Arka plan su dalgası efekti (hala var ama bulanık değil)
              Positioned(
                right: -20,
                bottom: -20,
                child: Icon(icon, size: 100, color: iconColor.withOpacity(0.1)),
              ),
              Padding(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [iconColor.withOpacity(0.8), iconColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 30),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumDrawer(User? user) {
    return Drawer(
      backgroundColor: const Color(0xFF0F172A), // Performans için düz koyu renk
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ClipRRect(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: 30,
                  top: 70,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.purpleAccent, Colors.deepPurple],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purpleAccent.withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _userInitial,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? "Kullanıcı",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildDrawerTile(
                      context,
                      icon: Icons.home_rounded,
                      title: 'Ana Sayfa',
                      iconColor: Colors.blueAccent,
                      onTap: () => Navigator.pop(context),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.trending_up_rounded,
                      title: 'Gelişim Raporum',
                      iconColor: Colors.purpleAccent,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProgressReportScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.mail_outline_rounded,
                      title: 'Bize Ulaşın',
                      iconColor: Colors.cyanAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _sendEmail(context);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: Divider(color: Colors.white.withOpacity(0.1)),
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.record_voice_over_rounded,
                      title: 'Ses Ayarları',
                      iconColor: Colors.tealAccent,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildDrawerTile(
                      context,
                      icon: Icons.logout_rounded,
                      title: 'Çıkış Yap',
                      iconColor: Colors.redAccent,
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(context);
                        _signOut(context);
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.verified_rounded,
                      size: 18,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Sürüm 1.0.1",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color iconColor,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDestructive
            ? Colors.redAccent.withOpacity(0.1)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDestructive
              ? Colors.redAccent.withOpacity(0.2)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(color: iconColor.withOpacity(0.2), blurRadius: 10),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDestructive
                ? Colors.redAccent
                : Colors.white.withOpacity(0.9),
            letterSpacing: -0.3,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.white.withOpacity(0.2),
        ),
      ),
    );
  }
}
