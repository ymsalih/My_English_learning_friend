import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart'; // YENİ: Firestore'dan isim çekmek için eklendi
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

// Sayfamızı dinamik (Stateful) hale getirdik
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Başlangıç değerleri (Veritabanından isim gelene kadar görünecekler)
  String _userName = "Öğrenci";
  String _userInitial = "Ö";

  @override
  void initState() {
    super.initState();
    _fetchUserName(); // Sayfa açıldığında ismi çek
  }

  // --- YENİ: FIRESTORE'DAN GERÇEK KULLANICI ADINI ÇEKME ---
  Future<void> _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // 'users' koleksiyonundan bu kullanıcının belgesini al
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          final data = userDoc.data() as Map<String, dynamic>;
          if (data.containsKey('username')) {
            String dbName = data['username'];
            if (dbName.isNotEmpty) {
              setState(() {
                // İsmin ilk harfini büyük yap
                _userName = dbName[0].toUpperCase() + dbName.substring(1);
                _userInitial = dbName[0].toUpperCase();
              });
              return; // İsim başarıyla alındıysa fonksiyondan çık
            }
          }
        }
      } catch (e) {
        debugPrint("İsim çekilirken hata oluştu: $e");
      }

      // Eğer veritabanında isim yoksa veya hata çıkarsa yedeğe (maile) dön
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
    // ⚠️ DİKKAT: Kendi mailini buraya yaz
    const String myEmail = 'seninmailin@gmail.com';
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
              // Artık state içindeki _userName ve _userInitial değerlerini kullanıyoruz
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

                  // Panelin içine de veritabanından gelen _userName'i gönderiyoruz
                  _buildUserPanel(_userName),

                  const SizedBox(height: 30),
                  const Text(
                    "Eğitim Menüsü",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
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
                    colors: [
                      Colors.blueAccent.shade700,
                      Colors.lightBlue.shade400,
                    ],
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
                const Text(
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
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        ),
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
                color: Colors.white24,
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
