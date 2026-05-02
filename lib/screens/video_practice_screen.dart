import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // 🚀 Web kontrolü için
import 'package:youtube_player_flutter/youtube_player_flutter.dart'
    as native; // Mobil için
import 'package:youtube_player_iframe/youtube_player_iframe.dart'
    as web; // 🚀 Web için

class VideoPracticeScreen extends StatelessWidget {
  const VideoPracticeScreen({super.key});

  final LinearGradient primaryGradient = const LinearGradient(
    colors: [Color(0xFFD32F2F), Color(0xFFFF5252)],
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
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: primaryGradient),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
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
              return _buildEmptyState();
            }

            final videos = snapshot.data!.docs;

            return ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index].data() as Map<String, dynamic>;
                final videoId = video['id'] ?? '';
                final title = video['title'] ?? 'Başlıksız Video';
                final desc = video['desc'] ?? '';

                if (videoId.isEmpty) return const SizedBox.shrink();

                return Card(
                  elevation: 5,
                  color: Colors.white,
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
                        _buildThumbnail(videoId),
                        _buildVideoInfo(title, desc),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => primaryGradient.createShader(bounds),
            child: const Icon(
              Icons.ondemand_video_rounded,
              size: 90,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Şu an hiç video yok.',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC62828),
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

  Widget _buildThumbnail(String videoId) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Image.network(
            'https://img.youtube.com/vi/$videoId/0.jpg',
            height: 210,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Container(
          height: 210,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.red,
            size: 45,
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
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
      progressIndicatorColor: Colors.redAccent,
    );
  }
}
