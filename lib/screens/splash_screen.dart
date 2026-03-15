import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import 'auth_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // --- LOGO ANİMASYONU ---
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Yaylanma efekti (ElasticOut) ile ikonun ekrana tatlı bir şekilde gelmesini sağlıyoruz
    _animation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    // --- YÖNLENDİRME (3 Saniye Sonra) ---
    Timer(const Duration(seconds: 3), () {
      final user = FirebaseAuth.instance.currentUser;

      // Kullanıcı zaten giriş yapmışsa direkt Dashboard'a, yapmamışsa Giriş ekranına atıyoruz
      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- ARKA PLAN (Aura Efekti) ---
          Container(color: const Color(0xFFF8FAFF)),
          Positioned(
            top: -100,
            left: -100,
            child: _buildAuraCircle(Colors.deepPurple.withOpacity(0.15), 400),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: _buildAuraCircle(Colors.blue.withOpacity(0.15), 400),
          ),

          // --- ANA İÇERİK ---
          Center(
            child: ScaleTransition(
              scale: _animation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Eğitim Temalı İkon (Mezuniyet Kepi)
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.2),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.school_rounded, // Eğitim ikonu
                      color: Color(0xFF1A1A2E), // Şık koyu lacivert
                      size: 90,
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Uygulama Adı
                  const Text(
                    "İngilizce Destek",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1A1A2E),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Alt Başlık
                  const Text(
                    "Öğrenmeye Hazır Mısın?",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Yükleniyor Animasyonu
                  const CircularProgressIndicator(
                    color: Colors.deepPurple,
                    strokeWidth: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Arka plandaki bulanık renk bulutlarını oluşturan fonksiyon
  Widget _buildAuraCircle(Color color, double size) {
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
}
