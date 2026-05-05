import 'dart:ui';
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
                    }
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
      drawer: _buildPremiumDrawer(user),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Arka Plan Işıkları
          Positioned(
            top: -100,
            left: -100,
            child: _buildGlowSphere(
              Colors.deepPurpleAccent.withOpacity(0.15),
              300,
            ),
          ),
          Positioned(
            top: 250,
            right: -150,
            child: _buildGlowSphere(Colors.blueAccent.withOpacity(0.15), 350),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _buildGlowSphere(Colors.tealAccent.withOpacity(0.1), 250),
          ),

          // Ana İçerik
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // 🚀 GÜNCELLEME: Bildirim butonu kaldırıldı, AppBar tamamen sadeleşti
              SliverAppBar(
                expandedHeight: 80.0,
                floating: true,
                pinned: true,
                backgroundColor: Colors.white.withOpacity(0.5),
                elevation: 0,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(color: Colors.transparent),
                  ),
                ),
                iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
                centerTitle: true,
                title: const Text(
                  'İngilizce Arkadaşım',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E293B),
                    letterSpacing: -0.5,
                  ),
                ),
                // 🚀 Buradaki "actions" listesini boşalttık
                actions: const [
                  SizedBox(
                    width: 56,
                  ), // Menü ikonuyla denge sağlaması için boşluk
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),

                      Text(
                        "Merhaba, $_userName 👋",
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        "Bugün öğrenme serüvenine nereden devam edelim?",
                        style: TextStyle(
                          fontSize: 15,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 30),

                      _buildPremiumStatCard(),

                      const SizedBox(height: 35),

                      _buildSectionHeader("Ana Modüller", Icons.school_rounded),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _buildCleanCard(
                              context,
                              title: 'Kelime Havuzu',
                              subtitle: 'Kendi Sözlüğün',
                              icon: Icons.auto_awesome_motion_rounded,
                              iconColor: const Color(0xFF3B82F6),
                              destination: const HomeScreen(),
                              height: 180,
                              isSmall: false,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              children: [
                                _buildCleanCard(
                                  context,
                                  title: 'Kendini Test Et',
                                  subtitle: 'Bilgini Sına',
                                  icon: Icons.psychology_rounded,
                                  iconColor: const Color(0xFF8B5CF6),
                                  destination: const TestScreen(),
                                  height: 82,
                                  isSmall: true,
                                ),
                                const SizedBox(height: 16),
                                _buildCleanCard(
                                  context,
                                  title: 'Öğrendiklerim',
                                  subtitle: 'Arşiv',
                                  icon: Icons.workspace_premium_rounded,
                                  iconColor: const Color(0xFFF59E0B),
                                  destination: const LearnedWordsScreen(),
                                  height: 82,
                                  isSmall: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 35),

                      _buildSectionHeader(
                        "Araçlar & Pratik",
                        Icons.build_circle_rounded,
                      ),
                      const SizedBox(height: 16),

                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                        children: [
                          _buildCleanCard(
                            context,
                            title: 'Akıllı Çeviri',
                            subtitle: 'Yapay Zeka',
                            icon: Icons.g_translate_rounded,
                            iconColor: const Color(0xFF10B981),
                            destination: const TranslationScreen(),
                          ),
                          _buildCleanCard(
                            context,
                            title: 'Paketler',
                            subtitle: 'Hazır Setler',
                            icon: Icons.inventory_2_rounded,
                            iconColor: const Color(0xFFF43F5E),
                            destination: const WordLearningScreen(),
                          ),
                          _buildCleanCard(
                            context,
                            title: 'Video Pratik',
                            subtitle: 'İzleyerek Öğren',
                            icon: Icons.play_circle_fill_rounded,
                            iconColor: const Color(0xFFEF4444),
                            destination: const VideoPracticeScreen(),
                          ),
                          _buildCleanCard(
                            context,
                            title: 'Okuma',
                            subtitle: 'Güncel Haberler',
                            icon: Icons.menu_book_rounded,
                            iconColor: const Color(0xFF6366F1),
                            destination: const NewsScreen(),
                          ),
                        ],
                      ),

                      const SizedBox(height: 60),

                      Center(
                        child: Column(
                          children: [
                            Text(
                              "© 2026 İngilizce Arkadaşım",
                              style: TextStyle(
                                color: const Color(0xFF94A3B8).withOpacity(0.6),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI METODLAR ---

  Widget _buildGlowSphere(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 20)],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF475569)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1E293B),
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumStatCard() {
    int totalAnswered = _totalCorrect + _totalWrong;
    double successRate = totalAnswered > 0
        ? (_totalCorrect / totalAnswered)
        : 0.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.blueAccent.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.4),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: const Text(
                          "GENEL DURUM",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        totalAnswered > 0
                            ? "Harika ilerliyorsun!"
                            : "Hemen başlayalım!",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (totalAnswered > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.orangeAccent,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "$_totalTests kelimede ustalaştın. Devam!",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Text(
                          "Sözlüğüne kelime ekle ve testlere katıl.",
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                if (totalAnswered > 0)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              (successRate > 0.7
                                      ? const Color(0xFF34D399)
                                      : Colors.orangeAccent)
                                  .withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: successRate,
                          strokeWidth: 8,
                          backgroundColor: Colors.white.withOpacity(0.15),
                          strokeCap: StrokeCap.round,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            successRate > 0.7
                                ? const Color(0xFF34D399)
                                : Colors.orangeAccent,
                          ),
                        ),
                        Center(
                          child: Text(
                            "%${(successRate * 100).toInt()}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCleanCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Widget destination,
    double? height,
    bool isSmall = false,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              highlightColor: iconColor.withOpacity(0.05),
              splashColor: iconColor.withOpacity(0.1),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => destination),
              ),
              child: Padding(
                padding: EdgeInsets.all(isSmall ? 12.0 : 20.0),
                child: isSmall
                    ? Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: iconColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: iconColor, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: iconColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(icon, color: iconColor, size: 24),
                              ),
                              if (height == null || height > 100)
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: const Color(0xFFCBD5E1),
                                ),
                            ],
                          ),
                          if (height == null || height > 100) const Spacer(),
                          if (height != null && height <= 100)
                            const SizedBox(height: 12),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumDrawer(User? user) {
    return Drawer(
      backgroundColor: const Color(0xFFF8FAFC),
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
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9), width: 2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF3B82F6).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _userInitial,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
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
                          color: Color(0xFF0F172A),
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.email ?? "Kullanıcı",
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
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
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildDrawerTile(
                  context,
                  icon: Icons.home_rounded,
                  title: 'Ana Sayfa',
                  iconColor: const Color(0xFF3B82F6),
                  onTap: () => Navigator.pop(context),
                ),
                _buildDrawerTile(
                  context,
                  icon: Icons.trending_up_rounded,
                  title: 'Gelişim Raporum',
                  iconColor: const Color(0xFF8B5CF6),
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
                  iconColor: const Color(0xFF0EA5E9),
                  onTap: () {
                    Navigator.pop(context);
                    _sendEmail(context);
                  },
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Color(0xFFE2E8F0)),
                ),

                _buildDrawerTile(
                  context,
                  icon: Icons.record_voice_over_rounded,
                  title: 'Ses Ayarları',
                  iconColor: const Color(0xFF10B981),
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
                  iconColor: const Color(0xFFEF4444),
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
              children: const [
                Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
                SizedBox(width: 8),
                Text(
                  "Sürüm 1.0.1",
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        hoverColor: iconColor.withOpacity(0.05),
        splashColor: iconColor.withOpacity(0.1),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDestructive
                ? const Color(0xFFFEF2F2)
                : iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: isDestructive ? const Color(0xFFEF4444) : iconColor,
            size: 22,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: isDestructive
                ? const Color(0xFFEF4444)
                : const Color(0xFF1E293B),
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}
