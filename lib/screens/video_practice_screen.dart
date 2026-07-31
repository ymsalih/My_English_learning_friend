import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as native;
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as web;
import 'dart:ui'; // For BackdropFilter

class VideoPracticeScreen extends StatelessWidget {
  const VideoPracticeScreen({super.key});

  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)], // Mor ve Mavi Uzay Geçişi
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Space Background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'İngilizce Dinleme & Pratik',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
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
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
                  .collection('practice_videos')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.purpleAccent),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final videos = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  physics: const BouncingScrollPhysics(),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index].data();
                    final rawVideoId = video['id'] ?? '';
                    final title = video['title'] ?? 'Başlıksız Video';
                    final desc = video['desc'] ?? '';

                    final videoId = _extractYoutubeId(rawVideoId);

                    if (videoId.isEmpty) return const SizedBox.shrink();

                    return _buildVideoCard(context, videoId, title, desc);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Kullanıcı Firebase'e yanlışlıkla tam URL girse bile ID'yi söküp alır
  String _extractYoutubeId(String urlOrId) {
    if (urlOrId.isEmpty) return '';
    String cleaned = urlOrId.trim();
    
    // Eğer sadece 11 karakterli ham ID girdiyse
    if (cleaned.length == 11 && !cleaned.contains('http') && !cleaned.contains('/')) return cleaned;
    
    // URL'den ID çıkarma (Çok daha gelişmiş Regex)
    final RegExp regExp = RegExp(
      r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:[^\/\n\s]+\/\S+\/|(?:v|e(?:mbed)?)\/|\S*?[?&]v=)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
      caseSensitive: false,
      multiLine: false,
    );
    final match = regExp.firstMatch(cleaned);
    if (match != null && match.group(1) != null && match.group(1)!.length == 11) {
      return match.group(1)!;
    }
    
    // Bulamazsa temizlenmiş halini döndür (çökmekten iyidir)
    return cleaned;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.purpleAccent.withOpacity(0.2), blurRadius: 30),
              ],
            ),
            child: const Icon(
              Icons.ondemand_video_rounded,
              size: 90,
              color: Colors.purpleAccent,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'Şu an hiç video yok.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            'Çok yakında harika içerikler\nburaya eklenecek!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, String videoId, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.7), // Glass panel
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.purpleAccent.withOpacity(0.2),
          highlightColor: Colors.purpleAccent.withOpacity(0.1),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlayerScreen(videoId: videoId, title: title),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildThumbnail(videoId),
              _buildVideoInfo(title, desc),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(String videoId) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)), // Border width compensation
          child: Image.network(
            'https://img.youtube.com/vi/$videoId/0.jpg',
            height: 220,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        // Dark Overlay for better contrast
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
        ),
        // Neon Play Button (Glassmorphism)
        ClipRRect(
          borderRadius: BorderRadius.circular(50),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.purpleAccent.withOpacity(0.5), blurRadius: 20),
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 50,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoInfo(String title, String desc) {
    return Padding(
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
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            desc,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.purpleAccent.shade100.withOpacity(0.8),
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ========================================================= //
// OYNATICI EKRANI (PLAYER SCREEN) - MOBİL & WEB UYUMLU
// ========================================================= //

class PlayerScreen extends StatefulWidget {
  final String videoId;
  final String title;

  const PlayerScreen({super.key, required this.videoId, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  // Mobil Controller
  late native.YoutubePlayerController _nativeController;
  // Web Controller
  late web.YoutubePlayerController _webController;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // 🚀 WEB İÇİN BAŞLATMA
      _webController = web.YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        params: const web.YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
        ),
      );
    } else {
      // 📱 MOBİL İÇİN BAŞLATMA
      _nativeController = native.YoutubePlayerController(
        initialVideoId: widget.videoId,
        flags: const native.YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          forceHD: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (!kIsWeb) _nativeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(child: kIsWeb ? _buildWebPlayer() : _buildNativePlayer()),
    );
  }

  // 🚀 WEB OYNATICI (Bağlantı kopsa da donmaz)
  Widget _buildWebPlayer() {
    return web.YoutubePlayer(controller: _webController, aspectRatio: 16 / 9);
  }

  // 📱 MOBİL OYNATICI
  Widget _buildNativePlayer() {
    return native.YoutubePlayer(
      controller: _nativeController,
      showVideoProgressIndicator: true,
      progressIndicatorColor: Colors.purpleAccent,
    );
  }
}
