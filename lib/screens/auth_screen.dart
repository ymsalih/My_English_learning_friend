import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dashboard_screen.dart';
import 'landing_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class AuthScreen extends StatefulWidget {
  final bool initialLoginMode;
  
  const AuthScreen({super.key, this.initialLoginMode = true});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late bool _isLogin;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  late AnimationController _floatingController;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.initialLoginMode;
    // Pürüzsüz ve sıfır işlemci yüküyle çalışan süzülme (hover) animasyonu
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingController.dispose();
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
        backgroundColor: AppColors.surface, // Koyu arka plan
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25), side: BorderSide(color: Colors.white.withOpacity(0.1))),
        title: const Text("Şifre Sıfırlama", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Kayıtlı e-posta adresinizi girin, size şifre sıfırlama bağlantısı gönderelim.",
              style: TextStyle(fontSize: 14, color: Colors.white70),
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
            child: const Text("İptal", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
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
                      backgroundColor: AppColors.successFill,
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
                      backgroundColor: AppColors.dangerFill,
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

        if (user != null) {
          try {
            await Purchases.logIn(user.uid);
          } catch (e) {
            debugPrint("RevenueCat LogIn Error: $e");
          }
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

          final todayStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'username': username,
                'displayName': username,
                'email': _emailController.text.trim(),
                'createdAt': FieldValue.serverTimestamp(),
                'subscriptionPlan': 'basic',
                'lifetimeWordsAdded': 0,
                'dailyUsage': {
                  'date': todayStr,
                  'storyGenCount': 0,
                  'storyReadCount': 0,
                  'chatMsgCount': 0,
                  'translateCount': 0,
                  'testCount': 0,
                },
                'level': 'A1',
                'streak': 0,
                'photoURL': '',
                'lastActive': FieldValue.serverTimestamp(),
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
                  "Hesabınız başarıyla oluşturuldu. Giriş yapabilmek için e-posta adresinize gönderilen doğrulama linkine tıklamanız gerekmektedir.\n\nEğer e-postayı göremiyorsanız lütfen Spam (Gereksiz) kutunuzu kontrol etmeyi unutmayın.",
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
            backgroundColor: AppColors.dangerFill,
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

  // --- GOOGLE İLE GİRİŞ YAP ---
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return; // Kullanıcı girişi iptal etti
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Kullanıcı Firestore'da var mı kontrol et
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          // Yeni kullanıcı: Adını Google'dan al ve veritabanını oluştur
          final displayName = user.displayName ?? "Kullanıcı";
          final todayStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
          
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'username': displayName,
            'displayName': displayName,
            'email': user.email ?? "",
            'createdAt': FieldValue.serverTimestamp(),
            'subscriptionPlan': 'basic',
            'lifetimeWordsAdded': 0,
            'dailyUsage': {
              'date': todayStr,
              'storyGenCount': 0,
              'storyReadCount': 0,
              'chatMsgCount': 0,
              'translateCount': 0,
              'testCount': 0,
            },
            'level': 'A1',
            'streak': 0,
            'photoURL': user.photoURL ?? "",
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
        
        // RevenueCat Girişi (Satın alımları eşitlemek için)
        try {
          await Purchases.logIn(user.uid);
        } catch (e) {
          debugPrint("RevenueCat LogIn Error: $e");
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Google ile giriş başarısız oldu: ${e.message}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.dangerFill,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Giriş iptal edildi veya bir sorun oluştu.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: AppColors.goldFill,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setMode(bool login) {
    if (login == _isLogin) return;
    _usernameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    setState(() => _isLogin = login);
  }

  void _backToLanding() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => const LandingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, AppSpacing.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _backToLanding,
                        icon: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.textMuted),
                        label: const Text('Tanıtım', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    ),
                    _buildHeroLogo(),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Octopus English', textAlign: TextAlign.center, style: AppText.display(size: 30)),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Kelimelerin dünyasına yolculuk başlasın.',
                      textAlign: TextAlign.center,
                      style: AppText.body,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildModeToggle(),
                    const SizedBox(height: AppSpacing.xl),
                    if (!_isLogin) ...[
                      _buildTextField(
                        controller: _usernameController,
                        label: 'Kullanıcı Adı',
                        icon: Icons.person_outline_rounded,
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    _buildTextField(
                      controller: _emailController,
                      label: 'E-posta',
                      icon: Icons.alternate_email_rounded,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildPasswordField(
                      controller: _passwordController,
                      label: 'Şifre',
                      isVisible: _isPasswordVisible,
                      onVisibilityChanged: () {
                        setState(() => _isPasswordVisible = !_isPasswordVisible);
                      },
                    ),
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text("Şifremi unuttum", style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    if (!_isLogin) ...[
                      const SizedBox(height: AppSpacing.md),
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: 'Şifreyi Onayla',
                        isVisible: _isConfirmPasswordVisible,
                        onVisibilityChanged: () {
                          setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        "Kayıttan sonra e-postana gelen onay linkine tıklayarak giriş yapabilirsin.",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      _buildSubmitButton(),
                      const SizedBox(height: AppSpacing.lg),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text("VEYA", style: AppText.overline),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildGoogleSignInButton(),
                    ],
                    if (!_isLogin) ...[
                      const SizedBox(height: AppSpacing.xl),
                      // YASAL METİN (MAĞAZA ŞARTI)
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          const Text("Kayıt olarak ", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse('https://sites.google.com/view/owlish-terms-of-use/ana-sayfa')),
                            child: const Text("Kullanım Şartları",
                                style: TextStyle(color: AppColors.primaryLight, fontSize: 11, decoration: TextDecoration.underline)),
                          ),
                          const Text(" ve ", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse('https://sites.google.com/view/owlishprivacypolicy/ana-sayfa')),
                            child: const Text("Gizlilik Politikasını",
                                style: TextStyle(color: AppColors.primaryLight, fontSize: 11, decoration: TextDecoration.underline)),
                          ),
                          const Text(" kabul etmiş olursunuz.", style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle() {
    Widget tab(String label, bool login) {
      final selected = _isLogin == login;
      return Expanded(
        child: GestureDetector(
          onTap: () => _setMode(login),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [tab('Giriş Yap', true), tab('Kayıt Ol', false)]),
    );
  }

  Widget _buildHeroLogo() {
    return GestureDetector(
      onTap: _backToLanding,
      child: AnimatedBuilder(
        animation: _floatingController,
        builder: (context, child) {
          final double bounce = Curves.easeInOutSine.transform(_floatingController.value);
          return Transform.translate(offset: Offset(0, -6 + (bounce * 12)), child: child);
        },
        child: Image.asset('assets/logo_transparent.png', height: 120, fit: BoxFit.contain),
      ),
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
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
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
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: IconButton(
          icon: Icon(isVisible ? Icons.visibility_rounded : Icons.visibility_off_rounded),
          onPressed: onVisibilityChanged,
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return FilledButton(
      onPressed: _submit,
      child: Text(_isLogin ? 'Giriş Yap' : 'Kayıt Ol'),
    );
  }

  Widget _buildGoogleSignInButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _signInWithGoogle,
        icon: Image.network(
          'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/120px-Google_%22G%22_logo.svg.png',
          height: 22,
          errorBuilder: (_, _, _) => const Icon(Icons.g_mobiledata_rounded, color: Colors.black87),
        ),
        label: Text(_isLogin ? 'Google ile Devam Et' : 'Google ile Kayıt Ol'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1F1F1F),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
