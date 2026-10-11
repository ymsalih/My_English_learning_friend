/// Uygulamanın dış bağlantıları tek yerde: bir adres değişirse yalnızca
/// burası güncellenir (giriş, ödeme ve ayarlar ekranları buradan okur).
class AppLinks {
  AppLinks._();

  static const String privacyPolicy =
      'https://sites.google.com/view/octopusgizlilikpolitikasi/ana-sayfa';

  static const String termsOfUse =
      'https://sites.google.com/view/octopuskullanimkosullari/ana-sayfa';

  /// Videolar YouTube oynatıcısıyla gösterildiği için YouTube API politikası
  /// bu bağlantıyı zorunlu tutar.
  static const String youtubeTerms = 'https://www.youtube.com/t/terms';
}
