import 'package:audio_session/audio_session.dart';

/// Uygulamanın kısa arayüz sesleri (açılış sesi, tıklama) için ortak ses oturumu.
///
/// - **iOS:** "ambient" kategori: telefonun sessiz anahtarına uyar, kullanıcının
///   çaldığı müziği kesmez, onunla karışır.
/// - **Android:** "sistem sesleri" kanalı (assistanceSonification): telefon
///   sessiz ya da titreşim modundayken susar, ses seviyesi sistem seslerine
///   bağlıdır. Medya ses seviyesinden bağımsızdır.
class AppAudio {
  AppAudio._();

  static Future<void>? _configured;

  /// Oturumu bir kez yapılandırır; tekrar çağrılar aynı işi paylaşır.
  static Future<void> configureSession() => _configured ??= _configure();

  static Future<void> _configure() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.ambient,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.assistanceSonification,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      ),
    );
  }
}
