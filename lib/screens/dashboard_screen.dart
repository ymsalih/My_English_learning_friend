import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'test_screen.dart';
import 'translation_screen.dart';
import 'video_practice_screen.dart'; // YENİ EKLENDİ

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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. KELİME HAVUZU BUTONU
              ElevatedButton.icon(
                icon: const Icon(Icons.library_books, size: 30),
                label: const Text(
                  'Kelime Havuzum',
                  style: TextStyle(fontSize: 20),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 80),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),

              // 2. KENDİMİ TEST ET BUTONU
              ElevatedButton.icon(
                icon: const Icon(Icons.style, size: 30),
                label: const Text(
                  'Kendini Test Et',
                  style: TextStyle(fontSize: 20),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 80),
                  backgroundColor: Colors.deepPurpleAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TestScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),

              // 3. AKILLI ÇEVİRİ BUTONU
              ElevatedButton.icon(
                icon: const Icon(Icons.g_translate, size: 30),
                label: const Text(
                  'Akıllı Çeviri',
                  style: TextStyle(fontSize: 20),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 80),
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TranslationScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // 4. VİDEO PRATİK BUTONU (YENİ)
              ElevatedButton.icon(
                icon: const Icon(Icons.ondemand_video, size: 30),
                label: const Text(
                  'Video Pratik',
                  style: TextStyle(fontSize: 20),
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 80),
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const VideoPracticeScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
