import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'test_screen.dart';
import 'translation_screen.dart';
import 'video_practice_screen.dart';
import 'word_learning_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Firebase'den güncel kullanıcıyı alıyoruz
    final user = FirebaseAuth.instance.currentUser;
    // İsim varsa ismi, yoksa e-postanın baş kısmını alıyoruz
    final String rawName =
        user?.displayName ?? user?.email?.split('@')[0] ?? "Öğrenci";
    // İsmin baş harfini büyük yapıyoruz
    final String userName = rawName[0].toUpperCase() + rawName.substring(1);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'İngilizce Destek',
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      body: Stack(
        children: [
          // --- 1. YARATICI ARKA PLAN (SOFT GRADIENT) ---
          Container(color: const Color(0xFFF0F4F8)),
          Positioned(
            top: -50,
            right: -50,
            child: _buildBlurCircle(Colors.blue.withOpacity(0.2), 300),
          ),
          Positioned(
            bottom: 100,
            left: -100,
            child: _buildBlurCircle(Colors.purple.withOpacity(0.1), 400),
          ),

          // --- 2. ANA İÇERİK ---
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    "Merhaba 👋",
                    style: const TextStyle(
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

                  // --- 3. ŞİMŞEK İKONLU KULLANICI PANELİ ---
                  _buildUserPanel(userName),

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

                  // --- 4. MODERN GRADIENT BUTONLAR ---
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
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Şimşek İkonlu Yeni Kullanıcı Paneli
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
          // Şık Şimşek İkonu
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
