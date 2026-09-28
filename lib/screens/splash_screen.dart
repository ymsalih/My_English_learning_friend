import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/subscription_service.dart';
import 'dashboard_screen.dart';
import 'landing_screen.dart';
import 'octopus_scene_painter.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // octopus-english-splash.html zaman çizelgesi (saniye)
  static const double _animationEnd = 4.6;
  static const double _wordStart = 3.3;
  static const double _wordDuration = 0.8;

  final OctopusScene _scene = OctopusScene();
  final ValueNotifier<double> _time = ValueNotifier<double>(0);
  final ValueNotifier<double> _wordProgress = ValueNotifier<double>(0);
  late final Ticker _ticker;
  late final Future<bool> _networkTask;
  bool _flowStarted = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);

    _networkTask = () async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await Purchases.logIn(user.uid);
          await SubscriptionService().syncRevenueCatStatus();
        } catch (e) {
          debugPrint("RevenueCat LogIn Error: $e");
        }
      }
      return user != null;
    }().timeout(const Duration(seconds: 3), onTimeout: () {
      debugPrint("RevenueCat Splash Sync Timed Out");
      return FirebaseAuth.instance.currentUser != null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_flowStarted) return;
    _flowStarted = true;

    // Animasyon ve açılış işleri paralel çalışır; ikisi de bitince geçilir.
    final Future<void> minimumDelay;
    if (MediaQuery.disableAnimationsOf(context)) {
      _time.value = _animationEnd;
      _wordProgress.value = 1;
      minimumDelay = Future<void>.value();
    } else {
      _ticker.start();
      minimumDelay = Future.delayed(
        Duration(milliseconds: (_animationEnd * 1000).round()),
      );
    }

    Future.wait([minimumDelay, _networkTask]).then((results) {
      if (!mounted) return;
      final isLoggedIn = results[1] as bool;
      if (isLoggedIn) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const DashboardScreen(),
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, _, _) => const LandingScreen(),
            transitionDuration: const Duration(milliseconds: 600),
            transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      }
    });
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    _time.value = t;
    final word = ((t - _wordStart) / _wordDuration).clamp(0.0, 1.0);
    if (word != _wordProgress.value) _wordProgress.value = word;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _wordProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1540),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final unit = OctopusScene.unitFor(size);
          // Referans sahne 390x844; yazı ahtapotla aynı oranda ölçeklenir ve
          // ahtapotun son konumuna göre yerleşir (390x844'te top = 548px).
          final scale = unit / OctopusScene.referenceUnit;
          final wordTop = size.height * 0.44 + (548 - 844 * 0.44) * scale;

          return Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: Semantics(
                    label: 'Ahtapot ekrana doğru yüzüp kollarıyla O harfi oluşturuyor',
                    child: CustomPaint(
                      painter: OctopusScenePainter(
                        scene: _scene,
                        time: _time,
                        devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: wordTop,
                child: ValueListenableBuilder<double>(
                  valueListenable: _wordProgress,
                  child: _Wordmark(scale: scale),
                  builder: (context, progress, child) {
                    // CSS: fadeup .8s ease-out 3.3s (opacity 0 -> 1, translateY 14px -> 0)
                    final e = Curves.easeOut.transform(progress);
                    return Opacity(
                      opacity: e,
                      child: Transform.translate(
                        offset: Offset(0, 14 * scale * (1 - e)),
                        child: child,
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Octopus',
          textScaler: TextScaler.noScaling,
          style: GoogleFonts.fredoka(
            fontSize: 44 * scale,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF4F1FF),
            letterSpacing: -0.5 * scale,
            height: 1,
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          'ENGLISH',
          textScaler: TextScaler.noScaling,
          style: GoogleFonts.fredoka(
            fontSize: 23 * scale,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF9FB2FF),
            letterSpacing: 8 * scale,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
