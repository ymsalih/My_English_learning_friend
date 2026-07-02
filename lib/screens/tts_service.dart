import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  // Singleton deseni: Tüm uygulamada sadece bir tane TtsService nesnesi olmasını sağlar.
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal() {
    _loadSettings(); // Sınıf oluştuğunda ayarları otomatik yükle
  }

  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  // --- MERKEZİ SES AYARLARI ---
  double _speechRate = 0.55; // Ses hızı
  double _pitch = 1.0; // Ses tonu (incelik/kalınlık)

  // Kalıcı hafızadan ayarları yükle
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _speechRate = prefs.getDouble('tts_rate') ?? 0.55;
      _pitch = prefs.getDouble('tts_pitch') ?? 1.0;
      
      // Eğer motor halihazırda çalışıyorsa, okuma ayarlarını anında güncelle
      if (_isInitialized && _flutterTts != null) {
        await _flutterTts!.setSpeechRate(_speechRate);
        await _flutterTts!.setPitch(_pitch);
      }
    } catch (e) {
      // SharedPreferences hatası durumunda varsayılan ayarlarla devam et
    }
  }

  // Motoru hazırlayan (Initialize) fonksiyon - Sadece ilk kullanımda tetiklenir.
  Future<void> _initTts() async {
    if (!_isInitialized) {
      _flutterTts = FlutterTts();
      await _loadSettings(); // Motor ayağa kalkarken kayıtlı ayarları kesin olarak çek
      await _flutterTts!.setLanguage("en-US");
      await _forceEnglishVoice();
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setPitch(_pitch);
      _isInitialized = true;
    }
  }

  // Cihazın / Tarayıcının dili ne olursa olsun zorla İngilizce bir ses (Voice) bulur
  Future<void> _forceEnglishVoice() async {
    try {
      final voices = await _flutterTts!.getVoices;
      if (voices != null) {
        for (var voice in voices) {
          final locale = voice["locale"].toString();
          // İçinde "en" geçen (en-US, en-GB, en-AU vb.) ilk sesi bul ve ayarla
          if (locale.toLowerCase().startsWith("en")) {
            await _flutterTts!.setVoice({"name": voice["name"], "locale": locale});
            break;
          }
        }
      }
    } catch (e) {
      // getVoices bazı eski platformlarda desteklenmeyebilir, hata verirse es geç
    }
  }

  // DIŞARIYA AÇILAN OKUMA FONKSİYONU
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Lazy Loading: Eğer motor henüz kurulmadıysa şimdi kur.
    if (!_isInitialized) {
      await _initTts();
    } else {
      // Motor kuruluyken bile okumadan hemen önce güncel ayarları cihaza bastır
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setPitch(_pitch);
    }

    // Web'de bazen tarayıcı kendi varsayılan diline dönebilir. 
    // Garanti altına almak için her okuma öncesi dili tekrar zorluyoruz.
    await _flutterTts!.setLanguage("en-US");
    await _forceEnglishVoice(); // Sesi de her ihtimale karşı tekrar zorla
    await _flutterTts!.speak(text);
  }

  // --- AYAR GÜNCELLEME VE KAYDETME FONKSİYONLARI ---
  Future<void> setRate(double rate) async {
    _speechRate = rate;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('tts_rate', rate);
    } catch (e) {}

    if (_isInitialized) {
      await _flutterTts!.setSpeechRate(_speechRate);
    }
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('tts_pitch', pitch);
    } catch (e) {}

    if (_isInitialized) {
      await _flutterTts!.setPitch(_pitch);
    }
  }

  // Getter'lar (Ayarlar sayfasında mevcut hızı görmek için)
  double get speechRate => _speechRate;
  double get pitch => _pitch;
}
