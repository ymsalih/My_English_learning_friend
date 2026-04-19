import 'dart:ui';
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
import 'progress_report_screen.dart'; // 🚀 YENİ İSTATİSTİK SAYFAMIZ EKLENDİ

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _userName = "Öğrenci";
  String _userInitial = "Ö";

  // --- 📊 FİREBASE'DEN GELECEK İSTATİSTİK DEĞİŞKENLERİ ---
  int _totalTests = 0;
  int _totalCorrect = 0;
  int _totalWrong = 0;

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Hem ismi hem istatistikleri çekeceğiz
  }

  // --- 🔄 İSİM VE İSTATİSTİKLERİ FİREBASE'DEN ÇEKME (%100 GÜVENLİ) ---
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;

          setState(() {
            // 1. İsim Çekme
            if (data['username'] != null) {
              String dbName = data['username'].toString();
              if (dbName.isNotEmpty) {
                _userName = dbName[0].toUpperCase() + dbName.substring(1);
                _userInitial = dbName[0].toUpperCase();
              }
            }

            // 2. İstatistik Çekme (Ana sayfadaki ateşli % yazısı için)
            if (data['stats'] != null) {
              // Firebase'in gönderdiği map'i güvenli bir şekilde dönüştürüyoruz
              Map<String, dynamic> stats = Map<String, dynamic>.from(
                data['stats'],
              );

              _totalTests = (stats['totalTests'] ?? 0).toInt();
              _totalCorrect = (stats['totalCorrect'] ?? 0).toInt();
              _totalWrong = (stats['totalWrong'] ?? 0).toInt();
            }
          });
          return; // Hata yoksa fonksiyondan çık
        }
      } catch (e) {
        debugPrint("Veri çekilirken hata oluştu: $e");
      }

      // Hata olursa veya veri yoksa yedek (fallback) isim göster
      String fallbackName =
          user.displayName ?? user.email?.split('@')[0] ?? "Öğrenci";
      setState(() {
        _userName = fallbackName.isNotEmpty
            ? fallbackName[0].toUpperCase() + fallbackName.substring(1)
            : "Öğrenci";
        _userInitial = fallbackName.isNotEmpty
            ? fallbackName[0].toUpperCase()
            : "Ö";
      });
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
      backgroundColor: const Color(0xFFF8FAFF),
      extendBodyBehindAppBar: true,

      appBar: AppBar(
        title: const Text(
          'İngilizce Arkadaşım',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => _signOut(context),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),

      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, const Color(0xFFF8FAFF).withOpacity(0.9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
            children: [
              _buildModernDrawerHeader(_userName, _userInitial, user?.email),

              const SizedBox(height: 25),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  children: [
                    _buildDrawerItem(
                      context,
                      icon: Icons.home_rounded,
                      title: 'Ana Sayfa',
                      color: Colors.blue.shade900,
                      onTap: () => Navigator.pop(context),
                    ),

                    // --- 🚀 GÜNCELLENEN: GELİŞİM RAPORU BUTONU ---
                    _buildDrawerItem(
                      context,
                      icon: Icons.trending_up_rounded,
                      title: 'Gelişim Raporum',
                      subtitle: 'Detaylı analiz ve geçmiş',
                      color: Colors.purple.shade600,
                      onTap: () {
                        Navigator.pop(context); // Menüyü kapat
                        // Yeni Sayfaya Yönlendir
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProgressReportScreen(),
                          ),
                        ).then((_) {
                          // Sayfadan döndüğünde ana sayfadaki verileri tazele
                          _fetchUserData();
                        });
                      },
                    ),

                    _buildDrawerItem(
                      context,
                      icon: Icons.mail_outline_rounded,
                      title: 'Bize Ulaşın (Destek)',
                      subtitle: 'Öneri ve şikayetlerinizi iletin',
                      color: Colors.blueAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _sendEmail(context);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildDrawerItem(
                      context,
                      icon: Icons.logout_rounded,
                      title: 'Çıkış Yap',
                      color: Colors.redAccent,
                      isSignOut: true,
                      onTap: () {
                        Navigator.pop(context);
                        _signOut(context);
                      },
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(15.0),
                child: Text(
                  "Sürüm 1.0.1",
                  style: TextStyle(color: Colors.black38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),

      body: Stack(
        children: [
          _buildBlurCircle(Colors.blue.withOpacity(0.2), 300),
          Positioned(
            bottom: 100,
            left: -100,
            child: _buildBlurCircle(Colors.purple.withOpacity(0.1), 400),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    "Merhaba 👋",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    "Bugün ne öğreniyoruz?",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 25),

                  _buildUserPanel(_userName),

                  const SizedBox(height: 35),

                  // --- 1. KATEGORİ: TEMEL ÖĞRENİM ---
                  const Text(
                    "Temel Öğrenim",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 15),

                  _buildCreativeButton(
                    context,
                    title: 'Kelime Havuzum',
                    subtitle: 'Kendi kelime kütüphanen',
                    icon: Icons.auto_awesome_motion_rounded,
                    colors: [Colors.blue.shade700, Colors.blue.shade400],
                    destination: const HomeScreen(),
                  ),

                  _buildCreativeButton(
                    context,
                    title: 'Kendini Test Et',
                    subtitle: 'Öğrendiklerini pekiştir',
                    icon: Icons.psychology_rounded,
                    colors: [
                      Colors.deepPurple.shade700,
                      Colors.purple.shade400,
                    ],
                    destination: const TestScreen(),
                  ),

                  _buildCreativeButton(
                    context,
                    title: 'Öğrendiklerim (Arşiv)',
                    subtitle: 'Ustalaştığın kelimeleri yönet',
                    icon: Icons.workspace_premium_rounded,
                    colors: [Colors.pink.shade600, Colors.pinkAccent.shade400],
                    destination: const LearnedWordsScreen(),
                  ),

                  const SizedBox(height: 25),
                  // --- 2. KATEGORİ: ARAÇLAR & PRATİK ---
                  const Text(
                    "Araçlar & Ekstra Pratik",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 15),

                  _buildCreativeButton(
                    context,
                    title: 'Akıllı Çeviri',
                    subtitle: 'Anlık çevir ve kaydet',
                    icon: Icons.g_translate_rounded,
                    colors: [Colors.teal.shade700, Colors.tealAccent.shade700],
                    destination: const TranslationScreen(),
                  ),

                  _buildCreativeButton(
                    context,
                    title: 'Kelime Paketleri',
                    subtitle: 'Hazır kelime setleri',
                    icon: Icons.school_rounded,
                    colors: [Colors.orange.shade800, Colors.orange.shade400],
                    destination: const WordLearningScreen(),
                  ),

                  _buildCreativeButton(
                    context,
                    title: 'İngilizce Pratik',
                    subtitle: 'Video analizli eğitim',
                    icon: Icons.play_circle_fill_rounded,
                    colors: [Colors.red.shade700, Colors.redAccent.shade400],
                    destination: const VideoPracticeScreen(),
                  ),

                  _buildCreativeButton(
                    context,
                    title: 'Okuma Pratiği',
                    subtitle: 'Güncel haberlerle İngilizce',
                    icon: Icons.menu_book_rounded,
                    colors: [Colors.indigo.shade700, Colors.indigo.shade400],
                    destination: const NewsScreen(),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI METODLAR ---

  Widget _buildModernDrawerHeader(
    String userName,
    String initial,
    String? email,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(left: 25, right: 20, bottom: 35, top: 65),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade900.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email ?? "Kullanıcı",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required Color color,
    bool isSignOut = false,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSignOut ? Colors.redAccent.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: isSignOut
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isSignOut ? Colors.redAccent.shade700 : Colors.black87,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              )
            : null,
        trailing: isSignOut
            ? null
            : Icon(Icons.chevron_right_rounded, color: color.withOpacity(0.4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  Widget _buildUserPanel(String name) {
    // Toplam başarıyı hesapla
    int totalAnswered = _totalCorrect + _totalWrong;
    double successRate = totalAnswered > 0
        ? (_totalCorrect / totalAnswered) * 100
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.blue.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white24, width: 2),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Colors.yellowAccent,
              size: 35,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Harika gidiyorsun, $name!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),

                // --- İSTATİSTİK BİLGİSİ ---
                totalAnswered > 0
                    ? Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            color: Colors.orangeAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Genel Başarı: %${successRate.toStringAsFixed(0)}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : const Text(
                        "Hedeflerine ulaşmak için harika bir gün. Hadi başlayalım!",
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurCircle(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(color: Colors.transparent),
      ),
    );
  }

  Widget _buildCreativeButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> colors,
    required Widget destination,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () =>
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination),
            ).then((_) {
              // Sayfadan geri dönüldüğünde istatistikleri güncellemek için verileri tekrar çek
              _fetchUserData();
            }),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(
                  0.15,
                ), // İç ikon arka planını biraz yumuşattık
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}
