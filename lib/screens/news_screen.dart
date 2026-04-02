import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'news_details_screen.dart'; // Yeni detay sayfasını import ediyoruz

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        title: Text(
          "Okuma Pratiği",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1A1A2E),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('news_links').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Henüz haber eklenmemiş."));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                index:
                    index, // 🎨 Yedek renk sırasını belirlemek için index'i yolluyoruz
              );
            },
          );
        },
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
      if (cleanHex.length == 6)
        cleanHex = 'FF$cleanHex'; // Opaklık (Görünürlük) ekle

      cardColor = Color(int.parse(cleanHex, radix: 16));
    } catch (e) {
      // 🔥 HATA DURUMUNDA ÇÖKMEK YERİNE YEDEK RENKLERİ KULLAN
      List<Color> fallbackColors = const [
        Color(0xFF6200EE), // Mor
        Color(0xFF009688), // Turkuaz
        Color(0xFFFF9800), // Turuncu
        Color(0xFFE91E63), // Pembe
        Color(0xFF3F51B5), // İndigo
      ];
      // Haber sırasına (index) göre yedek bir renk seç (hep aynı renk olmasın diye)
      cardColor = fallbackColors[index % fallbackColors.length];
    }

    return GestureDetector(
      onTap: () {
        // Tıklamada URL boşsa boşuna hata vermesin
        if (url.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bu haberin bağlantısı bulunmuyor.")),
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
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 8,
                decoration: BoxDecoration(
                  color:
                      cardColor, // 🔥 Hesaplanan güvenli (Firebase veya Yedek) rengi atadık
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3142),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Colors.black54,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.black12,
                size: 16,
              ),
              const SizedBox(width: 15),
            ],
          ),
        ),
      ),
    );
  }
}
