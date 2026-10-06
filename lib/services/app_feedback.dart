import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_audio.dart';

/// Dokunma geri bildirimi: kısa tıklama sesi ve hafif titreşim.
///
/// İkisi de Ayarlar'dan ayrı ayrı açılıp kapatılır (varsayılan: açık) ve
/// cihazda saklanır. Ses ayrıca telefonun sessiz/titreşim moduna uyar
/// (bkz. [AppAudio]); titreşim sistemin dokunma titreşimi ayarına uyar.
///
/// Kaynak kullanımı: tek bir küçük oynatıcı, yalnızca ses ayarı açıksa ve
/// ilk ekran geldikten sonra kurulur; ayar kapatılınca bellekten silinir.
class AppFeedback {
  AppFeedback._();

  static const String _asset = 'assets/sounds/tap.wav';
  static const String _kClick = 'feedback_click_sound';
  static const String _kHaptics = 'feedback_haptics';

  static final ValueNotifier<bool> clickSound = ValueNotifier<bool>(true);
  static final ValueNotifier<bool> haptics = ValueNotifier<bool>(true);

  static AudioPlayer? _player;
  static Future<void>? _loading;
  static int _loadAttempts = 0;
  static int _lastTapMs = 0;

  /// Kayıtlı ayarları okur (uygulama açılışında bir kez).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      clickSound.value = prefs.getBool(_kClick) ?? true;
      haptics.value = prefs.getBool(_kHaptics) ?? true;
    } catch (_) {}
  }

  static Future<void> setClickSound(bool enabled) async {
    clickSound.value = enabled;
    unawaited(_save(_kClick, enabled));
    if (enabled) {
      warmUp();
    } else {
      await _release();
    }
  }

  static Future<void> setHaptics(bool enabled) async {
    haptics.value = enabled;
    unawaited(_save(_kHaptics, enabled));
  }

  static Future<void> _save(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  /// Oynatıcıyı arka planda hazırlar. İlk ekran geldiğinde çağrılır; ilk
  /// dokunuşta gecikme olmaması için. Ayar kapalıysa hiçbir şey yapmaz.
  static void warmUp() {
    if (!clickSound.value || _player != null) return;
    _loading ??= _load();
  }

  static Future<void> _load() async {
    AudioPlayer? player;
    try {
      await AppAudio.configureSession();
      // Ses odağı istenmez: çalan müzik her dokunuşta kısılmasın.
      player = AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: false,
      );
      await player.setAsset(_asset, preload: true);
      if (!clickSound.value) {
        await player.dispose();
        return;
      }
      _player = player;
    } catch (e) {
      debugPrint('Tıklama sesi hazırlanamadı: $e');
      await player?.dispose();
      // Bozuk bir durumda her dokunuşta yeniden denemesin.
      if (++_loadAttempts < 3) _loading = null;
    }
  }

  /// Dokunma geri bildirimi (ses + titreşim). Hiçbir hata fırlatmaz.
  static void tap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTapMs < 60) return; // çift tetiklenmeyi önle
    _lastTapMs = now;
    if (haptics.value) _haptic();
    if (clickSound.value) _click();
  }

  /// Ayar anahtarı açıldığında örnek olarak çalar (hız sınırı yok).
  static void preview({bool sound = true, bool haptic = true}) {
    if (haptic) _haptic();
    if (sound) _click();
  }

  static void _haptic() {
    try {
      unawaited(HapticFeedback.lightImpact());
    } catch (_) {}
  }

  static Future<void> _click() async {
    final player = _player;
    if (player == null) {
      warmUp(); // henüz hazır değil: bu dokunuşu atla, sonrakiler çalsın
      return;
    }
    try {
      await player.seek(Duration.zero);
      unawaited(player.play());
    } catch (_) {}
  }

  static Future<void> _release() async {
    final player = _player;
    _player = null;
    _loading = null;
    _loadAttempts = 0;
    try {
      await player?.dispose();
    } catch (_) {}
  }
}
