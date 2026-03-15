import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart'; // YENİ: Açılış ekranımızı içeri aktardık

void main() async {
  // Flutter motorunun ve Firebase'in doğru başlatıldığından emin oluyoruz
  WidgetsFlutterBinding.ensureInitialized();
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
