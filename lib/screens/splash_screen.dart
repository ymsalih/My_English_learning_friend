import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dashboard_screen.dart';
import 'landing_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // --- SÜREKLİ SÜZÜLME (FLOATING) ANİMASYONU ---
    _controller = AnimationController(
      duration: const Duration(seconds: 2), // Yukarıdan aşağı inme süresi
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, -0.05), // Biraz yukarıda başla
      end: const Offset(0, 0.05), // Biraz aşağı in
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // --- YÖNLENDİRME (1.5 Saniye Sonra) ---
    Timer(const Duration(milliseconds: 1500), () {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LandingScreen()),
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
      backgroundColor: const Color(0xFF0F172A), // Dark Space Background
      body: Stack(
        children: [
          // --- 1. DİNAMİK ARKA PLAN (Karanlık Aura Efekti) ---
          Positioned(
            top: -100,
            left: -100,
            child: _buildAuraCircle(Colors.purpleAccent.withOpacity(0.15), 400),
          ),
          Positioned(
            bottom: -50,
            right: -100,
            child: _buildAuraCircle(Colors.blueAccent.withOpacity(0.15), 400),
          ),

          // --- 2. ANA İÇERİK ---
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- CANLI BAYKUŞ (Neon Cam Efekti) ---
                SlideTransition(
                  position: _floatAnimation,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05), // Glass background
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purpleAccent.withOpacity(0.3),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: Colors.blueAccent.withOpacity(0.2),
                          blurRadius: 60,
                          spreadRadius: -10,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Transform.scale(
                          scale: 1.15,
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // --- UYGULAMA ADI (Neon Parlama) ---
                Text(
                  "İngilizce Arkadaşım",
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                    shadows: [
                      Shadow(
                        color: Colors.purpleAccent.withOpacity(0.8),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),

                // --- ALT BAŞLIK ---
                Text(
                  "Kelimelerin dünyasına yolculuk başlasın.",
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // --- 3. YÜKLENİYOR İNDİKATÖRÜ (Modern) ---
          Positioned(
            bottom: 70,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Colors.purpleAccent,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "Yükleniyor...",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
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
    );
  }
}
