import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart'; // 🚀 YENİ: Kamera kontrol kütüphanesi
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

// 🚀 YENİ: Uygulamanın her yerinden erişebileceğimiz global kamera listesi
List<CameraDescription> cameras = [];

void main() async {
  // Flutter motorunun doğru başlatıldığından emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 YENİ: Cihazdaki kameraları tespit ediyoruz
  try {
    cameras = await availableCameras();
  } catch (e) {
    debugPrint("Kameralar alınırken hata oluştu: $e");
  }

  // Firebase'i başlatıyoruz
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
