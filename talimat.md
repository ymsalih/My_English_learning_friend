Bu Flutter projesinde SADECE ÜÇ ŞEY değişecek:
(1) uygulamanın telefonda görünen adı "Octopus English" olacak,
(2) uygulama ikonu ve logosu yenilenecek,
(3) açılış (splash) ekranı yeni animasyonla değişecek.
Yeni logo ve animasyon dosyaları projenin kök dizinindeki octopus_english_brand/ klasöründe.

KESİNLİKLE DOKUNMA:
- Paket adı / kimlikler: Android applicationId ve namespace (android/app/build.gradle veya build.gradle.kts), AndroidManifest'teki package, Kotlin/Java klasör yapısı (MainActivity yolu), iOS/macOS Bundle Identifier (PRODUCT_BUNDLE_IDENTIFIER), pubspec.yaml'daki "name:" alanı ve Dart import yolları (package:...).
- Firebase: google-services.json, GoogleService-Info.plist, firebase_options.dart, firebase.json, .firebaserc.
- .env dosyası: okuma, değiştirme.
- Proje klasörünün adı, versiyon numarası (version:), imzalama (signing) ayarları.
- Splash dışındaki ekranlar, iş mantığı, veritabanı, servisler, tema, mevcut paketlerin sürümleri. flutter pub upgrade ÇALIŞTIRMA.
Bu listedeki bir şeyi değiştirmen gerektiğini düşünürsen DURMA, bana sor.

ADIM 1 – ANALİZ (hiçbir dosyayı değiştirme):
- Uygulamanın görünen adının geçtiği yerleri bul: AndroidManifest (android:label), iOS Info.plist (CFBundleDisplayName ve CFBundleName), MaterialApp title, web/manifest.json ve web/index.html (<title>), windows/macos/linux'taki görünen ad ayarları.
- Mevcut ikon ve splash dosyalarını bul: Android mipmap klasörleri, iOS AppIcon.appiconset, launch_background.xml, LaunchScreen.storyboard, web ikonları, varsa flutter_launcher_icons / flutter_native_splash ayarları, Dart tarafındaki splash ekranı ve uygulama içinde kullanılan eski logo görselleri.
- Splash ekranından sonra uygulamanın nereye gittiğini ve açılışta hangi işlerin yapıldığını (Firebase başlatma, oturum kontrolü vb.) tespit et.
- Bana bir PLAN sun: değiştireceğin ve sileceğin her dosyayı tek tek listele. Onayımı almadan devam etme.

ADIM 2 – UYGULAMA ADI (onaydan sonra):
- Yalnızca görünen adı "Octopus English" yap. Yukarıdaki yasak listesindeki hiçbir kimliğe dokunma.

ADIM 3 – İKON VE LOGO:
- flutter_launcher_icons paketini dev_dependency olarak ekle. Ana ikon: octopus_english_brand/assets/icon/app_icon.png. Android adaptive icon: foreground = octopus_english_brand/assets/icon/app_icon_foreground.png, background rengi = #111A4A. iOS için remove_alpha_ios: true. Web ikonlarını da üret.
- Uygulama içinde eski logonun gösterildiği yerlerde octopus_english_brand/assets/icon/logo_transparent.png kullan (gerekirse projenin assets/ klasörüne kopyala ve pubspec.yaml'ın assets bölümüne ekle).
- Eski logo görsellerini yalnızca projede hiçbir yerde kullanılmıyorsa sil.

ADIM 4 – AÇILIŞ EKRANI:
- Mevcut splash ekranını yenisiyle değiştir. Açılış akışı aynen korunmalı: splash'ten sonra eskiden nereye gidiliyorsa yine oraya gidilsin, açılışta yapılan işler (Firebase, oturum kontrolü vb.) aynı şekilde yapılsın ve animasyonla paralel çalışsın.
- octopus_english_brand/reference/octopus_scene.js dosyasını dikkatle oku ve Flutter'a CustomPainter olarak BİREBİR port et:
  - Aynı seed'li rastgele sayı üreteci (seed = 11, seed*16807 % 2147483647), aynı SPEC dizisi, aynı kol geometrisi (açılar kümülatif toplanarak), aynı zaman çizelgesi, renkler ve katmanlar.
  - createRadialGradient → ui.Gradient.radial (focal + focalRadius ile). 'lighter' → BlendMode.plus. shadowBlur → MaskFilter.blur. Uzaklık bulanıklığı ve sis için saveLayer + ImageFilter.blur ve BlendMode.srcATop.
  - Zamanı Ticker ile ValueNotifier<double>'a yaz, CustomPainter'ı repaint: parametresiyle bu notifier'a bağla. Her karede setState yapma.
- "Octopus" / "ENGLISH" yazısını widget olarak ekle (Fredoka fontu, google_fonts paketiyle). Yazı 3.3. saniyede 0.8 saniyelik fade-up ile gelsin, konumu octopus_english_brand/reference/octopus-english-splash.html dosyasındaki gibi olsun.
- Animasyon yaklaşık 4.6 saniye sürsün. MediaQuery.disableAnimations açıksa son kareyi gösterip hemen geçsin.
- flutter_native_splash ile native açılış arka plan rengini #0B1540 yap (Flutter yüklenirken beyaz ekran görünmesin).
- Yeni paket olarak yalnızca flutter_launcher_icons, flutter_native_splash ve google_fonts ekle; başka paket ekleme.

ADIM 5 – KONTROL:
- flutter pub get ve flutter analyze çalıştır; yalnızca kendi değişikliklerinden kaynaklanan hataları düzelt.
- git diff ile yasak listesindeki hiçbir dosyanın değişmediğini doğrula ve bunu bana açıkça yaz.
- Değiştirdiğin tüm dosyaları listele. Android ve iOS'ta nasıl test edeceğimi söyle.
- octopus_english_brand/ klasörüne dokunma, referans olarak kalsın.