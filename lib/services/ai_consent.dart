import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';

import '../theme/app_theme.dart';

/// Kullanıcı rıza vermeden üçüncü taraf servislere (Gemini, çeviri servisleri)
/// hiçbir veri gönderilmez. Rıza cihazda saklanır ve Ayarlar'dan geri alınabilir.
class AiConsentException implements Exception {
  @override
  String toString() => 'AiConsentException: veri paylaşımı izni verilmedi';
}

class AiConsent {
  AiConsent._();

  static const _prefsKey = 'ai_data_consent_v1';

  /// null: henüz sorulmadı, true: izin verildi, false: reddedildi.
  static final ValueNotifier<bool?> state = ValueNotifier<bool?>(null);

  static bool get granted => state.value == true;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state.value = prefs.getBool(_prefsKey);
    } catch (e) {
      debugPrint('AiConsent load error: $e');
    }
  }

  static Future<void> set(bool value) async {
    state.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey, value);
    } catch (e) {
      debugPrint('AiConsent save error: $e');
    }
  }

  /// Üçüncü taraf bir servise istek atmadan önce çağrılır.
  static void check() {
    if (!granted) throw AiConsentException();
  }

  /// İzin yoksa onay penceresini gösterir; kullanıcı kabul ederse true döner.
  static Future<bool> ensure(BuildContext context) async {
    if (granted) return true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _AiConsentDialog(),
    );
    await set(accepted == true);
    return accepted == true;
  }

  /// Giriş sonrası ilk açılışta, henüz hiç sorulmadıysa sorar.
  static Future<void> askIfUndecided(BuildContext context) async {
    if (state.value != null) return;
    await ensure(context);
  }
}

/// `GoogleTranslator` ile aynı kullanım; yalnızca izin varsa istek atar.
class ConsentTranslator {
  final GoogleTranslator _inner = GoogleTranslator();

  Future<Translation> translate(String text, {String from = 'auto', String to = 'en'}) {
    AiConsent.check();
    return _inner.translate(text, from: from, to: to);
  }
}

class _AiConsentDialog extends StatelessWidget {
  const _AiConsentDialog();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border),
        ),
        title: Text('Verilerin nereye gidiyor?', style: AppText.heading(size: 20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Octopus English bazı özellikleri için yazdıklarını üçüncü taraf servislere gönderir. '
                'Devam etmek için aşağıdakileri kabul etmen gerekir.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              const _ConsentRow(
                icon: Icons.chat_bubble_rounded,
                title: 'Sohbet ve hikaye → Google Gemini',
                body: 'Yazdığın mesajlar ve hikaye isteklerin, yapay zeka cevabı üretmek için Google Gemini\'ye gönderilir.',
              ),
              const _ConsentRow(
                icon: Icons.translate_rounded,
                title: 'Çeviri → DeepL, Google Translate, dictionaryapi.dev',
                body: 'Çevirmek ya da anlamına bakmak istediğin metin ve kelimeler bu servislere gönderilir. '
                    'Kelime görseli için kelime, görsel servisi Pexels\'e iletilir.',
              ),
              const _ConsentRow(
                icon: Icons.mic_rounded,
                title: 'Konuşma tanıma → cihazın kendi servisi',
                body: 'Telaffuz ve sesli çeviride sesin, telefonunun konuşma tanıma servisi (Apple / Google) tarafından işlenir. '
                    'Uygulama ses kaydını saklamaz.',
              ),
              const SizedBox(height: 4),
              Text(
                'Kamerayla taranan görüntüler yalnızca cihazında işlenir, gönderilmez. '
                'İznini istediğin zaman Ayarlar\'dan geri alabilirsin. Reddedersen bu özellikler çalışmaz, '
                'uygulamanın diğer bölümleri kullanılmaya devam eder.',
                style: AppText.caption,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Reddet', style: TextStyle(color: AppColors.textMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kabul Ediyorum'),
          ),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.primaryLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
