import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true; // Uygulama ilk açıldığında 'Giriş Yap' modunda başlar

  Future<void> _submit() async {
    try {
      if (_isLogin) {
        // Giriş Yapma İşlemi
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        // Yeni Kayıt Olma İşlemi
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
    } catch (e) {
      // Hata olursa ekranda alt kısımda uyarı mesajı (SnackBar) gösteririz
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Hata: ${e.toString()}")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-posta',
                border:
                    OutlineInputBorder(), // Kutulara şık bir çerçeve ekledik
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              obscureText: true, // Şifreyi yıldızlı gösterir
              decoration: const InputDecoration(
                labelText: 'Şifre (En az 6 haneli)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(
                  double.infinity,
                  50,
                ), // Butonu tam ekran genişliği yapar
              ),
              child: Text(
                _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin =
                      !_isLogin; // Tıklandığında giriş/kayıt modunu değiştirir
                });
              },
              child: Text(
                _isLogin
                    ? 'Hesabın yok mu? Yeni Kayıt Oluştur'
                    : 'Zaten hesabın var mı? Giriş Yap',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
