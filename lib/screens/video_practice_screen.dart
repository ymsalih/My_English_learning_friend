import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class VideoPracticeScreen extends StatelessWidget {
  const VideoPracticeScreen({super.key});

  // 🎬 VİDEO PRATİK ÖZEL TEMASI (Sinematik Kırmızı Geçiş)
  final LinearGradient primaryGradient = const LinearGradient(
    colors: [
      Color(0xFFD32F2F),
      Color(0xFFFF5252),
    ], // Colors.red.shade700 ve redAccent.shade400
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'İngilizce Dinleme & Pratik',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // 🎬 APPBAR İÇİN KIRMIZI GEÇİŞ
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: primaryGradient),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          // 🎬 ARKA PLAN İÇİN ÇOK YUMUŞAK KIRMIZI TİNT
          gradient: LinearGradient(
            colors: [Colors.red.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('practice_videos')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: Colors.red.shade600),
              );
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) =>
                          primaryGradient.createShader(bounds),
                      child: const Icon(
                        Icons.ondemand_video_rounded,
                        size: 90,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Şu an hiç video yok.',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Çok yakında harika içerikler\nburaya eklenecek!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              );
            }

            final videos = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.only(
                top: 15,
                bottom: 20,
                left: 15,
                right: 15,
              ),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index].data();
                final videoId = video['id'] ?? '';
                final title = video['title'] ?? 'Başlıksız Video';
                final desc = video['desc'] ?? '';

                if (videoId.isEmpty) return const SizedBox.shrink();

                return Card(
                  elevation: 5,
                  color: Colors.white,
                  surfaceTintColor: Colors.white,
                  shadowColor: Colors.red.withOpacity(0.2),
                  margin: const EdgeInsets.only(bottom: 25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              PlayerScreen(videoId: videoId, title: title),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- 1. VİDEO KÜÇÜK RESMİ (THUMBNAIL) VE PLAY İKONU ---
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(20),
                              ),
                              child: Image.network(
                                'https://img.youtube.com/vi/$videoId/0.jpg',
                                height: 210,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            // Karartma Perdesi (Siyah transparan)
                            Container(
                              height: 210,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.35),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(20),
                                ),
                              ),
                            ),
                            // Ortadaki Büyük Beyaz Play Butonu
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withOpacity(0.5),
                                    blurRadius: 15,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.red.shade700,
                                size: 45,
                              ),
                            ),
                          ],
                        ),

                        // --- 2. VİDEO BİLGİLERİ (BAŞLIK & AÇIKLAMA) ---
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black87,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 15),

                              // --- 3. ŞİMDİ İZLE ETİKETİ ---
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: Colors.red.shade200,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.slow_motion_video_rounded,
                                          color: Colors.red.shade700,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'Şimdi İzle',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ========================================================= //
// OYNATICI EKRANI (PLAYER SCREEN) - SİNEMA MODU (DARK THEME)
// ========================================================= //

class PlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;

  const PlayerScreen({super.key, required this.videoId, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        isLive: false,
        forceHD: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Sinema hissi vermek için arka planı tamamen siyah yapıyoruz
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent, // AppBar şeffaf
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
          progressIndicatorColor: Colors.redAccent,
          progressColors: const ProgressBarColors(
            playedColor: Colors.red,
            handleColor: Colors.white, // Oynatma topu beyaz (Youtube tarzı)
            bufferedColor: Colors.white30,
            backgroundColor: Colors.white12,
          ),
          bottomActions: [
            CurrentPosition(),
            ProgressBar(isExpanded: true),
            RemainingDuration(),
            const PlaybackSpeedButton(),
            FullScreenButton(),
          ],
        ),
      ),
    );
  }
}
