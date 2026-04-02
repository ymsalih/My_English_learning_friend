import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  late AnimationController _animationController;
  late Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _floatAnimation =
        Tween<Offset>(
          begin: const Offset(0, -0.05),
          end: const Offset(0, 0.05),
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // --- ŞİFRE SIFIRLAMA DİALOGU (TÜRKÇELEŞTİRİLMİŞ) ---
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Şifre Sıfırlama"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Kayıtlı e-posta adresinizi girin, size şifre sıfırlama bağlantısı gönderelim.",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            _buildTextField(
              controller: resetEmailController,
              label: 'E-posta',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İptal", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            onPressed: () async {
              String email = resetEmailController.text.trim();
              if (email.isEmpty) return;

              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Sıfırlama bağlantısı gönderildi. Lütfen mail kutunuzu kontrol edin.",
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on FirebaseAuthException catch (e) {
                String errorMsg = "E-posta gönderilemedi.";
                if (e.code == 'user-not-found') {
                  errorMsg =
                      "Bu e-posta adresine kayıtlı bir hesap bulunamadı.";
                } else if (e.code == 'invalid-email') {
                  errorMsg = "Lütfen geçerli bir e-posta adresi girin.";
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text("Gönder", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        UserCredential userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        User? user = userCredential.user;

        if (user != null && !user.emailVerified) {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Lütfen giriş yapmadan önce e-posta adresinizi doğrulayın.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.orange.shade800,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        String username = _usernameController.text.trim();
        if (username.isEmpty || username.length < 3) {
          throw FirebaseAuthException(
            code: 'invalid-username',
            message: 'Lütfen en az 3 karakterli bir kullanıcı adı belirleyin.',
          );
        }

        if (_passwordController.text != _confirmPasswordController.text) {
          throw FirebaseAuthException(
            code: 'password-mismatch',
            message: 'Şifreler birbiriyle eşleşmiyor.',
          );
        }

        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text.trim(),
            );

        User? user = userCredential.user;
        if (user != null) {
          await user.sendEmailVerification();

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'username': username,
                'email': _emailController.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
              });

          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: const Text("Kayıt Başarılı! 🎉"),
                content: const Text(
                  "Hesabınız başarıyla oluşturuldu. Giriş yapabilmek için e-posta adresinize gönderilen doğrulama linkine tıklamanız gerekmektedir.",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _isLogin = true;
                        _passwordController.clear();
                        _confirmPasswordController.clear();
                      });
                    },
                    child: const Text("Anladım"),
                  ),
                ],
              ),
            );
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Bir sorun oluştu, lütfen tekrar deneyin.';
      switch (e.code) {
        case 'invalid-credential':
          message = 'E-posta veya şifre hatalı. Lütfen kontrol edin.';
          break;
        case 'user-not-found':
          message = 'Bu e-posta adresine kayıtlı bir hesap bulunamadı.';
          break;
        case 'wrong-password':
          message = 'Girdiğiniz şifre hatalı.';
          break;
        case 'invalid-email':
          message = 'Lütfen geçerli bir e-posta adresi yazın.';
          break;
        case 'email-already-in-use':
          message = 'Bu e-posta adresi zaten kullanımda.';
          break;
        case 'weak-password':
          message = 'Şifreniz çok zayıf. Lütfen daha güçlü bir şifre seçin.';
          break;
        case 'too-many-requests':
          message =
              'Çok fazla hatalı deneme yaptınız. Lütfen sonra tekrar deneyin.';
          break;
        case 'invalid-username':
        case 'password-mismatch':
          message = e.message ?? 'Eksik veya hatalı bilgi girdiniz.';
          break;
        case 'network-request-failed':
          message = 'İnternet bağlantınızı kontrol edin.';
          break;
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
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  children: [
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
                              if (!_isLogin) ...[
                                _buildTextField(
                                  controller: _usernameController,
                                  label: 'Kullanıcı Adı',
                                  icon: Icons.person_outline_rounded,
                                ),
                                const SizedBox(height: 15),
                              ],
                              _buildTextField(
                                controller: _emailController,
                                label: 'E-posta',
                                icon: Icons.alternate_email_rounded,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 15),
                              _buildPasswordField(
                                controller: _passwordController,
                                label: 'Şifre',
                                isVisible: _isPasswordVisible,
                                onVisibilityChanged: () {
                                  setState(
                                    () => _isPasswordVisible =
                                        !_isPasswordVisible,
                                  );
                                },
                              ),

                              if (_isLogin)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    child: const Text(
                                      "Şifremi unuttum",
                                      style: TextStyle(
                                        color: Colors.deepPurple,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                              if (!_isLogin) ...[
                                const SizedBox(height: 15),
                                _buildPasswordField(
                                  controller: _confirmPasswordController,
                                  label: 'Şifreyi Onayla',
                                  isVisible: _isConfirmPasswordVisible,
                                  onVisibilityChanged: () {
                                    setState(
                                      () => _isConfirmPasswordVisible =
                                          !_isConfirmPasswordVisible,
                                    );
                                  },
                                ),
                                // 🔥 YENİ: KAYIT BİLGİLENDİRME METNİ
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  child: Text(
                                    "Şifrenizi belirledikten sonra onay e-postasındaki linkten kaydı onaylayıp giriş yapabilirsiniz.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54.withOpacity(0.6),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.deepPurple,
                                    )
                                  : _buildSubmitButton(),
                              const SizedBox(height: 15),
                              TextButton(
                                onPressed: () {
                                  _usernameController.clear();
                                  _emailController.clear();
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
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
      child: ClipOval(child: Image.asset('assets/logo.png', fit: BoxFit.cover)),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onVisibilityChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: Colors.deepPurple.shade300,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: Colors.grey.shade600,
          ),
          onPressed: onVisibilityChanged,
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
