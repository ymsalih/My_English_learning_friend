import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🚀 YENİ
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/subscription_service.dart';

// Uygulamanın her yerinden erişebileceğimiz global kamera listesi
// 🚀 YENİ: İçini açılışta değil, kullanıcı kameraya tıkladığında dolduracağız!
List<CameraDescription> cameras = [];

void main() async {
  // Flutter motorunun doğru başlatıldığından emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();

  // .env dosyasını yüklüyoruz (Gemini API vb. için)
  await dotenv.load(fileName: ".env");

  // Firebase'i başlatıyoruz
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // RevenueCat'i Başlatıyoruz
  try {
    await Purchases.setLogLevel(LogLevel.debug);
    PurchasesConfiguration? configuration;
    
    if (Platform.isAndroid) {
      final androidKey = dotenv.env['REVENUECAT_ANDROID_KEY'];
      if (androidKey != null && androidKey.trim().isNotEmpty) {
        configuration = PurchasesConfiguration(androidKey);
      }
    } else if (Platform.isIOS) {
      final iosKey = dotenv.env['REVENUECAT_IOS_KEY'];
      if (iosKey != null && iosKey.trim().isNotEmpty && iosKey != 'BURAYA_APPLE_API_KEY_GELECEK') {
        configuration = PurchasesConfiguration(iosKey);
      }
    }
    
    if (configuration != null) {
      await Purchases.configure(configuration);
    } else {
      debugPrint("⚠️ RevenueCat API Anahtarı eksik veya geçersiz, ödeme sistemi başlatılamadı.");
    }
  } catch (e) {
    debugPrint("⚠️ RevenueCat Başlatma Hatası: $e");
  }
  
  SubscriptionService().setupRevenueCatListener();

  runApp(const IngilizceDestekApp());
}

class IngilizceDestekApp extends StatelessWidget {
  const IngilizceDestekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Owlish',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
