import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🚀 YENİ
import 'firebase_options.dart';
import 'screens/splash_screen.dart';

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
