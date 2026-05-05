import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  // Singleton deseni: Tüm uygulamada sadece bir tane TtsService nesnesi olmasını sağlar.
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  FlutterTts? _flutterTts;
  bool _isInitialized = false;

  // --- MERKEZİ SES AYARLARI ---
  // Bu değerleri ileride bir Ayarlar sayfasından değiştirebiliriz.
  double _speechRate = 0.55; // Ses hızı
  double _pitch = 1.0; // Ses tonu (incelik/kalınlık)

  // Motoru hazırlayan (Initialize) fonksiyon - Sadece ilk kullanımda tetiklenir.
  Future<void> _initTts() async {
    if (!_isInitialized) {
      _flutterTts = FlutterTts();
      await _flutterTts!.setLanguage("en-US");
      await _flutterTts!.setSpeechRate(_speechRate);
      await _flutterTts!.setPitch(_pitch);
      _isInitialized = true;
    }
  }

  // DIŞARIYA AÇILAN OKUMA FONKSİYONU
  Future<void> speak(String text) async {
    if (text.isEmpty) return;

    // Lazy Loading: Eğer motor henüz kurulmadıysa şimdi kur.
    if (!_isInitialized) {
      await _initTts();
    }

    await _flutterTts!.speak(text);
  }

  // --- AYAR GÜNCELLEME FONKSİYONLARI ---
  Future<void> setRate(double rate) async {
    _speechRate = rate;
    if (_isInitialized) {
      await _flutterTts!.setSpeechRate(_speechRate);
    }
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch;
    if (_isInitialized) {
      await _flutterTts!.setPitch(_pitch);
    }
  }

  // Getter'lar (Ayarlar sayfasında mevcut hızı görmek için)
  double get speechRate => _speechRate;
  double get pitch => _pitch;
}
