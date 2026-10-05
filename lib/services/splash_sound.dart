import 'dart:async';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Açılış ekranının sesi (assets/sounds/splash_intro.wav).
///
/// Ses önceden hazırlanmış sıkıştırılmamış PCM dosyasıdır: çalarken kod çözme
/// maliyeti yoktur. Dosya, açılış animasyonunun zamanlamasına göre
/// üretilmiştir (tools/generate_splash_sound.py). Hiçbir hata uygulamanın
/// açılışını engellemez; ses başarısız olursa animasyon sessiz oynar.
class SplashSound {
  SplashSound._();

  static const String _asset = 'assets/sounds/splash_intro.wav';

  static AudioPlayer? _player;
  static Future<bool>? _ready;

  /// Sesi arka planda hazırlar. Uygulama başlarken, Firebase ve diğer
  /// başlatma işleriyle paralel çağrılır. Birden çok çağrı tek hazırlık yapar.
  static Future<bool> preload() => _ready ??= _load();

  static Future<bool> _load() async {
    try {
      // Sessiz moda saygılı ("ambient"), kullanıcının müziğini kesmeyen,
      // yalnızca kısa süre kısan bir oturum.
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.ambient,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.game,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        ),
      );

      final player = AudioPlayer();
      await player.setAsset(_asset, preload: true);
      await player.setVolume(1.0);
      _player = player;
      return true;
    } catch (e) {
      debugPrint('Açılış sesi hazırlanamadı: $e');
      return false;
    }
  }

  /// Hazırsa sesi çalar. Ses bitince oynatıcıyı serbest bırakır; açılış ekranı
  /// kapansa bile ses kendi kuyruğuyla doğal şekilde sönümlenir.
  static Future<void> play() async {
    final player = _player;
    if (player == null) return;
    _player = null;
    _ready = null;
    try {
      unawaited(
        player.processingStateStream
            .firstWhere((s) => s == ProcessingState.completed)
            .timeout(const Duration(seconds: 12))
            .then((_) => player.dispose(), onError: (_) => player.dispose()),
      );
      unawaited(player.play());
    } catch (e) {
      debugPrint('Açılış sesi çalınamadı: $e');
      unawaited(player.dispose());
    }
  }

  /// Ses çalınmayacaksa (ör. "animasyonları kaldır" açık) kaynağı bırakır.
  static Future<void> discard() async {
    final player = _player;
    _player = null;
    _ready = null;
    await player?.dispose();
  }
}
