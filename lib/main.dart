import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart'; // Az önce yazdığımız sayfayı buraya çağırdık

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const IngilizceDestekApp());
}

class IngilizceDestekApp extends StatelessWidget {
  const IngilizceDestekApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'İngilizce Havuzum',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // StreamBuilder: Kullanıcının giriş yapıp yapmadığını anlık olarak dinler
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // Eğer snapshot içinde veri varsa, yani kullanıcı giriş yapmışsa
          if (snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(title: const Text('Ana Sayfa')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Harika! Giriş Başarılı 🎉\nAdım 8: Kelime Havuzu Buraya Gelecek!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Şimdilik test edebilmen için bir Çıkış Yap butonu koydum
                    ElevatedButton(
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: const Text('Çıkış Yap'),
                    ),
                  ],
                ),
              ),
            );
          }
          // Eğer giriş yapmamışsa Giriş ekranını (AuthScreen) göster
          return const AuthScreen();
        },
      ),
    );
  }
}
