import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dashboard_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  late AnimationController _animationController;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // --- SÜREKLİ SÜZÜLME (FLOATING) ANİMASYONU ---
    _animationController = AnimationController(
      duration: const Duration(seconds: 2), // İnip çıkma hızı
      vsync: this,
    )..repeat(reverse: true); // Sonsuza kadar aşağı-yukarı tekrar et

    _floatAnimation =
        Tween<Offset>(
          begin: const Offset(0, -0.05), // Hafif yukarıdan başla
          end: const Offset(0, 0.05), // Hafif aşağı in
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut, // Yumuşak bir geçiş sağla
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const DashboardScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Bir hata oluştu.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        message = 'E-posta veya şifre hatalı.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Bu e-posta zaten kullanımda.';
      } else if (e.code == 'invalid-email') {
        message = 'Geçerli bir e-posta adresi giriniz.';
      } else if (e.code == 'weak-password') {
        message = 'Şifreniz çok zayıf. En az 6 karakter olmalı.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // --- 1. DİNAMİK ARKA PLAN (AURA EFFECT) ---
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

          // --- 2. ANA İÇERİK ---
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  children: [
                    // --- ANİMASYONLU LOGO ALANI (BAYKUŞ) ---
                    SlideTransition(
                      position: _floatAnimation,
                      child: _buildHeroLogo(),
                    ),
                    const SizedBox(height: 30),

                    const Text(
                      'İngilizce Arkadaşım',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Kelimelerin dünyasına yolculuk başlasın.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black45, fontSize: 16),
                    ),
                    const SizedBox(height: 40),

                    // GLASSMORPHISM CARD (Giriş Formu)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(25),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                _isLogin
                                    ? 'Hoş Geldin! 👋'
                                    : 'Aramıza Katıl 💕',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              const SizedBox(height: 25),

                              // E-POSTA ALANI
                              _buildTextField(
                                controller: _emailController,
                                label: 'E-posta',
                                icon: Icons.alternate_email_rounded,
                              ),
                              const SizedBox(height: 15),

                              // ŞİFRE ALANI
                              _buildPasswordField(),

                              const SizedBox(height: 30),

                              // ANA BUTON
                              _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.deepPurple,
                                    )
                                  : _buildSubmitButton(),

                              const SizedBox(height: 15),

                              // MOD DEĞİŞTİRİCİ
                              TextButton(
                                onPressed: () {
                                  _emailController.clear();
                                  _passwordController.clear();
                                  setState(() => _isLogin = !_isLogin);
                                },
                                child: Text(
                                  _isLogin
                                      ? 'Yeni kayıt oluştur'
                                      : 'Zaten hesabım var, Giriş yap',
                                  style: const TextStyle(
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- YARDIMCI WIDGET'LAR ---

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

  // EĞİTİM LOGOSU (Baykuş İkonu)
  Widget _buildHeroLogo() {
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.2),
            blurRadius: 30,
            spreadRadius: 10,
          ),
        ],
      ),
      child: ClipOval(
        child: Transform.scale(
          scale: 1.0,
          child: Image.asset('assets/logo.png', fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepPurple.shade300),
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.deepPurple.withOpacity(0.1)),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: 'Şifre',
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: Colors.deepPurple.shade300,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: Colors.grey.shade600,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.deepPurple.withOpacity(0.1)),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Colors.deepPurple, Colors.blueAccent],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          _isLogin ? 'Giriş Yap' : 'Kayıt Ol',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
