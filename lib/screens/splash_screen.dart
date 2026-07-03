import 'dart:async';
import 'dart:ui';
import 'dart:math';
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
  bool _visible = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();

    // Hafıza Optimizasyonu (Performans): Logo resmini önbelleğe alıyoruz
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(const AssetImage('assets/logo.png'), context);
    });

    // Yörünge Hareketi için Animasyon Kontrolcüsü (Sonsuz Döner)
    // Performans için donanım hızlandırmalı
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 4,
      ), // Bir tam tur süresi (Yavaş ve zarif)
    )..repeat();

    // Tetikleyici: Animasyonların donanım hızlandırmalı başlaması için
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _visible = true;
        });
      }
    });

    // SIFIR PERFORMANS KAYBI: Tam 1.5 saniyede yönlendirme (Eskiyle aynı süre)
    Timer(const Duration(milliseconds: 1500), () {
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      if (user != null) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const DashboardScreen(),
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const LandingScreen(),
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (_, a, __, c) =>
                FadeTransition(opacity: a, child: c),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Uzay karanlığı
      body: Stack(
        alignment: Alignment.center,
        children: [
          // ZARİF ARKA PLAN PARLAMASI (GPU ile çizilir, kasmayı sıfırlar)
          AnimatedOpacity(
            opacity: _visible ? 1.0 : 0.0,
            duration: const Duration(seconds: 1),
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.deepPurpleAccent.withOpacity(0.2),
                    const Color(0xFF0F172A),
                  ],
                  radius: 1.5,
                ),
              ),
            ),
          ),

          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // LOGO VE DÖNEN HALKALAR (Hologram Efekti)
              AnimatedScale(
                scale: _visible ? 1.0 : 0.5,
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                child: AnimatedOpacity(
                  opacity: _visible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 400),
                  child: SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // DÖNEN IŞIKLI HALKALAR VE GEZEGENLER (Sıfır kasma, native çizim)
                        RotationTransition(
                          turns: _rotationController,
                          child: SizedBox(
                            width: 190,
                            height: 190,
                            child: CustomPaint(painter: NeonRingPainter()),
                          ),
                        ),
                        // BAYKUŞ (Merkezde sabit)
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.15),
                                blurRadius: 40,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // İSİM - ZARİF BELİRME
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeIn,
                child: const Text(
                  "Owlish",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ALT BAŞLIK
              AnimatedOpacity(
                opacity: _visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeIn,
                child: Text(
                  "Premium Öğrenim Deneyimi",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          // APPLE TARZI MİNİMALİST YÜKLEME ÇUBUĞU (En Altta)
          Positioned(
            bottom: 80,
            child: AnimatedOpacity(
              opacity: _visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: Column(
                children: [
                  Container(
                    width: 200,
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 200.0),
                        duration: const Duration(milliseconds: 1400),
                        curve: Curves.easeInOut,
                        builder: (context, value, child) {
                          return Container(
                            width: value,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(color: Colors.white, blurRadius: 10),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================== //
// NEON HALKA VE GEZEGEN ÇİZİM MOTORU (Custom Painter)
// Performans: Maksimum (İşletim sistemi grafikleriyle çizilir)
// ========================================================== //
class NeonRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Neon Çizgi Fırçası
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [Colors.purpleAccent, Colors.cyanAccent, Colors.purpleAccent],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Parlama Efekti Fırçası (Arkada bulanık)
    final Paint glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..shader = ringPaint.shader;

    // 1. Uzun Yay (Sol ve Üst)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      pi * 1.2,
      false,
      glowPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      pi * 1.2,
      false,
      ringPaint,
    );

    // 2. Kısa Yay (Sağ Alt)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 1.4,
      pi * 0.4,
      false,
      glowPaint,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi * 1.4,
      pi * 0.4,
      false,
      ringPaint,
    );

    // Yörüngedeki Gezegenler (Noktalar)
    final Paint planet1Glow = Paint()
      ..color = Colors.purpleAccent
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4);

    final Paint planet2Glow = Paint()
      ..color = Colors.cyanAccent
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 5);

    // Büyük Nokta (Boşlukta)
    final p1 = Offset(
      center.dx + radius * cos(pi * 1.3),
      center.dy + radius * sin(pi * 1.3),
    );
    canvas.drawCircle(p1, 8.0, planet1Glow);

    // Küçük Nokta (Yayın uçlarında)
    final p2 = Offset(
      center.dx + radius * cos(pi * 0.8),
      center.dy + radius * sin(pi * 0.8),
    );
    canvas.drawCircle(p2, 5.0, planet2Glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
