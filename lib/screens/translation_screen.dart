import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TranslationScreen extends StatefulWidget {
  const TranslationScreen({super.key});

  @override
  State<TranslationScreen> createState() => _TranslationScreenState();
}

class _TranslationScreenState extends State<TranslationScreen> {
  final _textController = TextEditingController();
  final _translator = GoogleTranslator();
  final FlutterTts flutterTts = FlutterTts();

  String _translatedText = "";
  bool _isLoading = false;
  bool _isEnToTr =
      true; // true = İngilizce -> Türkçe, false = Türkçe -> İngilizce

  // 🧪 AKILLI ÇEVİRİ ÖZEL TEMASI (Turkuaz Geçiş)
  final LinearGradient primaryGradient = LinearGradient(
    colors: [Colors.teal.shade700, Colors.tealAccent.shade700],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Düzeltildi: Artık dil yönüne göre doğru aksanla okuyacak!
  Future<void> _speak(String text, String languageCode) async {
    if (text.isEmpty) return;
    await flutterTts.setLanguage(languageCode);
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.speak(text);
  }

  Future<void> _translate() async {
    if (_textController.text.trim().isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _translatedText = "";
      });
    }

    try {
      final translation = await _translator.translate(
        _textController.text.trim(),
        from: _isEnToTr ? 'en' : 'tr',
        to: _isEnToTr ? 'tr' : 'en',
      );

      if (mounted) {
        setState(() {
          _translatedText = translation.text;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translatedText = "Çeviri yapılırken bir hata oluştu.";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveToPool() async {
    if (_textController.text.trim().isEmpty || _translatedText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String engWord = _isEnToTr
          ? _textController.text.trim()
          : _translatedText;
      String trWord = _isEnToTr ? _translatedText : _textController.text.trim();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('words')
          .add({
            'eng': engWord,
            'tr': trWord,
            'timestamp': FieldValue.serverTimestamp(),
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Kelime başarıyla havuzuna eklendi! 🎉',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.teal.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Akıllı Çeviri',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        // 🧪 APPBAR İÇİN TURKUAZ GEÇİŞ
        flexibleSpace: Container(
          decoration: BoxDecoration(gradient: primaryGradient),
        ),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          // 🧪 ARKA PLAN İÇİN ÇOK YUMUŞAK SU YEŞİLİ
          gradient: LinearGradient(
            colors: [Colors.teal.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // --- DİL DEĞİŞTİRME PANELİ ---
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isEnToTr ? '🇬🇧 İngilizce' : '🇹🇷 Türkçe',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    IconButton(
                      icon: ShaderMask(
                        shaderCallback: (bounds) =>
                            primaryGradient.createShader(bounds),
                        child: const Icon(
                          Icons.swap_horizontal_circle,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _isEnToTr = !_isEnToTr;
                            _translatedText = "";
                            _textController.clear();
                          });
                        }
                      },
                    ),
                    Text(
                      _isEnToTr ? '🇹🇷 Türkçe' : '🇬🇧 İngilizce',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // --- METİN GİRİŞ ALANI ---
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _textController,
                  maxLines: 4,
                  style: const TextStyle(fontSize: 18),
                  decoration: InputDecoration(
                    hintText: 'Çevrilecek metni buraya yazın...',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(20),
                    suffixIcon: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.clear, color: Colors.grey.shade400),
                          onPressed: () {
                            _textController.clear();
                            if (mounted) setState(() => _translatedText = "");
                          },
                        ),
                        // Dinleme butonu sadece girilen dil için (İngilizce ise en-GB, Türkçe ise tr-TR)
                        IconButton(
                          icon: Icon(
                            Icons.volume_up_rounded,
                            color: Colors.teal.shade600,
                          ),
                          onPressed: () => _speak(
                            _textController.text.trim(),
                            _isEnToTr ? 'en-GB' : 'tr-TR',
                          ),
                          tooltip: 'Dinle',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // --- ÇEVİR BUTONU ---
              Container(
                decoration: BoxDecoration(
                  gradient: primaryGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _translate,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 28,
                        ),
                  label: const Text(
                    'Çevir',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 60),
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- ÇEVİRİ SONUCU KUTUSU (Animasyonlu) ---
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: _translatedText.isEmpty
                    ? const SizedBox.shrink()
                    : Column(
                        key: ValueKey(_translatedText),
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.teal.shade200,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '✨ Çeviri Sonucu',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.teal.shade800,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.volume_up_rounded,
                                        color: Colors.teal.shade700,
                                        size: 28,
                                      ),
                                      // Sonucu dinlerken hedeflenen dilin aksanını kullanıyoruz
                                      onPressed: () => _speak(
                                        _translatedText,
                                        _isEnToTr ? 'tr-TR' : 'en-US',
                                      ),
                                      tooltip: 'Sonucu Dinle',
                                    ),
                                  ],
                                ),
                                const Divider(),
                                const SizedBox(height: 5),
                                Text(
                                  _translatedText,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // --- HAVUZA EKLE BUTONU ---
                          OutlinedButton.icon(
                            onPressed: _saveToPool,
                            icon: const Icon(Icons.add_task),
                            label: const Text(
                              'Bu Kelimeyi Havuzuma Ekle',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 55),
                              foregroundColor: Colors.teal.shade700,
                              side: BorderSide(
                                color: Colors.teal.shade400,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
