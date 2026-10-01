import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_screen.dart';
import 'tts_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../theme/theme_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TtsService _ttsService = TtsService();

  double _currentRate = 0.55;
  double _currentPitch = 1.0;

  String _selectedLevel = 'A1';
  bool _isLoadingUser = true;
  final List<String> _levels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

  final TextEditingController _testTextController = TextEditingController(
    text: "Hello, this is a test for the new voice settings.",
  );

  @override
  void initState() {
    super.initState();
    // Ekran açıldığında servisteki mevcut ayarları alıyoruz
    _currentRate = _ttsService.speechRate;
    _currentPitch = _ttsService.pitch;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _selectedLevel = doc.data()?['level'] ?? 'A1';
            _isLoadingUser = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingUser = false);
      }
    } else {
      if (mounted) setState(() => _isLoadingUser = false);
    }
  }

  @override
  void dispose() {
    _testTextController.dispose();
    super.dispose();
  }

  Future<void> _testVoice() async {
    // Test etmek için butona basıldığında güncel ayarları servise uygulayıp test metnini okutuyoruz
    await _ttsService.setRate(_currentRate);
    await _ttsService.setPitch(_currentPitch);
    await _ttsService.speak(_testTextController.text);
  }

  Future<void> _saveSettings() async {
    // Ayarları kalıcı olarak servise kaydediyoruz
    await _ttsService.setRate(_currentRate);
    await _ttsService.setPitch(_currentPitch);

    // Seviyeyi Firebase'e kaydediyoruz
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'level': _selectedLevel});
      } catch (e) {
        debugPrint("Seviye güncellenirken hata: $e");
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline, color: AppColors.textPrimary),
              SizedBox(width: 10),
              Text("Ses ayarları başarıyla kaydedildi! ✨", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: AppColors.primary.withOpacity(0.9), // Temaya Uygun SnackBar
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      );
    }
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _confirmDeleteAccount() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text("Hesabı Sil", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Hesabınızı ve tüm kelime havuzu/istatistik verilerinizi kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.",
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.danger.withOpacity(0.3)),
              ),
              child: Text(
                "⚠️ DİKKAT: Eğer aktif bir VIP aboneliğiniz varsa, hesabı silmek aboneliğinizi otomatik iptal etmez. İptal işlemini cihazınızın App Store veya Google Play ayarlarından yapmanız gerekmektedir.",
                style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Vazgeç", style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.dangerFill),
            onPressed: () async {
              Navigator.pop(context);
              await _deleteAccount();
            },
            child: const Text("Kalıcı Olarak Sil", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // 1. Önce kullanıcının oturumunun taze olup olmadığını kontrol et
        final lastSignIn = user.metadata.lastSignInTime;
        if (lastSignIn != null) {
          final diff = DateTime.now().difference(lastSignIn);
          if (diff.inMinutes > 5) {
            // Eğer 5 dakikadan eskiyse, Firebase Auth zaten hata verecektir.
            // Bu yüzden veritabanını silmeden önce işlemi durduruyoruz.
            throw FirebaseAuthException(
              code: 'requires-recent-login',
              message: 'Güvenlik nedeniyle yeniden giriş yapmalısınız.',
            );
          }
        }

        // 2. Oturum tazeyse önce veritabanındaki verileri siliyoruz
        final userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        
        // Alt koleksiyonlar toplu silinir (sayfa başına tek istek).
        for (final sub in const ['words', 'test_history', 'chatHistory']) {
          await _deleteCollection(userDocRef.collection(sub));
        }

        // Ana dokümanı siliyoruz
        await userDocRef.delete();
        
        // 3. Son olarak Auth (Giriş) hesabını tamamen siliyoruz
        await user.delete();
        await GoogleSignIn().signOut();
        
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        debugPrint("Hesap silinirken hata: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Güvenlik nedeniyle hesabınızı silmek için lütfen uygulamadan çıkış yapıp tekrar giriş yapın ve tekrar deneyin."),
              backgroundColor: AppColors.dangerFill,
            ),
          );
        }
      }
    }
  }

  /// Koleksiyonu 400'lük sayfalar hâlinde, her sayfayı tek toplu yazmayla
  /// siler (yüzlerce sıralı istek ve tüm koleksiyonu belleğe alma yerine).
  Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> collection) async {
    while (true) {
      final page = await collection.limit(400).get();
      if (page.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in page.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (page.docs.length < 400) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg, // Dark Space Background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Genel Ayarlar'
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground(child: SizedBox.expand())),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BİLGİ KARTI (Glassmorphism) ---
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.7), // Glass background
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.record_voice_over_rounded,
                            size: 28,
                            color: AppColors.primaryLight,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Text(
                            "Burada yaptığınız değişiklikler tüm uygulamadaki okuma hızını ve tonunu anında günceller.",
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),

                  // --- GÖRÜNÜM (AÇIK / KOYU MOD) ---
                  Text("Görünüm", style: AppText.heading(size: 18)),
                  const SizedBox(height: 12),
                  ValueListenableBuilder<ThemeMode>(
                    valueListenable: ThemeController.instance,
                    builder: (context, mode, _) => SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<ThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: Icon(Icons.brightness_auto_rounded, size: 18),
                            label: Text('Sistem'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: Icon(Icons.light_mode_rounded, size: 18),
                            label: Text('Açık'),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: Icon(Icons.dark_mode_rounded, size: 18),
                            label: Text('Koyu'),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (s) => ThemeController.instance.setMode(s.first),
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (st) => st.contains(WidgetState.selected) ? AppColors.primary : AppColors.surface,
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (st) => st.contains(WidgetState.selected) ? Colors.white : AppColors.textSecondary,
                          ),
                          side: WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Sistem seçiliyken uygulama telefonunun açık/koyu ayarını takip eder.",
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 40),

                  // --- İNGİLİZCE SEVİYESİ ---
                  if (!_isLoadingUser) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "İngilizce Seviyesi",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: AppColors.secondary.withOpacity(0.3)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedLevel,
                              icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.secondary),
                              dropdownColor: AppColors.surface,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.secondary,
                              ),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedLevel = newValue;
                                  });
                                }
                              },
                              items: _levels.map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Yapay zeka asistanı içerik üretirken bu seviyeyi baz alacaktır.",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],

                  // --- SES HIZI (RATE) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Okuma Hızı",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _currentRate.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.secondary,
                      inactiveTrackColor: AppColors.secondary.withOpacity(0.2),
                      thumbColor: AppColors.textPrimary,
                      overlayColor: AppColors.secondary.withOpacity(0.2),
                      trackHeight: 6.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                    ),
                    child: Slider(
                      value: _currentRate,
                      min: 0.1,
                      max: 1.5,
                      divisions: 14,
                      onChanged: (value) {
                        setState(() {
                          _currentRate = value;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Çok Yavaş",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Çok Hızlı",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- SES TONU (PITCH) ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Ses Tonu (Kalınlık)",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _currentPitch.toStringAsFixed(2),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primaryLight,
                      inactiveTrackColor: AppColors.primaryLight.withOpacity(0.2),
                      thumbColor: AppColors.textPrimary,
                      overlayColor: AppColors.primaryLight.withOpacity(0.2),
                      trackHeight: 6.0,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
                    ),
                    child: Slider(
                      value: _currentPitch,
                      min: 0.5,
                      max: 2.0,
                      divisions: 15,
                      onChanged: (value) {
                        setState(() {
                          _currentPitch = value;
                        });
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Kalın Ses",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "İnce Ses",
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // --- TEST ALANI ---
                  TextField(
                    controller: _testTextController,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      labelText: "İngilizce Test Metni",
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: AppColors.secondary, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: AppColors.textPrimary.withOpacity(0.1), width: 1.5),
                      ),
                      prefixIcon: Icon(Icons.text_fields_rounded, color: AppColors.secondary),
                      filled: true,
                      fillColor: AppColors.surface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 35),

                  // --- BUTONLAR ---
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _testVoice,
                          icon: const Icon(Icons.play_circle_fill_rounded),
                          label: const Text(
                            "Dinle",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: AppColors.secondary.withOpacity(0.5), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _saveSettings,
                          icon: const Icon(Icons.save_rounded),
                          label: Text(
                            "Kaydet",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            backgroundColor: AppColors.primary,
                            elevation: 8,
                            shadowColor: AppColors.primaryLight.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // --- HESAP VE YASAL BİLGİLER (MAĞAZA ZORUNLULUĞU) ---
                  Text(
                    "Hesap ve Yasal Bilgiler",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.surface),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(Icons.privacy_tip_outlined, color: AppColors.secondary),
                          title: Text("Gizlilik Politikası", style: TextStyle(color: AppColors.textPrimary)),
                          trailing: Icon(Icons.open_in_new, color: AppColors.textMuted, size: 18),
                          onTap: () => _launchURL('https://sites.google.com/view/owlishprivacypolicy/ana-sayfa'),
                        ),
                        Divider(color: AppColors.textPrimary.withOpacity(0.1), height: 1),
                        ListTile(
                          leading: Icon(Icons.description_outlined, color: AppColors.primaryLight),
                          title: Text("Kullanım Şartları", style: TextStyle(color: AppColors.textPrimary)),
                          trailing: Icon(Icons.open_in_new, color: AppColors.textMuted, size: 18),
                          onTap: () => _launchURL('https://sites.google.com/view/owlish-terms-of-use/ana-sayfa'),
                        ),
                        Divider(color: AppColors.textPrimary.withOpacity(0.1), height: 1),
                        ListTile(
                          leading: Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                          title: Text("Çıkış Yap", style: TextStyle(color: AppColors.textSecondary)),
                          onTap: _signOut,
                        ),
                        Divider(color: AppColors.textPrimary.withOpacity(0.1), height: 1),
                        ListTile(
                          leading: Icon(Icons.delete_forever_rounded, color: AppColors.danger),
                          title: Text("Hesabımı Sil", style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                          onTap: _confirmDeleteAccount,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
