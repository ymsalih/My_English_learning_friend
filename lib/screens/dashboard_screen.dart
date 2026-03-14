import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'test_screen.dart';
import 'translation_screen.dart';
import 'video_practice_screen.dart';
import 'word_learning_screen.dart'; // YENİ EKLENDİ (API Sayfası)

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('İngilizce Öğreniyorum'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
            tooltip: 'Çıkış Yap',
          ),
        ],
      ),
      // BODY kısmında kayma (taşma) sorununu çözmek için ayarlamalar yapıldı
      body: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: SingleChildScrollView(
          // Alttan ekstra padding vererek butonların ekrana yapışmasını engelledik
          padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60), // En üste biraz nefes payı
              // 1. KELİME HAVUZUM
              _buildMenuButton(
                context,
                title: 'Kelime Havuzum',
                icon: Icons.library_books,
                color: Colors.blue.shade700,
                destination: const HomeScreen(),
              ),
              const SizedBox(height: 30), // Boşluklar hafif artırıldı
              // 2. KENDİNİ TEST ET
              _buildMenuButton(
                context,
                title: 'Kendini Test Et',
                icon: Icons.style,
                color: Colors.deepPurpleAccent,
                destination: const TestScreen(),
              ),
              const SizedBox(height: 30),

              // 3. AKILLI ÇEVİRİ
              _buildMenuButton(
                context,
                title: 'Akıllı Çeviri',
                icon: Icons.g_translate,
                color: Colors.teal,
                destination: const TranslationScreen(),
              ),
              const SizedBox(height: 30),

              // 5. KELİME PAKETLERİ (GitHub API) - YENİ
              _buildMenuButton(
                context,
                title: 'Kelime Paketleri ',
                icon: Icons.school,
                color: Colors.orange.shade800,
                destination: const WordLearningScreen(),
              ),
              const SizedBox(height: 20), // En alta kaydırma payı
              // 4. VİDEO PRATİK (YouTube)
              _buildMenuButton(
                context,
                title: 'Video Pratik',
                icon: Icons.ondemand_video,
                color: Colors.redAccent,
                destination: const VideoPracticeScreen(),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // Buton karmaşasını önlemek için yardımcı bir tasarım fonksiyonu
  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required Widget destination,
  }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 28),
      label: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 70),
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => destination),
        );
      },
    );
  }
}
