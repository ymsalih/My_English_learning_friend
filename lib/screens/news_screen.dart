import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'news_details_screen.dart'; // Yeni detay sayfasını import ediyoruz

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Space Background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          "Okuma Pratiği",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Glows
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.purpleAccent.withOpacity(0.15), Colors.transparent],
                  stops: const [0.1, 1.0],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Colors.blueAccent.withOpacity(0.15), Colors.transparent],
                  stops: const [0.1, 1.0],
                ),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('news_links').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.purpleAccent),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Henüz haber eklenmemiş.",
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  physics: const BouncingScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];

                    // 🛡️ ADIM 1: StateError çökmesini önlemek için veriyi güvenli Haritaya (Map) çevir
                    Map<String, dynamic> data =
                        doc.data() as Map<String, dynamic>? ?? {};

                    // 🛡️ ADIM 2: 'color' alanı hiç yoksa kodun patlamaması için containsKey kontrolü yap
                    String safeColorHex =
                        data.containsKey('color') && data['color'] != null
                            ? data['color'].toString()
                            : '';

                    return _buildModernNewsCard(
                      context,
                      title: data['title']?.toString() ?? 'Başlıksız',
                      subtitle: data['subtitle']?.toString() ?? 'Açıklama yok.',
                      colorHex: safeColorHex, // Güvenli renk metnini yolla
                      url: data['url']?.toString() ?? '',
                      index: index, // Yedek renk sırasını belirlemek için index
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernNewsCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String colorHex,
    required String url,
    required int index, // Yeni eklenen parametre
  }) {
    // 🛡️ ADIM 3: ZIRHLI RENK ÇEVİRİCİ
    Color cardColor;
    try {
      // Renk Firebase'den boş veya null geldiyse direkt yedek renklere atla
      if (colorHex.trim().isEmpty) throw Exception("Renk verisi yok");

      // # işaretini temizle ve Flutter'ın anlayacağı HEX formatına çevir
      String cleanHex = colorHex.trim().replaceAll('#', '');
      if (cleanHex.length == 6) {
        cleanHex = 'FF$cleanHex'; // Opaklık (Görünürlük) ekle
      }

      cardColor = Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      // 🔥 HATA DURUMUNDA ÇÖKMEK YERİNE YEDEK RENKLERİ KULLAN (Neon Space Temasına Uygun)
      List<Color> fallbackColors = const [
        Colors.purpleAccent,
        Colors.blueAccent,
        Colors.pinkAccent,
        Colors.cyanAccent,
        Colors.greenAccent,
      ];
      // Haber sırasına (index) göre yedek bir renk seç (hep aynı renk olmasın diye)
      cardColor = fallbackColors[index % fallbackColors.length];
    }

    return GestureDetector(
      onTap: () {
        // Tıklamada URL boşsa boşuna hata vermesin
        if (url.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Bu haberin bağlantısı bulunmuyor."),
              backgroundColor: Colors.redAccent.withOpacity(0.9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                NewsDetailsScreen(url: url.trim(), title: title),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.7), // Glass panel
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Sol Taraftaki Parlayan Renk Şeridi
              Container(
                width: 8,
                decoration: BoxDecoration(
                  color: cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: cardColor.withOpacity(0.8),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.5),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
