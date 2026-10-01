import 'package:flutter/material.dart';
import 'auth_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  void _navigateToAuth(BuildContext context, bool isLogin) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) =>
            AuthScreen(initialLoginMode: isLogin),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/logo_transparent.png',
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: Text(
                'Octopus English',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.5,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
            child: TextButton(
              onPressed: () => _navigateToAuth(context, true),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: const Text(
                'Giriş Yap',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // YENİ UZUN DİNAMİK ARKA PLAN
          const Positioned.fill(child: AppBackground(child: SizedBox.expand())),

          // Aura Efektleri (Arka plana derinlik katmak için)

          // Kaydırılabilir Ana İçerik
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),

                    // --- HERO BÖLÜMÜ ---
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              border: Border.all(color: AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.gold,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Yapay Zeka Destekli Öğrenim",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          const Text(
                            "İngilizceyi Yaşayarak\nÖğrenin",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 42,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Sıradan kelime testlerini unutun. AI sohbet, interaktif hikayeler, kamera çevirisi ve çok daha fazlası ile dil yeteneklerinizi zirveye taşıyın.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 60),

                    // --- BENTO BOX ÖZELLİKLER BÖLÜMÜ ---
                    Center(
                      child: Text(
                        "Sınırları Aşan Özellikler",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildLargeBentoCard(
                      icon: Icons.forum_rounded,
                      iconColor: AppColors.gold,
                      title: "Yapay Zeka Öğretmen",
                      description: "AI tabanlı chat sistemi ile 7/24 kesintisiz pratik yapın ve hatalarınızı anında görün.",
                      gradientColors: [AppColors.gold.withOpacity(0.2), AppColors.gold.withOpacity(0.05)],
                    ),
                    const SizedBox(height: 16),

                    // YENİ: BÜYÜK KART (Okuma ve Telaffuz)
                    _buildLargeBentoCard(
                      icon: Icons.mic_external_on_rounded,
                      iconColor: AppColors.primaryLight,
                      title: "Okuma ve Telaffuz Analizi",
                      description: "İngilizce metinleri sesli okuyun, AI telaffuzunuzu analiz edip hatalarınızı kırmızı ile göstersin.",
                      gradientColors: [AppColors.primaryLight.withOpacity(0.2), AppColors.primaryLight.withOpacity(0.05)],
                    ),
                    const SizedBox(height: 16),

                    // 2. SATIR: İKİ KÜÇÜK KART (Hikayeler & Videolar)
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallBentoCard(
                            icon: Icons.auto_stories_rounded,
                            iconColor: AppColors.primaryLight,
                            title: "Hikayeler",
                            description: "İnteraktif metinler ve anında çeviri.",
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSmallBentoCard(
                            icon: Icons.play_circle_fill_rounded,
                            iconColor: AppColors.danger,
                            title: "Videolar",
                            description: "Dinleme (Listening) pratikleri yapın.",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 3. SATIR: BÜYÜK KART (Kamera Çevirisi)
                    _buildLargeBentoCard(
                      icon: Icons.document_scanner_rounded,
                      iconColor: AppColors.secondary,
                      title: "Kamera ile Çeviri (AI Vision)",
                      description: "Gerçek dünyadaki İngilizce metinleri kameranızla okutun, AI teknolojisi anında çevirsin.",
                      gradientColors: [AppColors.secondary.withOpacity(0.2), AppColors.secondary.withOpacity(0.05)],
                    ),
                    const SizedBox(height: 16),

                    // 4. SATIR: İKİ KÜÇÜK KART (Haberler & Kelime Havuzu)
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallBentoCard(
                            icon: Icons.article_rounded,
                            iconColor: AppColors.secondary,
                            title: "Haberler",
                            description: "Güncel İngilizce makaleler.",
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSmallBentoCard(
                            icon: Icons.inventory_2_rounded,
                            iconColor: AppColors.primary,
                            title: "Havuz",
                            description: "Öğrendiklerinizi biriktirin.",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 5. SATIR: İKİ KÜÇÜK KART (Testler & Gelişim Raporu)
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallBentoCard(
                            icon: Icons.quiz_rounded,
                            iconColor: AppColors.gold,
                            title: "Testler",
                            description: "Kalıcı hafıza için quizler.",
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSmallBentoCard(
                            icon: Icons.insights_rounded,
                            iconColor: AppColors.success,
                            title: "Gelişim",
                            description: "Detaylı analiz ve raporlar.",
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 80),

                    // --- KULLANICI YORUMLARI (TESTIMONIALS) ---
                    Center(
                      child: Text(
                        "Kullanıcılarımız Ne Diyor?",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildTestimonialCard(
                      name: "Ayşe Yılmaz",
                      role: "Üniversite Öğrencisi",
                      comment:
                          "Özellikle kamera ile çeviri harika! Gördüğüm her şeyi okutup anında kelime hazinemi geliştiriyorum. Gerçek bir asistan.",
                    ),
                    const SizedBox(height: 16),
                    _buildTestimonialCard(
                      name: "Caner Korkmaz",
                      role: "Yazılım Geliştirici",
                      comment:
                          "AI Chat sayesinde konuşma pratiği yapma korkumu yendim. Karşımda beni yargılamayan, mükemmel bir İngilizce öğretmeni var.",
                    ),
                    const SizedBox(height: 16),
                    _buildTestimonialCard(
                      name: "Selin Demir",
                      role: "Lise Öğrencisi",
                      comment:
                          "Hikayeler bölümü mükemmel. Bilmediğim kelimeye basıp çevirisini gördüğüm için artık hikaye okumak hiç sıkıcı değil!",
                    ),
                    const SizedBox(height: 16),
                    _buildTestimonialCard(
                      name: "Mehmet Yıldırım",
                      role: "İngilizce Öğretmeni",
                      comment:
                          "Öğrencilerime tavsiye ettiğim tek uygulama. Kaydırılabilir kelime kartları (Flashcards) ve akıllı tekrar sistemi kelimeleri kalıcı belleğe adeta kazıyor.",
                    ),
                    const SizedBox(height: 16),
                    _buildTestimonialCard(
                      name: "Burcu Kaya",
                      role: "Banka Yöneticisi",
                      comment:
                          "Kelime testleri ve seri (streak) koruma hırsı sayesinde İngilizce çalışmak bağımlılık yapan bir oyun gibi oldu. Artık her gün pratik yapıyorum!",
                    ),

                    const SizedBox(height: 80),

                    // --- KAYIT OL (CTA) BÖLÜMÜ ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 40,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.9),
                            AppColors.secondary.withOpacity(0.9),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(
                          color: AppColors.textMuted,
                        ),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.rocket_launch_rounded,
                            color: Colors.white,
                            size: 50,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "Yeni Macerana Hazır Mısın?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Binlerce kelime, interaktif hikayeler ve AI öğretmeniniz sizi bekliyor. Ücretsiz hesabınızı saniyeler içinde oluşturun.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 35),
                          ElevatedButton(
                            onPressed: () => _navigateToAuth(
                              context,
                              false,
                            ), // false = Register
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              minimumSize: const Size(double.infinity, 60),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.xl),
                              ),
                              elevation: 10,
                            ),
                            child: const Text(
                              'Ücretsiz Kayıt Ol',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          TextButton(
                            onPressed: () =>
                                _navigateToAuth(context, true), // true = Login
                            child: Text(
                              "Zaten hesabım var",
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),
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


  // YENİ BENTO BOX BÜYÜK KART TASARIMI
  Widget _buildLargeBentoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
            children: [
              Positioned(
                right: -30,
                bottom: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: gradientColors,
                      stops: const [0.1, 1.0],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(icon, color: iconColor, size: 32),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ),
    );
  }

  // YENİ BENTO BOX KÜÇÜK KART TASARIMI
  Widget _buildSmallBentoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      height: 180, // Eşit yükseklik sağlamak için
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.surface),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }

  Widget _buildTestimonialCard({
    required String name,
    required String role,
    required String comment,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      child: Text(
                        name[0],
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          role,
                          style: TextStyle(
                            color: AppColors.gold.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.format_quote_rounded,
                      color: Colors.white24,
                      size: 40,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "\"$comment\"",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontStyle: FontStyle.italic,
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(
                    5,
                    (index) => const Icon(
                      Icons.star_rounded,
                      color: AppColors.gold,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }
}
