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
                color: AppColors.textPrimary,
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
            Flexible(
              child: Text(
                'Octopus English',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
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
                backgroundColor: AppColors.textPrimary.withOpacity(0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Text(
                'Giriş Yap',
                style: TextStyle(
                  color: AppColors.textPrimary,
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
                              color: AppColors.textPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              border: Border.all(color: AppColors.border,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: AppColors.gold,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Yapay Zeka Destekli Öğrenim",
                                  style: TextStyle(
                                    color: AppColors.textPrimary.withOpacity(0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            "İngilizceyi Yaşayarak\nÖğrenin",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 42,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -1.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Yapay zeka ile sohbet, etkileşimli hikayeler, kamerayla çeviri ve kelime testleriyle İngilizcenizi her gün bir adım ileri taşıyın.",
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
                          color: AppColors.textPrimary.withOpacity(0.9),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildLargeBentoCard(
                      icon: Icons.forum_rounded,
                      iconColor: AppColors.gold,
                      title: "Yapay Zeka Öğretmen",
                      description: "Yapay zeka ile İngilizce sohbet ederek pratik yapın; hatalarınızı Türkçe açıklamalarıyla anında görün.",
                      gradientColors: [AppColors.gold.withOpacity(0.2), AppColors.gold.withOpacity(0.05)],
                    ),
                    const SizedBox(height: 16),

                    // YENİ: BÜYÜK KART (Okuma ve Telaffuz)
                    _buildLargeBentoCard(
                      icon: Icons.mic_external_on_rounded,
                      iconColor: AppColors.primaryLight,
                      title: "Okuma ve Telaffuz Pratiği",
                      description: "İngilizce metinleri sesli okuyun; doğru okuduğunuz kelimeler yeşil, tekrar etmeniz gerekenler kırmızı işaretlensin.",
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
                      title: "Kamera ile Çeviri",
                      description: "Gerçek hayattaki İngilizce yazıları kameranızla tarayın, kelimelerin anlamını anında görün.",
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
                            description: "İngilizce haberlerle okuma pratiği.",
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSmallBentoCard(
                            icon: Icons.inventory_2_rounded,
                            iconColor: AppColors.primary,
                            title: "Havuz",
                            description: "Hazır paketler ve kendi kelimeleriniz.",
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
                            description: "Öğrendiklerinizi quizlerle pekiştirin.",
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSmallBentoCard(
                            icon: Icons.insights_rounded,
                            iconColor: AppColors.success,
                            title: "Gelişim",
                            description: "Test sonuçlarınız ve başarı oranınız.",
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 80),

                    // --- NASIL İLERLERSİN? (özellikleri tekrar etmeden öğrenme döngüsü) ---
                    Center(
                      child: Text(
                        "3 Adımda İlerle",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary.withOpacity(0.9),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        "Öğrendiğin her kelime bir sonraki adımı besler.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),

                    _buildStep(
                      number: 1,
                      icon: Icons.bookmark_add_rounded,
                      color: AppColors.secondary,
                      title: "Kelimeni yakala",
                      description:
                          "Kamerayla taradığın ya da çevirdiğin kelimeleri kendi kelime havuzunda topla. Ne öğreneceğine sen karar ver.",
                    ),
                    _buildStep(
                      number: 2,
                      icon: Icons.record_voice_over_rounded,
                      color: AppColors.primaryLight,
                      title: "Kullanarak pekiştir",
                      description:
                          "Kartlarla çalış, testlerle kendini dene, yapay zekayla sohbet ederek kelimeleri gerçek cümlelerde kullan.",
                    ),
                    _buildStep(
                      number: 3,
                      icon: Icons.trending_up_rounded,
                      color: AppColors.gold,
                      title: "Her gün biraz daha",
                      description:
                          "Kısa günlük tekrarlarla serini büyüt. İlerlemeni raporlardan adım adım izle.",
                      isLast: true,
                    ),

                    const SizedBox(height: 40),

                    // --- NEDEN OCTOPUS ENGLISH? ---
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _buildPerk(value: "A1–C2", label: "Seviyene göre içerik")),
                          const SizedBox(width: 12),
                          Expanded(child: _buildPerk(value: "Türkçe", label: "Hata açıklamaları")),
                          const SizedBox(width: 12),
                          Expanded(child: _buildPerk(value: "Ücretsiz", label: "Hemen başla")),
                        ],
                      ),
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
                          Icon(
                            Icons.rocket_launch_rounded,
                            color: AppColors.textPrimary,
                            size: 50,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "Yeni Macerana Hazır Mısın?",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Seviyenize göre hazır kelime paketleri, etkileşimli hikayeler ve yapay zeka sohbet arkadaşınız sizi bekliyor. Ücretsiz hesabınızı hemen oluşturun.",
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
                            style: TextStyle(
                              color: AppColors.textPrimary,
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
                  style: TextStyle(
                    color: AppColors.textPrimary,
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

  /// "3 Adımda İlerle" bölümündeki tek bir adım: numaralı rozet, adımları
  /// birbirine bağlayan çizgi ve açıklama.
  Widget _buildStep({
    required int number,
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    bool isLast = false,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.18),
                    border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
                  ),
                  child: Text(
                    "$number",
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [color.withValues(alpha: 0.5), AppColors.border],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5,
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

  /// "Neden Octopus English?" şeridindeki kısa artı.
  Widget _buildPerk({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
