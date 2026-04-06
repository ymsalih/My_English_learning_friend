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

// SingleTickerProviderStateMixin animasyonları yönetmemizi sağlar
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // --- SÜREKLİ SÜZÜLME (FLOATING) ANİMASYONU ---
    _controller =
        AnimationController(
          duration: const Duration(seconds: 2), // Yukarıdan aşağı inme süresi
          vsync: this,
        )..repeat(
          reverse: true,
        ); // repeat(reverse: true) ile sürekli aşağı yukarı hareket eder!

    // Baykuşun Y ekseninde (yukarı-aşağı) ne kadar hareket edeceğini belirliyoruz
    _floatAnimation =
        Tween<Offset>(
          begin: const Offset(0, -0.05), // Biraz yukarıda başla
          end: const Offset(0, 0.05), // Biraz aşağı in
        ).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeInOut, // Yumuşak bir ivmelenme sağlar
          ),
        );

    // --- YÖNLENDİRME (4 Saniye Sonra) ---
    Timer(const Duration(seconds: 4), () {
      final user = FirebaseAuth.instance.currentUser;

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
    _controller.dispose(); // Animasyonu hafızadan temizle
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- 1. DİNAMİK ARKA PLAN (Aura Efekti) ---
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

          // --- 2. ANA İÇERİK (Tam Ekran Hissiyatı) ---
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // --- CANLI BAYKUŞ ANİMASYONU ---
                SlideTransition(
                  position:
                      _floatAnimation, // Hazırladığımız süzülme animasyonunu buraya bağladık
                  child: Container(
                    width: 180, // Baykuşu biraz daha büyüttük
                    height: 180,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.deepPurple.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 10,
                          offset: const Offset(
                            0,
                            10,
                          ), // Gölgeyi biraz aşağı kaydırdık
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Transform.scale(
                        scale:
                            1.1, // Dairenin içini tam doldurması için hafif zoom
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // --- UYGULAMA ADI ---
                const Text(
                  "İngilizce Arkadaşım",
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1A1A2E),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 10),

                // --- ALT BAŞLIK ---
                const Text(
                  "Kelimelerin dünyasına yolculuk başlasın.",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // --- 3. YÜKLENİYOR İNDİKATÖRÜ ---
          const Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: CircularProgressIndicator(
                color: Colors.deepPurple,
                strokeWidth: 3,
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
