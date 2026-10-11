import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart' as native;
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as web;
import '../theme/app_theme.dart';
import '../theme/app_widgets.dart';
import '../widgets/cached_stream_builder.dart';
import 'dart:ui'; // For BackdropFilter

class VideoPracticeScreen extends StatelessWidget {
  const VideoPracticeScreen({super.key});

  LinearGradient get primaryGradient => LinearGradient(
    colors: [AppColors.primary, AppColors.secondary], // Mor ve Mavi Uzay Geçişi
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg, // Dark Space Background
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'İngilizce Dinleme & Pratik'
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AppBackground(child: SizedBox.expand())),
          SafeArea(
            child: CachedStreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              queryKey: 'practice_videos',
              // Üst sınır: koleksiyon büyüdükçe her açılışta tamamı okunmasın.
              create: () => FirebaseFirestore.instance
                  .collection('practice_videos')
                  .limit(100)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.primaryLight),
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
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.ondemand_video_rounded,
              size: 90,
              color: AppColors.primaryLight,
            ),
          ),
          const SizedBox(height: 30),
          Text(
            'Şu an hiç video yok.',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 15),
          Text(
            'Yeni videolar eklendiğinde burada görünecek.\nDaha sonra tekrar göz atabilirsin.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(BuildContext context, String videoId, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.7), // Glass panel
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          enableFeedback: false,
          borderRadius: BorderRadius.circular(24),
          splashColor: AppColors.primaryLight.withOpacity(0.2),
          highlightColor: AppColors.primaryLight.withOpacity(0.1),
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
          child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: AppColors.textPrimary.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.textMuted, width: 1.5),
              ),
              child: Icon(
                Icons.play_arrow_rounded,
                color: AppColors.textPrimary,
                size: 50,
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
          // Kaynak: YouTube API politikası, küçük resmi gösterilen içeriğin
          // YouTube'dan geldiğinin belli olmasını ister.
          Row(
            children: [
              Icon(Icons.smart_display_rounded, size: 16, color: AppColors.danger),
              const SizedBox(width: 6),
              Text(
                'YouTube',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
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
    if (!kIsWeb) {
      _nativeController.dispose();
      // Tam ekrandayken çıkılırsa yön kilidi ve gizlenen sistem çubukları
      // uygulamanın geri kalanında takılı kalmasın.
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: SystemUiOverlay.values);
    }
    super.dispose();
  }

  Scaffold _page(Widget player) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(child: player),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _page(_buildWebPlayer());

    // Telefon yan çevrilince video tam ekrana geçer, dik çevrilince geri döner;
    // tam ekrandayken geri tuşu önce tam ekrandan çıkarır.
    return native.YoutubePlayerBuilder(
      onExitFullScreen: () {
        // Paket tam ekrandan çıkarken yönü yalnızca dik konuma kilitler. Kilit
        // kaldırılmazsa telefon tekrar çevrildiğinde ekran dönmez ("takılır").
        SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      },
      player: _buildNativePlayer(),
      builder: (context, player) => _page(player),
    );
  }

  // 🚀 WEB OYNATICI (Bağlantı kopsa da donmaz)
  Widget _buildWebPlayer() {
    return web.YoutubePlayer(controller: _webController, aspectRatio: 16 / 9);
  }

  // 📱 MOBİL OYNATICI
  native.YoutubePlayer _buildNativePlayer() {
    return native.YoutubePlayer(
      controller: _nativeController,
      showVideoProgressIndicator: true,
      progressIndicatorColor: AppColors.primaryLight,
    );
  }
}
