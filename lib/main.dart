import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // YENİ: .env kasamızı açmak için gerekli kütüphane
import 'firebase_options.dart';
import 'screens/splash_screen.dart'; // Açılış ekranımızı içeri aktardık

void main() async {
  // Flutter motorunun doğru başlatıldığından emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();

  // 🚀 YENİ: Uygulama ve Firebase ayağa kalkmadan hemen önce gizli kasamızı (.env) yüklüyoruz
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
      title: 'İngilizce Destek',
      debugShowCheckedModeBanner: false, // Sağ üstteki "DEBUG" bandını gizler
      theme: ThemeData(
        // Uygulamanın genel renk paletini ana temamız olan derin mora ayarlıyoruz
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // UYGULAMA ARTIK DİREKT AÇILIŞ EKRANIYLA BAŞLIYOR!
      // (Giriş kontrolü ve sayfa yönlendirmesi SplashScreen'in içinde yapılıyor)
      home: const SplashScreen(),
    );
  }
}
